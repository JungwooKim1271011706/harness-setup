#!/bin/bash
# SessionStart hook: 소비자 clone의 하네스를 SSOT(origin/main)와 자동 동기화한다.
#
# 문제: 소비자 `.claude`는 프로젝트마다 독립 nested clone이라 사람이 `git -C .claude pull`을
#       기억해야만 갱신된다. 안 하면 조용히 뒤처진다(2026-07-26 실측: repostitch가 17커밋·16버전 뒤).
#       session-check의 버전 drift 감지는 "세션 스탬프 vs 로컬 VERSION" 비교라 둘 다 로컬 —
#       아무도 pull을 안 하면 영원히 침묵한다. 즉 stale을 알려주는 장치가 없었다.
# 왜 소비자 쪽인가: dev clone에서 팬아웃하려면 소비자 경로 레지스트리가 필요하고(git엔 client
#       post-push 훅이 없다) 등록 누락 시 같은 실패가 재발한다. 소비자가 당기면 레지스트리 불요 =
#       새 프로젝트도 자동 포함(self-healing).
# 안전: SessionStart는 agent md를 읽기 **전**이라 파일 교체가 가장 안전한 시점이다.
#       `--ff-only`라 소비자가 로컬 커밋을 해버린 경우(하네스 직접커밋 금지 위반) merge 대신
#       실패하며 드러난다 — 오히려 탐지기. 자동 병합·자동 커밋은 하지 않는다.
# 범위: 배포(승인된 SSOT를 받아오기)만 자동. 하네스 **저작**은 여전히 사람 승인 게이트(불변식).
# 분리 이유: session-check.sh(timeout 10)에 넣으면 느린 pull이 훅을 죽여 다른 경고까지 유실된다.
set -u

INPUT=$(cat 2>/dev/null)
PROJECT_DIR=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0
[ -z "$PROJECT_DIR" ] && exit 0

CLAUDE_DIR="$PROJECT_DIR/.claude"
# dev clone(하네스 자체가 repo 루트)엔 .claude가 없다 → 자동 no-op. 자기 자신은 안 당긴다.
[ -d "$CLAUDE_DIR" ] || exit 0
[ -e "$CLAUDE_DIR/.git" ] || exit 0

# source=startup 에서만. resume/compact/clear는 세션 도중이라 교체하면 안 된다.
SOURCE=$(printf '%s' "$INPUT" | sed -n 's/.*"source"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
[ "$SOURCE" = "startup" ] || exit 0

# throttle — 1일 1회. 세션을 자주 여는 날 매번 네트워크 물지 않게.
STATE_DIR="$CLAUDE_DIR/state"
STAMP="$STATE_DIR/autopull.last"
mkdir -p "$STATE_DIR" 2>/dev/null || true
NOW_TS=$(date +%s)
if [ -f "$STAMP" ]; then
  LAST=$(cat "$STAMP" 2>/dev/null)
  case "$LAST" in '' | *[!0-9]*) LAST=0 ;; esac
  [ $((NOW_TS - LAST)) -lt 86400 ] && exit 0
fi
printf '%s\n' "$NOW_TS" > "$STAMP" 2>/dev/null || true

BEFORE=$(grep -oE '[0-9]+\.[0-9]+\.[0-9]+' "$CLAUDE_DIR/VERSION" 2>/dev/null | head -1)

# --ff-only: 로컬 커밋·발산이 있으면 병합하지 않고 실패한다(의도).
# timeout: 오프라인·느린 망에서 세션 시작을 붙잡지 않게.
OUT=$(timeout 8 git -C "$CLAUDE_DIR" pull --ff-only --no-rebase 2>&1)
RC=$?

AFTER=$(grep -oE '[0-9]+\.[0-9]+\.[0-9]+' "$CLAUDE_DIR/VERSION" 2>/dev/null | head -1)

MSG=""
if [ "$RC" -eq 0 ]; then
  if [ -n "$BEFORE" ] && [ -n "$AFTER" ] && [ "$BEFORE" != "$AFTER" ]; then
    if [ "${BEFORE%%.*}" != "${AFTER%%.*}" ]; then
      MSG="🔄 하네스 자동 갱신 v${BEFORE} → v${AFTER} (MAJOR) — 거버넌스·게이트 구조가 바뀌었다. 사용자에게 변경점 확인을 안내할 것 (CHANGELOG)."
    else
      MSG="🔄 하네스 자동 갱신 v${BEFORE} → v${AFTER} — 이 세션은 갱신된 정의로 시작한다."
    fi
  fi
elif [ "$RC" -eq 124 ]; then
  : # 네트워크 타임아웃 — 침묵(오프라인 작업 방해 금지)
else
  # ff 불가 = 소비자 clone에 로컬 커밋/발산이 있다. 하네스 직접커밋 금지 위반 신호.
  case "$OUT" in
    *"Not possible to fast-forward"* | *"diverged"* | *"non-fast-forward"*)
      MSG="⚠ 하네스 자동 갱신 실패 (fast-forward 불가) — .claude에 로컬 커밋이 있다(소비자 세션 하네스 직접커밋 금지 위반 의심). 수동 확인: git -C .claude log origin/main..HEAD"
      ;;
    *"local changes"* | *"would be overwritten"*)
      MSG="⚠ 하네스 자동 갱신 실패 — .claude에 커밋 안 된 변경이 있다. 수동 확인: git -C .claude status"
      ;;
  esac
fi

# SSOT 미반영 로컬 커밋 감지 — behind 없이 ahead만이면 `pull --ff-only`가 "up to date"로 **성공**해
# 위 분기가 침묵한다. 그 커밋은 제품 repo에 갇혀 SSOT에 영영 안 올라간다(2026-07-15 사고 클래스).
AHEAD=$(git -C "$CLAUDE_DIR" rev-list --count origin/main..HEAD 2>/dev/null)
case "$AHEAD" in '' | *[!0-9]*) AHEAD=0 ;; esac
if [ "$AHEAD" -gt 0 ]; then
  MSG="⚠ .claude에 SSOT 미반영 로컬 커밋 ${AHEAD}건 — 소비자 세션 하네스 직접커밋 금지 위반 의심(제품 repo에 갇혀 SSOT가 못 받는다). 확인: git -C .claude log origin/main..HEAD${MSG:+ / $MSG}"
fi

[ -z "$MSG" ] && exit 0
ESCAPED=$(printf '%s' "$MSG" | sed 's/\\/\\\\/g; s/"/\\"/g')
printf '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"%s"}}' "$ESCAPED"
