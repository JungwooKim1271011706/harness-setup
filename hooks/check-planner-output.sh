#!/bin/bash
# SubagentStop(planner-*) 훅 — planner 산출 계획서(feature 문서) 형식 기계검증.
# 목적: orchestrator.md '계획서 형식 검증'(글 권고, LLM 자율) → 기계강제(경고모드).
#   백로그 #6. PreToolUse(사전차단)에 더해 SubagentStop(사후 산출물검증)으로 enforce 보강.
#
# 동작: planner-* 종료 시, 가장 최근 docs/features/*.md를 찾아 필수 섹션 존재 검사.
#   누락 시 hookSpecificOutput.additionalContext로 경고 주입(차단 아님 — false-positive 대비).
#   conversation 계속되므로 orchestrator가 경고 받고 재작성 판단 가능.
#
# ⚠ 경고모드: decision:block / exit 2 안 함. v1은 형식 과적합 false-positive 리스크라 경고만.
#   안정화되면 차단 승격 검토.

PROJECT_DIR=$(git rev-parse --show-toplevel 2>/dev/null)
[ -z "$PROJECT_DIR" ] && exit 0

FEAT_DIR="$PROJECT_DIR/docs/features"
[ -d "$FEAT_DIR" ] || exit 0

# 가장 최근 수정된 feature 문서 (이 planner가 방금 쓴 것으로 간주 — 5분 이내만)
DOC=$(find "$FEAT_DIR" -maxdepth 1 -name "*.md" -mmin -5 -type f 2>/dev/null | sort -r | head -1)
# 5분 이내가 없으면(드묾) 최근 1개로 폴백하지 않고 조용히 종료(오탐 방지)
[ -z "$DOC" ] && exit 0

MISSING=()
# 필수 형식 (orchestrator.md '계획서 형식 검증' 기준)
grep -q '### 기존 시나리오' "$DOC" || MISSING+=("### 기존 시나리오 섹션")
grep -q '### 신규 시나리오' "$DOC" || MISSING+=("### 신규 시나리오 섹션")
grep -qE '^##[[:space:]]*흐름[[:space:]]*[0-9]' "$DOC" || MISSING+=("## 흐름 N: 제목")
# 흐름 제목 바로 아래 '> ' 인용구 설명 — 흐름이 있는데 인용구가 0이면 누락 의심
if grep -qE '^##[[:space:]]*흐름[[:space:]]*[0-9]' "$DOC"; then
  grep -qE '^>[[:space:]]' "$DOC" || MISSING+=("흐름 설명용 '> ' 인용구")
fi

# 누락 없으면 조용히 통과
[ ${#MISSING[@]} -eq 0 ] && exit 0

DOCREL="${DOC#$PROJECT_DIR/}"
WARN="🔎 [planner 산출물 형식검증] ${DOCREL} 에 누락: "
for m in "${MISSING[@]}"; do WARN="${WARN}[${m}] "; done
WARN="${WARN}— 사용자 승인 전 planner 재작성으로 형식 보강 권장 (경고: 차단 아님)."

ESCAPED=$(printf '%s' "$WARN" | sed 's/\\/\\\\/g; s/"/\\"/g')
printf '{"hookSpecificOutput":{"hookEventName":"SubagentStop","additionalContext":"%s"}}' "$ESCAPED"
exit 0
