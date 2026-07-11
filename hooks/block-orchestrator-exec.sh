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
# 경계1 — 인용부호 '문자'만 제거(내용 보존): 셸과 동일하게 정규화해 따옴표 우회를 잡는다.
#   "git" commit / m"v"n package 는 셸에선 정상 실행 → 문자만 떼면 git commit / mvn 으로 복원돼 차단.
#   ⚠ 인용 '내용'을 통째 지우면 "git" commit → " commit" 으로 denylist 우회가 생김 → 내용은 안 지운다.
# 경계2 — '명령 위치'에서만 매치: 문자열 시작 또는 제어연산자(; & | 괄호) 직후만 실행 명령으로 본다.
#   일반 공백(인자 구분)은 명령 위치 아님 → codex exec ... mvn package ... 의 프롬프트 인자 내부 mvn은 오탐 안 함.
scan=$(printf '%s' "$command" | tr -d "\"'")
# 경계3 — heredoc 본문 제외: `cat > f <<'EOF' … EOF` 본문 줄이 줄머리 mvn/gradle이면
#   grep ^ 앵커가 데이터를 명령으로 오탐(체크포인트 heredoc·JSON payload 3회 실측). 본문 +
#   종료구분자 라인을 스캔에서 제거한다. heredoc '밖' 진짜 명령(; mvn / 줄머리 mvn)은 남아
#   차단 유지 → 오케스트레이터 직접실행 금지 불변식 보존, 데이터 오탐만 축소.
#   (따옴표는 위 tr서 이미 제거 → <<'EOF' == <<EOF, 구분자 매칭 단순화)
scan=$(printf '%s' "$scan" | awk '
  d=="" && match($0, /<<-?[ \t]*[A-Za-z_][A-Za-z0-9_]*/) {
    t=substr($0,RSTART,RLENGTH); sub(/^<<-?[ \t]*/,"",t); d=t; print; next
  }
  d!="" { l=$0; sub(/^[ \t]+/,"",l); if (l==d) d=""; next }
  { print }
')
if printf '%s' "$scan" | grep -qiE '(^|[;&|(])[[:space:]]*(git[[:space:]]+(commit|push)|mvn|mvnw|\./mvnw|gradle|gradlew|\./gradlew)([[:space:]]|$|[;&|])'; then
  echo "[hook] 오케스트레이터 직접 실행 금지 — git commit/push는 finalizer, mvn/gradle 빌드·테스트는 tester에 위임하라. (차단 command: ${command})" >&2
  exit 2
fi

exit 0
