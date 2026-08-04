#!/usr/bin/env bash
# red-baseline.sh — RED 기준선 스냅샷 ↔ 최종 테스트 파일 대조 (시맨틱 reward-hack 탐지)
#
# 왜 필요한가:
#   `block-developer-test-edit.sh`는 developer의 테스트 편집을 **구문 경로**로 막는다.
#   그러나 테스트 약화는 **정당한 경로로도** 일어난다 — GREEN 실패 → FAIL 3분기 →
#   작성자(codex/tester-design) 재작성 루프에서 단언이 조용히 약해질 수 있다.
#   그리고 `/review`는 대상에서 테스트를 **명시적으로 제외**한다(code-reviewer.md 핵심규칙).
#   → RED 기준선의 단언이 최종본에서 살아있는지 보는 그물이 어디에도 없었다.
#
# 역할 분담: **탐지는 여기(결정론), 판정은 LLM.**
#   이 스크립트는 "무엇이 바뀌었나"만 증거로 낸다. "약화인가 정당한 교정인가"는 판단이라 안 한다.
#
# Usage (제품 repo 루트에서 실행):
#   bash .claude/scripts/red-baseline.sh snapshot   # 8.0 위임 커버리지 대조 시점(GREEN 발사 직전)
#   bash .claude/scripts/red-baseline.sh diff       # 워크스루 3단계(finalizer 직전)
#   bash .claude/scripts/red-baseline.sh show       # 스냅샷 덤프 (디버그)
#
# ── 불변식 ───────────────────────────────────────────────────────────────
#   - **무음 통과 금지.** 스냅샷이 없으면 "이상 없음"이 아니라 `⚠ 미검증`을 출력한다.
#     (부재를 통과로 읽는 게 이 하네스가 반복해서 물린 실패 클래스다 —
#      wiki/gates-verify-present-code-only.md)
#   - 판정·차단은 하지 않는다. exit 는 항상 0, 판정 신호는 stdout 텍스트로만.
#   - 테스트 파일을 수정하지 않는다(읽기 + git object 쓰기뿐).
#
# 테스트 경로 판정: `hooks/block-developer-test-edit.sh`와 같은 클래스이되 **앵커가 다르다**.
#   훅은 hook payload의 **절대경로**를 보므로 `[/\\]src[/\\]test[/\\]`로 충분하지만,
#   여기는 `git ls-files`의 **repo-상대 경로**라 선두 세그먼트(`src/test/…`)가 앞 구분자 없이 온다.
#   → `(^|[/\\])`로 선두를 허용한다. 이 차이를 놓치면 백엔드 테스트가 통째로 스냅샷에서 빠져
#     "이탈 없음"이 조용히 오출력된다(실측으로 잡은 버그, 2026-07-27).
#   env RED_BASELINE_TEST_RE 로 프로젝트별 override 가능.

set -uo pipefail

TEST_RE="${RED_BASELINE_TEST_RE:-(^|[/\\])src[/\\]test[/\\]|(^|[/\\])__tests__[/\\]|\.(spec|test)\.(ts|tsx|js|jsx|mts|cts|vue)$}"

# 삭제되면 약화 의심인 라인 (단언류)
ASSERT_RE='assert|assertThat|assertEquals|assertThrows|verify\(|expect\(|\.should|toBe|toEqual|toThrow|toHaveBeen|isEqualTo|isInstanceOf|hasSize|contains'
# 추가되면 약화 의심인 라인 (skip/비활성/무력화)
SKIP_RE='@Disabled|@Ignore|\.skip\(|\bxit\(|\bxdescribe\(|it\.skip|describe\.skip|test\.skip|enabled[[:space:]]*=[[:space:]]*false|@Test\(enabled|todo\('
SAMPLE_MAX=5   # 파일당 인용 라인 상한 (출력 폭주 방지)

note() { printf '%s\n' "red-baseline: $*" >&2; }

# ⚠ Windows 네이티브 jq(winget 등)는 stdout에 **CRLF**를 쓴다. MSYS 도구 대부분이
#   텍스트모드로 CR을 걸러주지만 `jq | sort` 처럼 중간 파이프를 끼우면 CR이 살아남아
#   경로·해시 비교가 조용히 어긋난다(파일이 "삭제됨"으로 오판). jq 출력은 전부 이걸로 받는다.
#   근거: 실측 2026-07-27 — `.files|keys[] | sort -u` 경로에 CR 잔존 → 백엔드 테스트 오탐.
jqr() { jq -r "$@" 2>/dev/null | tr -d '\r'; }

CMD="${1:-diff}"
case "$CMD" in
  snapshot|diff|show) ;;
  -h|--help|help) sed -n '2,30p' "$0"; exit 0 ;;
  *) note "알 수 없는 명령 '$CMD' (snapshot|diff|show)"; exit 0 ;;
esac

command -v jq >/dev/null 2>&1 || { note "jq 없음 — 생략"; exit 0; }
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || { note "git repo 아님 — 생략"; exit 0; }

SLUG=""
SLUG_BIN="$HOME/.claude/skills/gstack/bin/gstack-slug"
[ -x "$SLUG_BIN" ] && { eval "$("$SLUG_BIN" 2>/dev/null)" 2>/dev/null || true; }
if [ -z "${SLUG:-}" ]; then note "slug 산정 실패(gstack 미설치?) — 생략"; exit 0; fi

STATE_DIR="$HOME/.gstack/projects/$SLUG"
STATE="$STATE_DIR/red-baseline.json"

# 현재 워킹트리의 테스트 파일 목록 (tracked + untracked, ignored 제외)
list_test_files() {
  git ls-files -co --exclude-standard 2>/dev/null | grep -iE "$TEST_RE" | sort -u
}

case "$CMD" in

show)
  if [ -f "$STATE" ]; then jq . "$STATE"; else printf '%s\n' "(스냅샷 없음: $STATE)"; fi
  ;;

# ── snapshot: RED 기준선 고정 (8.0, GREEN 발사 직전) ─────────────────────
snapshot)
  FILES="$(list_test_files)"
  if [ -z "$FILES" ]; then
    printf '%s\n' "📸 RED 기준선: 테스트 파일 0개 — 스냅샷 생략(대조 대상 없음)."
    exit 0
  fi

  ENTRIES=""
  N=0
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    blob="$(git hash-object -w -- "$f" 2>/dev/null)"
    [ -z "$blob" ] && { note "hash-object 실패: $f — 목록에서 제외"; continue; }
    ENTRIES="$ENTRIES$(printf '%s\t%s\n' "$f" "$blob")"$'\n'
    N=$((N+1))
  done <<< "$FILES"

  if [ "$N" -eq 0 ]; then note "해시 산출 0건 — 스냅샷 생략"; exit 0; fi

  HEAD_SHA="$(git rev-parse HEAD 2>/dev/null)"
  TS="$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null)"
  MAP="$(printf '%s' "$ENTRIES" | jq -R -s 'split("\n") | map(select(length>0) | split("\t") | {(.[0]): .[1]}) | add' 2>/dev/null)"
  [ -z "$MAP" ] && { note "맵 생성 실패 — 스냅샷 생략"; exit 0; }

  mkdir -p "$STATE_DIR" 2>/dev/null || { note "디렉터리 생성 실패 — 생략"; exit 0; }
  tmp="$STATE_DIR/.red-baseline.$$.tmp"
  if printf '%s' "$MAP" | jq --arg ts "$TS" --arg head "$HEAD_SHA" \
       '{ts:$ts, head:$head, files:.}' > "$tmp" 2>/dev/null && mv -f "$tmp" "$STATE" 2>/dev/null; then
    printf '%s\n' "📸 RED 기준선 스냅샷: 테스트 ${N}파일 고정 (GREEN 이후 워크스루서 대조)"
  else
    rm -f "$tmp" 2>/dev/null
    note "스냅샷 쓰기 실패 — 이 축은 미검증이 된다"
    printf '%s\n' "⚠ RED 기준선 스냅샷 실패 — 워크스루 대조 불가(⚠ 미검증 전제로 태깅할 것)"
  fi
  ;;

# ── diff: 기준선 이탈 대조 (워크스루 3단계, finalizer 직전) ──────────────
diff)
  if [ ! -f "$STATE" ] || ! jq -e . "$STATE" >/dev/null 2>&1; then
    printf '%s\n' "⚠ RED 기준선 스냅샷 없음 — 8.0에서 \`snapshot\` 미실행."
    printf '%s\n' "  → 이 축(단언 약화)은 **미검증**이다. \"이상 없음\"으로 읽지 말 것."
    printf '%s\n' "  → 기능 문서·완료 리포트에 \`⚠ 미검증 전제: RED 기준선 대조\`로 태깅한다."
    exit 0
  fi

  BASE_TS="$(jqr '.ts // "?"' "$STATE")"
  BASE_PATHS="$(jqr '.files | keys[]' "$STATE" | sort -u)"
  NOW_PATHS="$(list_test_files)"

  CHANGED=""; REMOVED=""; ADDED=""; SAME=0
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    want="$(jqr --arg f "$f" '.files[$f] // empty' "$STATE")"
    if [ ! -f "$f" ]; then REMOVED="$REMOVED$f"$'\n'; continue; fi
    have="$(git hash-object -- "$f" 2>/dev/null)"
    if [ "$want" = "$have" ]; then SAME=$((SAME+1)); else CHANGED="$CHANGED$f"$'\n'; fi
  done <<< "$BASE_PATHS"

  while IFS= read -r f; do
    [ -z "$f" ] && continue
    if ! printf '%s\n' "$BASE_PATHS" | grep -Fxq -- "$f"; then ADDED="$ADDED$f"$'\n'; fi
  done <<< "$NOW_PATHS"

  N_CH="$(printf '%s' "$CHANGED" | grep -c . || true)"
  N_RM="$(printf '%s' "$REMOVED" | grep -c . || true)"
  N_AD="$(printf '%s' "$ADDED"   | grep -c . || true)"

  if [ "$N_CH" -eq 0 ] && [ "$N_RM" -eq 0 ]; then
    if [ "$N_AD" -gt 0 ]; then
      printf '%s\n' "✅ RED 기준선 이탈 없음 — ${SAME}파일 해시 일치 (기준선 $BASE_TS). 신규 테스트 ${N_AD}파일은 추가만(약화 아님)."
    else
      printf '%s\n' "✅ RED 기준선 이탈 없음 — ${SAME}파일 해시 일치 (기준선 $BASE_TS)."
    fi
    exit 0
  fi

  printf '%s\n' "⚠ RED 기준선 이탈: 변경 ${N_CH}파일 / 삭제 ${N_RM}파일 / 신규 ${N_AD}파일 (기준선 $BASE_TS)"

  # 기준선 stale 경고: 기준선 이후 커밋이 있으면 **남의 변경**이 이탈 집합에 섞인다.
  #   실측(2026-08-02): 이탈 3파일 중 1파일이 직전 라운드 커밋분(+8 -5). 삭제단언 0이라 오판은
  #   면했으나, 있었다면 남의 변경을 내 약화로 판정했을 것. → 미커밋 집합을 함께 찍어 교집합을 보이게.
  SINCE_N=0
  if [ "$BASE_TS" != "?" ]; then
    SINCE_N="$(git log --since="$BASE_TS" --oneline 2>/dev/null | grep -c . || true)"
  fi
  if [ "${SINCE_N:-0}" -gt 0 ]; then
    printf '%s\n' "  ⚠ 기준선 이후 커밋 ${SINCE_N}건 — 이탈 집합에 **다른 라운드 산출물**이 섞였을 수 있다."
    printf '%s\n' "     판정 전 미커밋 집합과 교집합을 내라(교집합 밖 = 내 변경 아님):"
    UNCOMMITTED="$(git diff --name-only 2>/dev/null; git diff --cached --name-only 2>/dev/null)"
    UNCOMMITTED="$(printf '%s\n' "$UNCOMMITTED" | sort -u | grep -c . || true)"
    printf '%s\n' "     미커밋 변경 파일 ${UNCOMMITTED}개 (아래 각 이탈 파일에 [미커밋]/[기커밋] 표기)"
  fi

  TMPD="$(mktemp -d 2>/dev/null)" || TMPD=""
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    want="$(jqr --arg f "$f" '.files[$f] // empty' "$STATE")"
    [ -z "$want" ] && continue
    old=""
    if [ -n "$TMPD" ]; then
      old="$TMPD/base"
      git cat-file -p "$want" > "$old" 2>/dev/null || old=""
    fi
    if [ -z "$old" ]; then printf '%s\n' "  $f — (기준선 blob 복원 실패, 수동 확인 필요)"; continue; fi

    D="$(git diff --no-index --unified=0 -- "$old" "$f" 2>/dev/null)"
    DEL_ASSERT="$(printf '%s\n' "$D" | grep '^-' | grep -v '^---' | grep -iE "$ASSERT_RE" || true)"
    ADD_SKIP="$(printf '%s\n' "$D" | grep '^+' | grep -v '^+++' | grep -iE "$SKIP_RE" || true)"
    NA="$(printf '%s' "$DEL_ASSERT" | grep -c . || true)"
    NS="$(printf '%s' "$ADD_SKIP" | grep -c . || true)"
    PLUS="$(printf '%s\n' "$D" | grep -c '^+' || true)"; PLUS=$((PLUS>0?PLUS-1:0))
    MINUS="$(printf '%s\n' "$D" | grep -c '^-' || true)"; MINUS=$((MINUS>0?MINUS-1:0))

    # 이 파일이 내 미커밋 변경인가, 기준선 이후 이미 커밋된 남의 변경인가.
    ORIGIN=""
    if [ "${SINCE_N:-0}" -gt 0 ]; then
      if git diff --name-only -- "$f" 2>/dev/null | grep -Fxq -- "$f" \
        || git diff --cached --name-only -- "$f" 2>/dev/null | grep -Fxq -- "$f"; then
        ORIGIN=" [미커밋]"
      else
        ORIGIN=" [기커밋 — 내 변경 아닐 수 있음]"
      fi
    fi
    printf '%s\n' "  $f  +${PLUS} -${MINUS}   삭제단언 ${NA} / skip마커 +${NS}${ORIGIN}"
    if [ "$NA" -gt 0 ]; then
      printf '%s\n' "$DEL_ASSERT" | head -"$SAMPLE_MAX" | sed 's/^/      /'
      [ "$NA" -gt "$SAMPLE_MAX" ] && printf '%s\n' "      ... 외 $((NA-SAMPLE_MAX))줄"
    fi
    if [ "$NS" -gt 0 ]; then
      printf '%s\n' "$ADD_SKIP" | head -"$SAMPLE_MAX" | sed 's/^/      /'
    fi
  done <<< "$CHANGED"

  if [ "$N_RM" -gt 0 ]; then
    printf '%s\n' "  [삭제된 테스트 파일 — 최고 위험]"
    printf '%s' "$REMOVED" | sed 's/^/      /'
  fi
  [ -n "$TMPD" ] && rm -rf "$TMPD" 2>/dev/null

  printf '%s\n' "→ 판정 필요(LLM): 위 변경이 **약화(reward-hack)**인가 **정당한 교정**인가."
  printf '%s\n' "   정당하면 사유를 기능 문서에 1줄 기록. 약화면 finalizer 진입 금지 → 작성자 반환."
  ;;

esac

exit 0
