#!/usr/bin/env bash
# panel-metrics.sh — 설계패널 실행 계측 (재게이트 파급 축이 실제로 값을 내나)
#
# 왜 필요한가:
#   재게이트 LOOP마다 페르소나 **전원**이 도는 설계의 근거는 *"1회차 수정이 다른 렌즈
#   영역에 결함을 만든다"*(파급 축)인데, 그 근거의 관측은 **n=1**이다(백로그 2026-07-01).
#   n=1로 worst-case 스폰의 상당 비중을 정당화하는 건 과한 추론이라, 실데이터를 모은다.
#
#   ⚠ **이 스크립트는 판정하지 않는다.** 게이트 구조 변경(페르소나 축소 등)은
#   사람 승인 사항이고, 여기서는 재론에 필요한 숫자만 만든다.
#
# 왜 orchestrator가 호출하나:
#   `design-panel.js`는 Workflow 런타임이라 **파일시스템 접근이 없다**(스크립트 :146 주석).
#   따라서 계측은 패널 산출을 수령한 **orchestrator**(Bash 보유)가 한다.
#
# Usage:
#   패널 산출 수령 직후:
#     echo '<JSON>' | bash .claude/scripts/panel-metrics.sh log
#   판단이 필요할 때:
#     bash .claude/scripts/panel-metrics.sh report
#     bash .claude/scripts/panel-metrics.sh show     # 원본 JSONL 덤프
#
# 입력 JSON (orchestrator가 이미 들고 있는 값들로 조립):
#   {
#     "round": 2,                       // 이번 패널이 몇 번째 실행인가 (최초=1)
#     "reGate": true,                   // 워크플로 반환의 reGate
#     "priorPersonas": ["eng"],         // 직전 라운드 **생존** critical을 낸 페르소나(코드대조 통과분)
#     "perPersona": [ {"persona":"eng","criticals":0,"total":2,"model":"..."} ],
#     "failures": []                    // 워크플로 반환의 failures
#   }
#
# ── 불변식 ───────────────────────────────────────────────────────────────
#   - 어떤 실패에서도 exit 0. 계측이 게이트를 막지 않는다.
#   - 판정·차단 없음. report는 숫자와 "판단 필요" 표시만 낸다.
#   - state는 repo 밖(`~/.gstack/projects/{slug}/`) — 하네스 미오염.

set -uo pipefail

note() { printf '%s\n' "panel-metrics: $*" >&2; }

# ⚠ Windows 네이티브 jq는 stdout에 CRLF를 쓴다 → 문자열 비교가 무음으로 어긋난다.
#   wiki/jq-crlf-stdout-windows.md. jq 출력은 전부 이걸로 받는다.
jqr() { jq -r "$@" 2>/dev/null | tr -d '\r'; }

CMD="${1:-report}"
case "$CMD" in
  log|report|show) ;;
  -h|--help|help) sed -n '2,30p' "$0"; exit 0 ;;
  *) note "알 수 없는 명령 '$CMD' (log|report|show)"; exit 0 ;;
esac

command -v jq >/dev/null 2>&1 || { note "jq 없음 — 생략"; exit 0; }

SLUG=""
SLUG_BIN="$HOME/.claude/skills/gstack/bin/gstack-slug"
[ -x "$SLUG_BIN" ] && { eval "$("$SLUG_BIN" 2>/dev/null)" 2>/dev/null || true; }
[ -z "${SLUG:-}" ] && { note "slug 산정 실패(gstack 미설치?) — 생략"; exit 0; }

STATE_DIR="$HOME/.gstack/projects/$SLUG"
LOG="$STATE_DIR/panel-metrics.jsonl"

case "$CMD" in

show)
  [ -f "$LOG" ] && cat "$LOG" || printf '%s\n' "(계측 없음: $LOG)"
  ;;

# ── log: 패널 1회 실행 기록 ──────────────────────────────────────────────
log)
  IN="$(cat)"
  if ! printf '%s' "$IN" | jq -e . >/dev/null 2>&1; then
    note "입력이 JSON이 아님 — 기록 생략(게이트 영향 없음)"; exit 0
  fi

  TS="$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null)"
  SHA="$(git rev-parse --short HEAD 2>/dev/null || echo '?')"

  # 파생 지표 — 이게 이 계측의 존재 이유다.
  #   ripple = 직전에 critical을 내지 **않은** 페르소나가 이번에 낸 critical
  #            (= 파급 축이 실제로 발화한 경우. 페르소나 축소했으면 놓쳤을 건들)
  #   own    = 직전 발견자가 이번에도 낸 critical (해소 미흡 또는 새 결함)
  # ⚠ ripple/own은 **재게이트에서만 의미가 있다.** 최초 라운드는 priorPersonas가 비어
  #   "직전 발견자가 아닌 페르소나"에 전원이 해당돼 버린다(= 전원 파급으로 오집계).
  #   report는 reGate 필터로 걸러내지만, **필드 자체가 오해를 팔면 안 된다** → 최초
  #   라운드엔 빈 배열로 고정한다(집계 이중안전 + show 덤프 육안 오독 방지).
  OUT="$(printf '%s' "$IN" | jq -c --arg ts "$TS" --arg sha "$SHA" '
    (.reGate // false) as $rg
    | (.priorPersonas // []) as $prior
    | (.perPersona // []) as $pp
    | ($pp | map(select((.criticals // 0) > 0))) as $hit
    | {
        ts: $ts, sha: $sha,
        round: (.round // 1),
        reGate: $rg,
        priorPersonas: $prior,
        personas: ($pp | map(.persona)),
        criticalsTotal: ($pp | map(.criticals // 0) | add // 0),
        ripplePersonas: (if $rg then ($hit | map(select(.persona as $k | $prior | index($k) | not)) | map(.persona)) else [] end),
        ownPersonas:    (if $rg then ($hit | map(select(.persona as $k | $prior | index($k)))      | map(.persona)) else [] end),
        failures: (.failures // []),
        models: ($pp | map({(.persona): (.model // "?")}) | add // {})
      }' 2>/dev/null)"
  [ -z "$OUT" ] && { note "파생 지표 계산 실패 — 기록 생략"; exit 0; }

  mkdir -p "$STATE_DIR" 2>/dev/null || { note "디렉터리 생성 실패 — 생략"; exit 0; }
  printf '%s\n' "$OUT" >> "$LOG" 2>/dev/null || { note "기록 실패 — 생략"; exit 0; }

  R="$(printf '%s' "$OUT" | jqr '.round')"
  G="$(printf '%s' "$OUT" | jqr '.reGate')"
  if [ "$G" = "true" ]; then
    RIP="$(printf '%s' "$OUT" | jqr '.ripplePersonas | join(",")')"
    note "기록 (round=$R, 재게이트, 파급발화=${RIP:-없음})"
  else
    C="$(printf '%s' "$OUT" | jqr '.criticalsTotal')"
    note "기록 (round=$R, 최초, critical=${C})"
  fi
  ;;

# ── report: 누적 요약 (출력 ≤6줄) ────────────────────────────────────────
report)
  if [ ! -f "$LOG" ]; then
    printf '%s\n' "📊 패널 계측 0건 — 아직 판단 근거 없음. (재게이트 구조 변경은 데이터 확보 후)"
    exit 0
  fi

  N="$(grep -c . "$LOG" 2>/dev/null || echo 0)"
  RG="$(jqr 'select(.reGate == true) | 1' "$LOG" | grep -c . || true)"
  RIPRUNS="$(jqr 'select(.reGate == true and (.ripplePersonas | length) > 0) | 1' "$LOG" | grep -c . || true)"
  RIPDIST="$(jqr 'select(.reGate == true) | .ripplePersonas[]?' "$LOG" | sort | uniq -c | sort -rn \
             | awk '{printf "%s×%s ", $2, $1}')"
  FAILS="$(jqr '.failures[]?' "$LOG" | sort | uniq -c | sort -rn | awk '{printf "%s×%s ", $2, $1}')"

  printf '%s\n' "📊 설계패널 계측 — 패널 ${N}회 (재게이트 ${RG}회)"
  if [ "${RG:-0}" -eq 0 ]; then
    printf '%s\n' "   재게이트 표본 0 — 파급 축 판단 불가. 최소 2~3회 쌓인 뒤 재론."
    exit 0
  fi
  printf '%s\n' "   파급 축 발화: ${RIPRUNS}/${RG}회 — 직전 발견자가 **아닌** 페르소나가 신규 critical 산출"
  [ -n "$RIPDIST" ] && printf '%s\n' "   발화 페르소나: $RIPDIST"
  [ -n "$FAILS" ]   && printf '%s\n' "   ⚠ 페르소나 사망 누적: $FAILS (완전성 재런치 트리거 이력)"
  if [ "${RIPRUNS:-0}" -eq 0 ]; then
    printf '%s\n' "   → 발화 0. '전원 재실행' 근거가 약해진다 — 페르소나 축소 재론 가치 있음(사람 판단)."
  else
    printf '%s\n' "   → 발화 있음. 페르소나 축소했다면 이 건들을 놓쳤다 — 현 설계 유지 근거."
  fi
  ;;

esac

exit 0
