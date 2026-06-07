#!/bin/bash
# PreToolUse(Edit|Write|MultiEdit) 훅 — orchestrator 메인스레드의 제품소스 직접편집 차단.
# 판별: agent_id 없음 = orchestrator 메인. 있음 = 서브에이전트(developer-*/finalizer) → 허용.
# 차단리스트 방식: 제품모듈(tocServer/tocProcess/tocFramework)만 deny.
#   그 외(.claude/ 하네스 자가수정, agent-memory, docs/)는 메인도 허용 → 하네스 self-edit 안 깨짐.
# 차단 시 exit 2 + stderr → Claude가 사유 받고 developer-* 위임으로 전환.
#
# 알려진 구멍(v1, 의도적 비차단): Bash `sed -i`/`tee`로 제품소스 편집은 이 훅이 못 잡는다.
#   Edit/Write/MultiEdit 도구만 대상. orchestrator가 sed로 소스편집할 현실 트리거가 거의 0이라
#   봉쇄로직 복잡도 대비 실익 없어 v1 제외. 필요 시 block-orchestrator-exec.sh(Bash 훅) 확장.

input=$(cat)

# jq 있으면 사용, 없으면 grep 폴백
if command -v jq >/dev/null 2>&1; then
  agent_id=$(printf '%s' "$input" | jq -r '.agent_id // empty' 2>/dev/null)
  file_path=$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
else
  # 폴백(jq 부재): 값만 거칠게 추출. file_path 값만 잡아 오탐 감소.
  agent_id=$(printf '%s' "$input" | sed -n 's/.*"agent_id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
  file_path=$(printf '%s' "$input" | sed -n 's/.*"file_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
fi

# 서브에이전트(agent_id 존재) → 허용 (developer-* 구현, finalizer 정리 등 정상)
[ -n "$agent_id" ] && exit 0

# 메인 orchestrator: 제품모듈 경로면 차단. 경로구분자(/ 또는 \) 뒤 디렉터리로 매치.
# 절대경로(C:/.../sb/tocServer/...)·상대경로(tocServer/...) 둘 다 잡는다.
# .claude/ 하위는 tocServer 등이 안 들어가므로 자가수정은 통과.
if printf '%s' "$file_path" | grep -qiE '(^|[/\\])(tocServer|tocProcess|tocFramework)[/\\]'; then
  echo "[hook] 오케스트레이터 제품소스 직접편집 금지 — 구현·수정은 developer-backend/developer-frontend에 위임하라. (차단 file_path: ${file_path})" >&2
  exit 2
fi

exit 0
