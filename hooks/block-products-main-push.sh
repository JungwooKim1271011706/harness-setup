#!/bin/bash
# PreToolUse(Bash) 훅 — 사내 products 그룹의 보호 main(master/main) 직접 push 차단.
# 근거: 사내 정책(§02 3.1) products master = Protected, MR만 허용. 풀사이클(개인실험)이
#       실수로 사내 products main을 직접 오염하는 것을 막는 안전망(서버측 Protected의 보강).
# 적용 범위: 메인 orchestrator + 모든 서브에이전트(특히 finalizer가 pusher) → agent_id 게이트 없음.
# 통과: 개인 브랜치 push, *_WI_* 브랜치 push(봇 워크플로), products 외 remote, push 아닌 명령.
# 차단 시 exit 2 + stderr.
#
# 알려진 구멍(v1 의도적 비차단, 현실 트리거 ~0):
#  - explicit-URL 없이 비표준 remote명으로 push 시 origin만 해석.
#  - refspec 우회(HEAD:master 등) 일부 형태는 textual 매치 한계.
# 정확 봉쇄는 서버측 Protected branch가 1차 담당. 본 훅은 클라이언트 보강.

input=$(cat)

if command -v jq >/dev/null 2>&1; then
  command=$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null)
  cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)
else
  command=$(printf '%s' "$input" | sed -n 's/.*"command"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
  cwd=$(printf '%s' "$input" | sed -n 's/.*"cwd"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
fi

# git push 아니면 통과
printf '%s' "$command" | grep -qiE '(^|[;&|[:space:]])git[[:space:]].*push' || exit 0

# 푸시 대상 remote URL 해석: 명령에 명시 URL 있으면 사용, 없으면 cwd의 origin
url=$(printf '%s' "$command" | grep -oE 'https?://[^ ]+' | head -1)
if [ -z "$url" ]; then
  url=$(git -C "${cwd:-.}" remote get-url origin 2>/dev/null)
fi

# 사내 products 그룹 아니면 통과
printf '%s' "$url" | grep -qE '10\.1\.1\.10:9090/crinity/products/' || exit 0

# WI 작업 브랜치(*_WI_*)는 봇 워크플로 정상 흐름 → 통과
printf '%s' "$command" | grep -qE '_WI_' && exit 0

# 타겟 브랜치가 master/main 이면 차단 (명시 인자 우선, 없으면 현재 브랜치)
target_is_main=0
if printf '%s' "$command" | grep -qE '(^|[[:space:]:])(master|main)([[:space:]]|:|$)'; then
  target_is_main=1
else
  branch=$(git -C "${cwd:-.}" rev-parse --abbrev-ref HEAD 2>/dev/null)
  printf '%s' "$branch" | grep -qE '^(master|main)$' && target_is_main=1
fi

if [ "$target_is_main" -eq 1 ]; then
  echo "[hook] 사내 products 보호 main 직접 push 금지 — 풀사이클(개인실험)은 사내 main에 올리지 않는다. 사내 반영은 설계모드 WI → 봇이 <base>_WI_<id> 브랜치+MR로 처리한다. (차단 command: ${command})" >&2
  exit 2
fi

exit 0
