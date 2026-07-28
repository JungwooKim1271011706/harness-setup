#!/usr/bin/env bash
# regression-debt.sh — 전체회귀 부채(Full Regression Debt) state 단일 진입점 (SSOT)
#
# 정의: CONTEXT.md `## 전체회귀 부채` / docs/adr/0002-regression-debt-decoupling.md D3~D7
# 소비자: finalizer(render/update) · tester-runtime(reset)
#
# Usage (제품 repo 루트에서 실행):
#   bash .claude/scripts/regression-debt.sh render   # 커밋 직전 안내 블록 출력 (finalizer)
#   bash .claude/scripts/regression-debt.sh update   # 커밋 직후 state 갱신    (finalizer)
#   bash .claude/scripts/regression-debt.sh reset    # 전체회귀 PASS 시 리셋    (tester-runtime)
#   bash .claude/scripts/regression-debt.sh show     # state 덤프 (디버그 전용)
#   bash .claude/scripts/regression-debt.sh set-escalation "modA,modB"   # 트리거② 1회 시딩
#
# ── 불변식 (ADR-0002 D4 — 절대 위반 금지) ────────────────────────────────
#   - 이 스크립트는 **절대 커밋을 차단하지 않는다**. 어떤 실패(state 부재·JSON 파손·
#     jq 부재·slug 산정 실패·쓰기 실패)에서도 stdout은 비우고 exit 0. 진단은 stderr로만.
#   - 출력은 비차단 단방향 통지 텍스트다. 호출자는 exit code로 분기하지 않는다.
#   - slug 산정은 여기 한 곳뿐이다. finalizer와 tester-runtime이 같은 스크립트를 쓰므로
#     양쪽 slug 불일치로 부채가 영구 리셋 실패하던 축이 구조적으로 사라진다.
#
# ── 프로젝트 특화 설정 ───────────────────────────────────────────────────
# state 파일 안에 선택 필드로 둔다(repo 밖 = 하네스 미오염, `.claude/`에 안 들어감).
#   escalation_modules : ["<공용 프레임워크 모듈>"]  트리거② 격상 대상. 없으면 트리거②는 항상 false.
#   module_depth       : 1                          모듈명으로 쓸 경로 세그먼트 수(기본 1).
# 1회성 override: 환경변수 REGRESSION_ESCALATION_MODULES="modA,modB"

set -uo pipefail   # -e 금지: 부분 실패가 커밋 흐름을 끊으면 안 된다

N_THRESHOLD=5

note() { printf '%s\n' "regression-debt: $*" >&2; }

CMD="${1:-render}"
case "$CMD" in
  render|update|reset|show|set-escalation) ;;
  -h|--help|help) sed -n '2,25p' "$0"; exit 0 ;;
  *) note "알 수 없는 명령 '$CMD' (render|update|reset|show|set-escalation)"; exit 0 ;;
esac

command -v jq >/dev/null 2>&1 || { note "jq 없음 — 생략"; exit 0; }

# ── slug 산정 (리뷰모드 체크포인트와 동일 메커니즘) ──────────────────────
SLUG=""
SLUG_BIN="$HOME/.claude/skills/gstack/bin/gstack-slug"
if [ -x "$SLUG_BIN" ]; then
  eval "$("$SLUG_BIN" 2>/dev/null)" 2>/dev/null || true
fi
if [ -z "${SLUG:-}" ]; then
  note "slug 산정 실패(gstack 미설치?) — 생략"
  exit 0
fi

STATE_DIR="$HOME/.gstack/projects/$SLUG"
STATE="$STATE_DIR/regression-debt.json"
EMPTY='{"last_full_regression":{"sha":null,"ts":null},"commits_since":[]}'

# ── state 읽기: 부재·파손이면 빈 부채로 간주 (커밋 차단 금지) ────────────
STATE_JSON="$EMPTY"
if [ -f "$STATE" ]; then
  if jq -e . "$STATE" >/dev/null 2>&1; then
    STATE_JSON="$(cat "$STATE")"
  else
    note "state JSON 파손 — 빈 부채로 간주"
  fi
fi

# ⚠ Windows 네이티브 jq(winget 등)는 stdout에 CRLF를 쓴다. MSYS 도구가 대개 CR을 걸러주지만
#   중간 파이프(`jq | sort` 등)를 끼우면 살아남아 문자열 비교가 조용히 어긋난다 —
#   `grep -Fxq "$esc"`가 `tocFramework\r`에 안 걸려 격상 트리거가 무음 false가 되는 식.
#   실측으로 물린 클래스라(2026-07-27, red-baseline.sh) jq 출력은 전부 CR을 벗겨 받는다.
jqs() { printf '%s' "$STATE_JSON" | jq -r "$1" 2>/dev/null | tr -d '\r'; }

write_state() {
  mkdir -p "$STATE_DIR" 2>/dev/null || { note "state 디렉터리 생성 실패 — 갱신 생략"; exit 0; }
  tmp="$STATE_DIR/.regression-debt.$$.tmp"
  if printf '%s\n' "$1" > "$tmp" 2>/dev/null && mv -f "$tmp" "$STATE" 2>/dev/null; then
    return 0
  fi
  rm -f "$tmp" 2>/dev/null
  note "state 쓰기 실패 — 무시하고 진행"
  exit 0
}

# 파일 경로 목록(stdin) → 코드 모듈명(stdout, 중복 제거)
# 제외: .claude/** · docs/** · 루트 문서(*.md, VERSION, LICENSE*, *.txt)
derive_modules() {
  depth="$1"
  while IFS= read -r p; do
    [ -z "$p" ] && continue
    case "$p" in
      .claude/*|docs/*) continue ;;
      */*)  printf '%s\n' "$p" | cut -d/ -f1-"$depth" ;;
      *.md|*.md.template|*.template|VERSION|LICENSE|LICENSE.*|*.txt) continue ;;
      *)    printf '%s\n' "<root>" ;;
    esac
  done | sort -u
}

MODULE_DEPTH="$(jqs '.module_depth // 1')"
case "$MODULE_DEPTH" in ''|*[!0-9]*) MODULE_DEPTH=1 ;; esac
[ "$MODULE_DEPTH" -lt 1 ] 2>/dev/null && MODULE_DEPTH=1

case "$CMD" in

show)
  printf '%s\n' "$STATE_JSON"
  printf '# state: %s\n' "$STATE" >&2
  ;;

# ── set-escalation: 트리거② 격상 모듈 1회 시딩 (프로젝트 도입 시) ───────
set-escalation)
  RAW="${2:-}"
  if [ -z "$RAW" ]; then
    note "사용법: set-escalation <모듈1,모듈2>  (빈 목록으로 지우려면 set-escalation NONE)"
    exit 0
  fi
  if [ "$RAW" = "NONE" ]; then
    ESC_JSON='[]'
  else
    ESC_JSON="$(printf '%s' "$RAW" | tr ',' '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' \
                | grep -v '^$' | jq -R . | jq -s . 2>/dev/null)"
  fi
  [ -z "$ESC_JSON" ] && { note "모듈 목록 파싱 실패 — 생략"; exit 0; }

  OUT="$(printf '%s' "$STATE_JSON" | jq --argjson esc "$ESC_JSON" '.escalation_modules = $esc' 2>/dev/null)"
  [ -z "$OUT" ] && { note "설정 계산 실패 — 생략"; exit 0; }
  write_state "$OUT"
  printf '%s\n' "✅ escalation_modules = $(printf '%s' "$ESC_JSON" | jq -c .)  ($STATE)"
  ;;

# ── render: 커밋 직전 비차단 통지 1블록 ─────────────────────────────────
render)
  N="$(jqs '.commits_since | length')"
  case "$N" in ''|*[!0-9]*) N=0 ;; esac

  MODS="$(jqs '[.commits_since[].modules[]?] | unique | .[]')"
  M=0; MOD_CSV=""
  if [ -n "$MODS" ]; then
    M="$(printf '%s\n' "$MODS" | grep -c .)"
    MOD_CSV="$(printf '%s\n' "$MODS" | tr '\n' ',' | sed 's/,$//')"
  fi

  if [ -n "${REGRESSION_ESCALATION_MODULES:-}" ]; then
    ESC_LIST="$(printf '%s' "$REGRESSION_ESCALATION_MODULES" | tr ',' '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | grep -v '^$')"
  else
    ESC_LIST="$(jqs '(.escalation_modules // [])[]')"
  fi

  ESC_HIT=0; ESC_NAME=""
  if [ -n "$ESC_LIST" ] && [ -n "$MODS" ]; then
    while IFS= read -r e; do
      [ -z "$e" ] && continue
      if printf '%s\n' "$MODS" | grep -Fxq -- "$e"; then
        ESC_HIT=1; ESC_NAME="$e"; break
      fi
    done <<< "$ESC_LIST"
  fi

  if [ "$ESC_HIT" -eq 1 ] || [ "$N" -ge "$N_THRESHOLD" ]; then
    printf '%s\n' "⚠ 전체회귀 강력 권장"
    [ "$ESC_HIT" -eq 1 ] && printf '%s\n' "  - $ESC_NAME 변경 감지 (의존 모듈 전체 영향)"
    printf '%s\n' "  - 마지막 전체회귀 후: ${N}커밋"
    printf '%s\n' '  - 권장: "회귀 돌려"로 tester-runtime 전체회귀 1회'
    printf '%s\n' "  (소프트 — 차단 안 함)"
  elif [ "$N" -ge 1 ]; then
    printf '%s\n' "📊 전체회귀 부채: 후 ${N}커밋 / ${M}모듈(${MOD_CSV}). 임계 미만 — 참고."
  fi
  # N=0 & 트리거 미hit → 무출력(노이즈 방지)
  ;;

# ── update: 커밋 직후 state 갱신 (코드 모듈 터친 커밋만 카운트) ──────────
update)
  SHA="$(git rev-parse HEAD 2>/dev/null)"
  if [ -z "$SHA" ]; then note "HEAD 산정 실패 — 갱신 생략"; exit 0; fi

  FILES="$(git show --name-only --format= HEAD 2>/dev/null)"
  NEW_MODS="$(printf '%s\n' "$FILES" | derive_modules "$MODULE_DEPTH")"
  if [ -z "$NEW_MODS" ]; then
    note "코드 모듈 미터치 커밋 — 카운트 제외"
    exit 0
  fi

  MODS_JSON="$(printf '%s\n' "$NEW_MODS" | jq -R . | jq -s . 2>/dev/null)"
  [ -z "$MODS_JSON" ] && { note "모듈 JSON 변환 실패 — 갱신 생략"; exit 0; }

  TS="$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null)"
  OUT="$(printf '%s' "$STATE_JSON" | jq \
    --arg sha "$SHA" --arg ts "$TS" --argjson mods "$MODS_JSON" '
      if ([.commits_since[].sha] | index($sha)) then .
      else .commits_since += [{sha:$sha, modules:$mods, ts:$ts}] end
    ' 2>/dev/null)"
  [ -z "$OUT" ] && { note "state 갱신 계산 실패 — 생략"; exit 0; }

  BEFORE="$(jqs '.commits_since | length')"
  AFTER="$(printf '%s' "$OUT" | jq -r '.commits_since | length' 2>/dev/null | tr -d '\r')"
  write_state "$OUT"
  if [ "$BEFORE" = "$AFTER" ]; then
    note "이미 카운트된 sha=${SHA:0:7} — 중복 append 스킵"
  else
    note "부채 +1 (sha=${SHA:0:7}, modules=$(printf '%s\n' "$NEW_MODS" | tr '\n' ',' | sed 's/,$//'))"
  fi
  ;;

# ── reset: 전체회귀 PASS 시 (tester-runtime 전용) ───────────────────────
reset)
  SHA="$(git rev-parse HEAD 2>/dev/null)"
  if [ -z "$SHA" ]; then note "HEAD 산정 실패 — 리셋 생략"; exit 0; fi
  TS="$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null)"

  OUT="$(printf '%s' "$STATE_JSON" | jq --arg sha "$SHA" --arg ts "$TS" '
    .last_full_regression = {sha:$sha, ts:$ts} | .commits_since = []
  ' 2>/dev/null)"
  [ -z "$OUT" ] && { note "리셋 계산 실패 — 생략"; exit 0; }

  write_state "$OUT"
  printf '%s\n' "✅ 전체회귀 부채 리셋 — 기준 sha=${SHA:0:7}"
  ;;

esac

exit 0
