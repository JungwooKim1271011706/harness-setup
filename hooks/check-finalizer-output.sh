#!/bin/bash
# SubagentStop(finalizer) 훅 — 기능 트랙 커밋에 사람 E2E 런북(## 수동 E2E 검증)이
#   feature 문서로 들어갔나 기계검증. finalizer.md '사람 E2E 점검 안내' 절차의 enforce 보강.
# 목적: finalizer.md에 절차는 있으나 강제 메커니즘이 없어 다른 세션에서 E2E 점검표가
#   조용히 누락되던 문제(v3.7.0부터 프롬프트 의존, 훅 부재) → planner 훅과 동형으로 잡는다.
#
# ⚠ 경고모드: decision:block / exit 2 안 함. additionalContext로 경고만 주입(false-positive 대비).
#   planner 훅(check-planner-output.sh)과 동일 신중 — 안정화되면 차단 승격 검토.
#
# 동작: finalizer는 커밋 직후 종료 → HEAD = 이번 트랙 커밋. 이 커밋이 건드린 feature 문서에
#   '## 수동 E2E 검증' 섹션이 없으면 경고. feature 문서 미변경(단순수정·문서·하네스 자기수정)은 면제.

PROJECT_DIR=$(git rev-parse --show-toplevel 2>/dev/null)
[ -z "$PROJECT_DIR" ] && exit 0
cd "$PROJECT_DIR" || exit 0

# 이번 트랙 최종 커밋(HEAD)이 건드린 feature 문서
FEATFILES=$(git log -1 --name-only --pretty=format: 2>/dev/null | grep -E '^docs/features/.*\.md$')
# 기능 트랙 아님(feature 문서 미변경) → 사람 E2E 점검 불요 → 조용히 면제
[ -z "$FEATFILES" ] && exit 0

MISSING=()
while IFS= read -r f; do
  [ -z "$f" ] && continue
  [ -f "$f" ] || continue
  grep -q '## 수동 E2E 검증' "$f" || MISSING+=("$f")
done <<< "$FEATFILES"

# 모든 feature 문서에 런북 섹션 있으면 통과
[ ${#MISSING[@]} -eq 0 ] && exit 0

WARN="🔍 [finalizer E2E 가드] 기능 트랙 커밋인데 feature 문서에 '## 수동 E2E 검증' 런북이 없음: "
for m in "${MISSING[@]}"; do WARN="${WARN}[${m}] "; done
WARN="${WARN}— finalizer는 사람 E2E 점검 런북을 콘솔 출력 + feature 문서에 append해야 한다(비차단 = 출력 필수, 생략 ≠ 비차단). 누락이면 런북 생성·append (경고: 차단 아님)."

ESCAPED=$(printf '%s' "$WARN" | sed 's/\\/\\\\/g; s/"/\\"/g')
printf '{"hookSpecificOutput":{"hookEventName":"SubagentStop","additionalContext":"%s"}}' "$ESCAPED"
exit 0
