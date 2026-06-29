#!/bin/bash
# PreToolUse(Bash) 훅 — orchestrator 메인스레드의 직접 commit/build/test/배포 차단.
# 판별: agent_id 없음 = orchestrator 메인. 있음 = 서브에이전트(finalizer/tester 등) → 허용.
# 외과적: git status/log/diff, curl, ls, grep 등 일반 Bash는 통과. commit/push/build/test만 차단.
# 차단 시 exit 2 + stderr → Claude가 사유 받고 위임으로 전환.

input=$(cat)

# jq 있으면 사용, 없으면 grep 폴백
if command -v jq >/dev/null 2>&1; then
  agent_id=$(printf '%s' "$input" | jq -r '.agent_id // empty' 2>/dev/null)
  command=$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null)
else
  # 폴백(jq 부재): 값만 거칠게 추출. command는 JSON 전체가 아니라 tool_input.command 값만
  # 잡아 오탐 감소. escape된 따옴표가 있으면 값이 잘릴 수 있으나, 차단 방향엔 안전
  # (부분이라도 git commit 매치 시 차단). 정확성은 jq 경로가 보장.
  agent_id=$(printf '%s' "$input" | sed -n 's/.*"agent_id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
  command=$(printf '%s' "$input" | sed -n 's/.*"command"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
fi

# 서브에이전트(agent_id 존재) → 허용 (finalizer commit, tester mvn 등 정상)
[ -n "$agent_id" ] && exit 0

# 메인 orchestrator: commit/push/build/test/배포 명령 차단
# 경계: 명령 시작 또는 ;|&/공백 뒤에 오는 토큰만 매치 (git status 등 오탐 방지)
# 인용부 안 텍스트(codex/echo 프롬프트 본문 등)는 실행 토큰이 아님 → 매치 전 제거.
#   따옴표로 감싼 "mvn package"는 셸이 실행명령으로 안 봄(파일명 취급) → 제거해도 실 빌드 누락 위험 0.
#   (예: codex exec "...mvn package..." -s read-only 의 프롬프트 내 mvn 오탐 차단 제거)
scan=$(printf '%s' "$command" | sed -E "s/'[^']*'//g; s/\"[^\"]*\"//g")
if printf '%s' "$scan" | grep -qiE '(^|[;&|[:space:]])(git[[:space:]]+(commit|push)|mvn|mvnw|\./mvnw|gradle|gradlew|\./gradlew)([[:space:]]|$|;|&)'; then
  echo "[hook] 오케스트레이터 직접 실행 금지 — git commit/push는 finalizer, mvn/gradle 빌드·테스트는 tester에 위임하라. (차단 command: ${command})" >&2
  exit 2
fi

exit 0
