#!/bin/bash
# SessionStart hook: 실패 패턴 및 스킬 동기화 상태 자동 점검
PROJECT_DIR=$(git rev-parse --show-toplevel 2>/dev/null)
if [ -z "$PROJECT_DIR" ]; then
  exit 0
fi

MESSAGES=()

# 1) failure 패턴 미처리 건수 체크
FAIL_COUNT=$(find "$PROJECT_DIR/.claude/agent-memory" -name "failure_*.md" 2>/dev/null | wc -l | tr -d ' ')
if [ "$FAIL_COUNT" -gt 0 ]; then
  MESSAGES+=("⚠ 미처리 실패 패턴 ${FAIL_COUNT}건 — 하네스 자가 점검 권장 (/harness-check)")
fi

# 2) 스킬 동기화 날짜 체크 (versions.md 기준 7일 초과 시 경고)
VERSIONS="$PROJECT_DIR/.claude/skills/versions.md"
if [ -f "$VERSIONS" ]; then
  LAST_SYNC=$(grep -o '[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}' "$VERSIONS" | head -1)
  if [ -n "$LAST_SYNC" ]; then
    TODAY=$(date +%Y-%m-%d)
    # macOS(date -j) / Linux(date -d) 모두 지원
    if date --version 2>/dev/null | grep -q GNU; then
      TODAY_TS=$(date -d "$TODAY" +%s 2>/dev/null)
      SYNC_TS=$(date -d "$LAST_SYNC" +%s 2>/dev/null)
    else
      TODAY_TS=$(date -j -f "%Y-%m-%d" "$TODAY" +%s 2>/dev/null)
      SYNC_TS=$(date -j -f "%Y-%m-%d" "$LAST_SYNC" +%s 2>/dev/null)
    fi
    if [ -n "$TODAY_TS" ] && [ -n "$SYNC_TS" ]; then
      DAYS=$(( (TODAY_TS - SYNC_TS) / 86400 ))
      if [ "$DAYS" -ge 7 ]; then
        MESSAGES+=("⚠ 스킬 동기화 ${DAYS}일 경과 (마지막: ${LAST_SYNC}) — sync-skills.sh 실행 권장")
      fi
    fi
  fi
fi

# 메시지 없으면 조용히 종료
if [ ${#MESSAGES[@]} -eq 0 ]; then
  exit 0
fi

# Claude 컨텍스트에 주입 (additionalContext)
CONTEXT=""
for msg in "${MESSAGES[@]}"; do
  CONTEXT="${CONTEXT}${msg}\n"
done
# JSON 특수문자 이스케이프
ESCAPED=$(printf '%s' "$CONTEXT" | sed 's/\\/\\\\/g; s/"/\\"/g')
printf '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"%s"}}' "$ESCAPED"
