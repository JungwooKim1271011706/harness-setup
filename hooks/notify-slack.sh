#!/bin/bash
# Stop 훅 — CC 응답 완료 시 Slack 알림(폰+PC) + 채널=히스토리 + 응답 요약 3줄.
# 웹훅 URL은 .claude/.secrets/slack-webhook(gitignore됨)에서 읽음. URL 절대 echo/log 안 함.
# 알림 훅이라 절대 차단 금지 — 어떤 경로로도 exit 0(응답 흐름 방해 X).
#
# 한글 인코딩 핵심: bash→Windows curl.exe 인자 경계에서 UTF-8이 cp949로 변환되며 깨짐.
# 우회 = payload를 jq로 임시파일에 UTF-8 기록 후 `curl -d @파일`로 전달(인자 경계 안 거침).
# 라벨·요약 모두 이 파일 경유라 한글 보존됨. ASCII(branch/시간)는 어느 경로든 안전.

input=$(cat)

# 스크립트 위치 기준 비밀 파일(견고)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SECRET_FILE="$SCRIPT_DIR/../.secrets/slack-webhook"
[ -f "$SECRET_FILE" ] || exit 0
URL="$(tr -d '[:space:]' < "$SECRET_FILE")"
[ -n "$URL" ] || exit 0

# Stop 페이로드에서 cwd·transcript_path 추출
if command -v jq >/dev/null 2>&1; then
  cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)
  tpath=$(printf '%s' "$input" | jq -r '.transcript_path // empty' 2>/dev/null)
else
  cwd=$(printf '%s' "$input" | sed -n 's/.*"cwd"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
  tpath=$(printf '%s' "$input" | sed -n 's/.*"transcript_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
fi
[ -n "$cwd" ] || cwd="$PWD"

branch="$(git -C "$cwd" rev-parse --abbrev-ref HEAD 2>/dev/null || echo '?')"
ts="$(date '+%H:%M:%S' 2>/dev/null || echo '')"

# 응답 요약: transcript에서 마지막 assistant 텍스트 → 3줄 → 300자 컷
summary=""
if [ -n "$tpath" ] && [ -f "$tpath" ] && command -v jq >/dev/null 2>&1; then
  summary="$(jq -rs '[.[] | select(.type=="assistant") | .message.content[]? | select(.type=="text") | .text] | last // ""' "$tpath" 2>/dev/null | head -3 | head -c 300)"
fi

# 메시지 조립
text="[CC] 응답 완료 [${branch}] ${ts}"
[ -n "$summary" ] && text="${text}"$'\n'"${summary}"

# payload를 임시파일에 UTF-8 기록(인자 경계 우회 → 한글 보존)
tmp="$(mktemp 2>/dev/null || echo "${TMPDIR:-/tmp}/notify-slack.$$.json")"
if command -v jq >/dev/null 2>&1; then
  jq -nc --arg t "$text" '{text:$t}' > "$tmp" 2>/dev/null
else
  # jq 부재 폴백: ASCII만(한글·요약 생략). 절대 실패 안 하게 최소 전송
  printf '{"text":"[CC] response done [%s] %s"}' "$branch" "$ts" > "$tmp"
fi

curl -s -m 10 -X POST -H 'Content-Type: application/json' -d @"$tmp" "$URL" >/dev/null 2>&1 || true
rm -f "$tmp" 2>/dev/null || true
exit 0
