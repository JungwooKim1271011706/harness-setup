#!/bin/bash
# Stop 훅 백스톱: 워크플로 운영 고통 신호를 결정적으로 탐지해 /harness-check 호출을 강제한다.
#   orchestrator post_commit 자가점검(소프트 = 모델이 기억해야 발동)이 자주 새는 문제의 enforcement 보강.
#
# 왜 decision:block 인가: 훅(command형)은 스킬을 직접 실행 못 한다 — 컨텍스트 주입/Stop 차단만 가능.
#   Stop을 막아(reason 피드백) 모델이 turn 종료 전에 /harness-check를 돌리게 강제한다. 신호당 1회(지문 스탬프).
# 왜 안전한가: harness-check는 탐지·초안까지만(detection-only). 실제 하네스 수정은 /harness-retro 승인 게이트.
#   = 자동 발동해도 거버넌스 불변식(자동수정 금지·사람승인) 안 깸. 거버넌스 게이트 변경 아님.
#
# 두 모드:
#   --seed (SessionStart에서 호출): 세션 시작 시점 신호 지문을 baseline으로 기록(차단 안 함). 기존 고통엔 안 터지게.
#   (기본, Stop에서 호출): 현재 지문 vs baseline. 신규 고통이면 1회 block + 스탬프 갱신.
#
# 신호(셸 탐지 가능한 결정적 아티팩트만):
#   (1) failure_*.md — ESCALATION/중단 기록 (agent-memory).
#   (2) 체크포인트 [LOOP 2/3]|[LOOP 3/3] — 과다 루프(결국 PASS여도). post_commit 자가회고 신호와 동일.

MODE="${1:-stop}"
INPUT=$(cat 2>/dev/null)
PROJECT_DIR=$(git rev-parse --show-toplevel 2>/dev/null)
[ -z "$PROJECT_DIR" ] && exit 0

SESSION_ID=$(printf '%s' "$INPUT" | sed -n 's/.*"session_id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
[ -z "$SESSION_ID" ] && SESSION_ID="ppid-$PPID"
SAFE_SID=$(printf '%s' "$SESSION_ID" | tr '/ :' '___')

STATE_DIR="$PROJECT_DIR/.claude/state"
STAMP="$STATE_DIR/harness-check-backstop-${SAFE_SID}.stamp"

# --- 신호 지문 계산 ---
FAIL_COUNT=$(find "$PROJECT_DIR/.claude/agent-memory" -name "failure_*.md" 2>/dev/null | wc -l | tr -d ' ')

GSTACK_SLUG=""
GSTACK_SLUG_BIN="${HOME}/.claude/skills/gstack/bin/gstack-slug"
if [ -x "$GSTACK_SLUG_BIN" ]; then
  eval "$("$GSTACK_SLUG_BIN" 2>/dev/null)" 2>/dev/null || true
  GSTACK_SLUG="${SLUG:-}"
fi
[ -z "$GSTACK_SLUG" ] && GSTACK_SLUG=$(basename "$PROJECT_DIR")
CKPT_DIR="${HOME}/.gstack/projects/${GSTACK_SLUG}/checkpoints"
LOOP_HIT=""
if [ -d "$CKPT_DIR" ]; then
  CKPT_FILES=$(find "$CKPT_DIR" -maxdepth 1 -name '*.md' -mtime -1 2>/dev/null)
  if [ -n "$CKPT_FILES" ]; then
    # xargs로 파일이 있을 때만 grep (stdin hang 방지). 최신 LOOP≥2 체크포인트 1개.
    LOOP_HIT=$(printf '%s\n' "$CKPT_FILES" | xargs grep -lE '\[LOOP [23]/3\]' 2>/dev/null | head -1)
  fi
fi

LOOP_FP=$([ -n "$LOOP_HIT" ] && basename "$LOOP_HIT" || echo none)
FP="fail=${FAIL_COUNT};loop=${LOOP_FP}"

mkdir -p "$STATE_DIR" 2>/dev/null || true
# 오래된 백스톱 스탬프 청소 (mtime +1일)
find "$STATE_DIR" -maxdepth 1 -name 'harness-check-backstop-*.stamp' -mtime +1 -type f -delete 2>/dev/null || true

# --- seed 모드: baseline만 기록(차단 안 함). 이미 있으면(resume/compact) 보존. ---
if [ "$MODE" = "--seed" ]; then
  [ ! -f "$STAMP" ] && printf '%s' "$FP" > "$STAMP" 2>/dev/null
  exit 0
fi

# --- stop 모드 ---
# 고통 신호 없으면(fail=0 & loop=none) 조용히 종료.
[ "$FAIL_COUNT" -eq 0 ] && [ -z "$LOOP_HIT" ] && exit 0

# baseline과 동일 지문이면 이미 처리/넛지함 → 침묵(반복 강제 방지).
PREV=""
[ -f "$STAMP" ] && PREV=$(cat "$STAMP" 2>/dev/null)
[ "$FP" = "$PREV" ] && exit 0

# 신규 고통 → 지문 먼저 갱신(루프 방지: 모델 미준수해도 다음 Stop은 동일지문→허용) 후 1회 block.
printf '%s' "$FP" > "$STAMP" 2>/dev/null || true

SIG=""
[ "$FAIL_COUNT" -gt 0 ] && SIG="${SIG}실패패턴 ${FAIL_COUNT}건, "
[ -n "$LOOP_HIT" ] && SIG="${SIG}과다루프 LOOP≥2, "
SIG=${SIG%, }

REASON="🔧 하네스 운영 고통 감지(${SIG}) — orchestrator post_commit 자가점검이 누락된 듯하다. turn 종료 전에 /harness-check 를 Skill 도구로 1회 호출해 개선 후보를 만들어라(탐지·초안까지만; 적용은 /harness-retro 승인 게이트). 후보 0건이면 harness-check가 조용히 종료한다 — 그 뒤 바로 멈춰도 된다."
ESCAPED=$(printf '%s' "$REASON" | sed 's/\\/\\\\/g; s/"/\\"/g')
printf '{"decision":"block","reason":"%s"}' "$ESCAPED"
