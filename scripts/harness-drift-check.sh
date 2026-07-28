#!/usr/bin/env bash
# harness-drift-check.sh — orchestrator.md ↔ 분리 문서(playbook·routing-map) drift 탐지
#
# 왜 필요한가:
#   `orchestrator.md ## 분리 문서`가 "이 4개 파일은 orchestrator.md와 한 몸"이라 선언하고,
#   finalizer bump 의식 step 1.5가 정합성 점검을 지시한다. 그런데 **소프트룰이라 진다** —
#   v3.76.0 이후 orchestrator.md 8커밋 중 routing-map 동반 갱신은 1회(실측 2026-07-28).
#   누락된 게이트 3개: 8.0 위임 커버리지 대조 / 모델 실측 / 워크스루 3.5 RED 기준선.
#
# 역할 분담: **탐지는 여기(결정론), 판정은 LLM.**
#   "이 변경이 다이어그램에 실려야 하나"는 판단이라 스크립트가 결론내지 않는다.
#   바뀐 **섹션 이름**을 뽑아줘 5초 안에 판단하게 하는 게 목적이다.
#
# Usage:
#   bash .claude/scripts/harness-drift-check.sh            # staged (커밋 직전 — 기본)
#   bash .claude/scripts/harness-drift-check.sh HEAD       # 직전 커밋 사후 점검
#   bash .claude/scripts/harness-drift-check.sh <sha>      # 임의 커밋
#   bash .claude/scripts/harness-drift-check.sh --audit    # 누적 drift 전수 점검
#
# ⚠ **왜 --audit이 따로 필요한가**: 위 세 모드는 전부 **커밋 delta**를 본다. 그래서
#   *"애초에 한 번도 실린 적 없는 단계"*는 어떤 delta에도 안 나타나 영원히 안 잡힌다.
#   실제로 모드 판정·설계모드 트랙이 2026-06-05 도입 후 53일간 미반영이었고,
#   delta 모드로는 못 찾아 수동 전수 대조로 발견했다(2026-07-28).
#   부재는 delta에 나타나지 않는다 — wiki/gates-verify-present-code-only.md와 같은 축.
#
# ── 불변식 ───────────────────────────────────────────────────────────────
#   - 차단하지 않는다. exit 항상 0. 판정 신호는 stdout 텍스트로만.
#   - **노이즈 금지**: 게이트·시퀀스 성격의 섹션이 바뀐 경우에만 말한다.
#     오타·문구 다듬기(토큰 다이어트 등)엔 침묵 — 소프트룰 피로를 만들지 않는다.
#   - 무변경·비대상 커밋엔 아무것도 출력하지 않는다.

set -uo pipefail

SRC="agents/orchestrator.md"
MAP="docs/routing-map.md"
PLAYBOOKS="docs/playbook-harness-ops.md docs/playbook-design-mode.md docs/playbook-tdd.md"

# ── 판별식: "새 단계·게이트가 생겼나" (섹션 이름 매칭은 쓰지 않는다) ──────────
#   ⚠ 초기안은 heading 이름을 `게이트|단계|라우팅|…`로 필터했는데 **무용지물**이었다 —
#     orchestrator.md 헤딩이 거의 전부 그 단어를 달고 있어, 문구만 다듬은 커밋(v3.77.1
#     토큰 다이어트)이 9건 오탐으로 걸렸다. 소프트룰 피로를 만드는 정확히 그 실패다.
#   → 실제 drift 3건(8.0 / 8.0b / 모델 실측)과 코스메틱 커밋을 가르는 건 이름이 아니라
#     **구조 변화**다. 두 신호만 본다:
#       (A) heading 집합의 추가·삭제
#       (B) 번호 하위단계 신설 (`3.5.` 처럼 heading이 아닌 목록 항목으로 들어오는 게이트)
SUBSTEP='^\+[[:space:]]*[0-9]+\.[0-9]+\.?[[:space:]]'

note() { printf '%s\n' "harness-drift: $*" >&2; }

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || { note "git repo 아님 — 생략"; exit 0; }
cd "$(git rev-parse --show-toplevel)" 2>/dev/null || exit 0

REF="${1:-}"

# ── --audit: 현재 상태 전수 대조 (delta 무관) ────────────────────────────
if [ "$REF" = "--audit" ]; then
  [ -f "$MAP" ] || { note "$MAP 없음 — 생략"; exit 0; }
  MAPTXT="$(cat "$MAP" 2>/dev/null)"
  MISSING=""

  # 대상 = 번호 붙은 단계/게이트 heading (흐름 축). 산문 규칙 섹션은 제외.
  for f in $SRC $PLAYBOOKS; do
    [ -f "$f" ] || continue
    while IFS= read -r h; do
      [ -z "$h" ] && continue
      # heading에서 단계 키(선두 번호 또는 첫 명사구) 추출
      key="$(printf '%s' "$h" | sed 's/^#\{1,6\}[[:space:]]*//; s/[[:space:]]*(.*//; s/[*_`]//g; s/[[:space:]]*$//')"
      [ -z "$key" ] && continue
      # 번호 키(0-1단계·7c.1·8.0b 등)면 번호만, 아니면 앞 6자로 대조
      num="$(printf '%s' "$key" | sed -n 's/^\([0-9][0-9.a-z-]*\).*/\1/p')"
      probe="${num:-$(printf '%s' "$key" | cut -c1-6)}"
      printf '%s' "$MAPTXT" | grep -qF -- "$probe" || MISSING="$MISSING  ${f##*/} → $key"$'\n'
    done <<< "$(grep -E '^#{2,3} *[0-9]' "$f" 2>/dev/null)"
  done

  if [ -z "$MISSING" ]; then
    printf '%s\n' "✅ 번호 단계 전수 대조 — ${MAP##*/}에 전부 반영됨"
    exit 0
  fi
  printf '%s\n' "⚠ 누적 drift: ${MAP##*/}에 없는 번호 단계"
  printf '%s' "$MISSING"
  printf '%s\n' "→ 판정 필요(LLM): 흐름 축이면 다이어그램에 반영. 세부 하위규칙이면 무시."
  printf '%s\n' "   (이 모드는 '한눈에' 가치를 지키려 일부러 과탐지한다 — 전부 넣으라는 뜻 아님)"
  exit 0
fi

if [ -z "$REF" ]; then
  DIFF_ARGS="--cached"; LABEL="staged"
else
  git rev-parse --verify "$REF^{commit}" >/dev/null 2>&1 || { note "커밋 아님: $REF — 생략"; exit 0; }
  DIFF_ARGS="$REF^ $REF"; LABEL="$REF"
fi

# shellcheck disable=SC2086
CHANGED="$(git diff --name-only $DIFF_ARGS 2>/dev/null)"
[ -z "$CHANGED" ] && exit 0

has() { printf '%s\n' "$CHANGED" | grep -Fxq -- "$1"; }

SRC_TOUCHED=false;  has "$SRC" && SRC_TOUCHED=true
MAP_TOUCHED=false;  has "$MAP" && MAP_TOUCHED=true
PB_TOUCHED=false;   for p in $PLAYBOOKS; do has "$p" && PB_TOUCHED=true; done

# 대상 파일을 하나도 안 건드린 커밋 → 침묵
if ! $SRC_TOUCHED && ! $PB_TOUCHED; then exit 0; fi
# 다이어그램을 이미 갱신했으면 → 침묵 (의식 수행됨)
if $MAP_TOUCHED; then exit 0; fi

# (A) heading 집합 변화 + (B) 번호 하위단계 신설
structural_changes() {
  file="$1"
  if [ -z "$REF" ]; then
    old="$(git show "HEAD:$file" 2>/dev/null)"; new="$(git show ":$file" 2>/dev/null)"
  else
    old="$(git show "$REF^:$file" 2>/dev/null)"; new="$(git show "$REF:$file" 2>/dev/null)"
  fi

  # (A) 신규/삭제 heading — 단, **개명은 신설이 아니다**.
  #     괄호 부제만 바뀐 경우(`… (컨텍스트 절감 — v3.69.0)` → `… (컨텍스트 절감)`)가
  #     +/- 쌍으로 잡혀 v3.77.1 코스메틱 커밋이 오탐됐다 → 정규화 키가 같으면 상쇄한다.
  ho="$(printf '%s\n' "$old" | grep -E '^#{2,4} ' 2>/dev/null | sed 's/[[:space:]]*$//' | sort -u)"
  hn="$(printf '%s\n' "$new" | grep -E '^#{2,4} ' 2>/dev/null | sed 's/[[:space:]]*$//' | sort -u)"
  add="$(comm -13 <(printf '%s\n' "$ho") <(printf '%s\n' "$hn") 2>/dev/null | grep -v '^$' || true)"
  del="$(comm -23 <(printf '%s\n' "$ho") <(printf '%s\n' "$hn") 2>/dev/null | grep -v '^$' || true)"
  # 정규화: heading 마커·괄호 부제·강조기호 제거 후 공백 정리
  norm() { sed 's/^#\{1,6\}[[:space:]]*//; s/([^)]*)//g; s/[*_`]//g; s/[[:space:]]\{1,\}/ /g; s/^ //; s/ $//'; }
  del_keys="$(printf '%s\n' "$del" | norm)"
  add_keys="$(printf '%s\n' "$add" | norm)"
  paste -d'\t' <(printf '%s\n' "$add_keys") <(printf '%s\n' "$add") 2>/dev/null \
    | while IFS=$'\t' read -r k line; do
        [ -z "$line" ] && continue
        printf '%s\n' "$del_keys" | grep -Fxq -- "$k" && continue   # 개명 → 상쇄
        printf '  + %s\n' "$line"
      done
  paste -d'\t' <(printf '%s\n' "$del_keys") <(printf '%s\n' "$del") 2>/dev/null \
    | while IFS=$'\t' read -r k line; do
        [ -z "$line" ] && continue
        printf '%s\n' "$add_keys" | grep -Fxq -- "$k" && continue
        printf '  - %s\n' "$line"
      done

  # (B) heading 아닌 번호 하위단계 신설 (예: 워크스루 "3.5. …")
  # shellcheck disable=SC2086
  git diff -U0 $DIFF_ARGS -- "$file" 2>/dev/null \
    | grep -E "$SUBSTEP" 2>/dev/null \
    | sed 's/^+[[:space:]]*//; s/^/  + /' | cut -c1-100
}

FINDINGS=""
for f in $SRC $PLAYBOOKS; do
  has "$f" || continue
  out="$(structural_changes "$f" | grep -v '^  [+-] *$' || true)"
  [ -n "$out" ] && FINDINGS="$FINDINGS$(printf '%s\n' "$out" | sed "s|^  |  ${f##*/} |")"$'\n'
done

[ -z "$FINDINGS" ] && exit 0

printf '%s\n' "⚠ 분리 문서 drift 의심 ($LABEL) — 단계·게이트가 신설/삭제됐는데 ${MAP##*/} 미변경"
printf '%s' "$FINDINGS"
printf '%s\n' "→ 판정 필요(LLM): 위 단계가 흐름 다이어그램에 실려야 하나?"
printf '%s\n' "   실려야 하면 $MAP 같은 커밋에서 갱신. 아니면 무시(차단 아님)."

exit 0
