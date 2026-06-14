#!/bin/bash
# Stop 훅 — CC 응답 완료 시 Slack 알림(폰+PC) + 채널=히스토리 + 응답 요약 3줄.
# 웹훅 URL은 .claude/.secrets/slack-webhook(gitignore됨)에서 읽음. URL 절대 echo/log 안 함.
# 알림 훅이라 절대 차단 금지 — 어떤 경로로도 exit 0(응답 흐름 방해 X).
#
# 한글 인코딩 핵심: bash→Windows curl.exe 인자 경계에서 UTF-8이 cp949로 변환되며 깨짐.
# 우회 = payload를 jq로 임시파일에 UTF-8 기록 후 `curl -d @파일`로 전달(인자 경계 안 거침).
# 라벨·요약 모두 이 파일 경유라 한글 보존됨. ASCII(branch/시간)는 어느 경로든 안전.

input=$(cat)

# jq가 PATH에 없으면(예: Windows에서 CC가 stale 환경 상속) 알려진 설치 위치를 PATH에 추가.
# jq 없으면 한글 요약이 ASCII 폴백으로 떨어지므로, PATH 의존 없이 직접 찾아 붙임.
if ! command -v jq >/dev/null 2>&1; then
  for d in "$HOME/AppData/Local/Microsoft/WinGet/Packages/jqlang.jq"*/ \
           "$HOME/AppData/Local/Microsoft/WinGet/Links/" \
           /mingw64/bin/ /usr/bin/; do
    if [ -x "${d}jq.exe" ] || [ -x "${d}jq" ]; then
      PATH="${d%/}:$PATH"
      break
    fi
  done
fi

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
proj="$(basename "$cwd" 2>/dev/null || echo '?')"
ts="$(date '+%H:%M:%S' 2>/dev/null || echo '')"

# 세션ID: transcript 파일명(uuid) 뒤 4자 → 같은 프로젝트 다중 세션 구분용
sid="$(basename "$tpath" .jsonl 2>/dev/null)"
sid="${sid: -4}"

# 색 바: cwd 해시 6자리 → 프로젝트별 고정 색(왼쪽 세로 색띠). md5sum 없으면 기본색.
color="#$(printf '%s' "$cwd" | md5sum 2>/dev/null | cut -c1-6)"
[ ${#color} -eq 7 ] || color="#4a90d9"

# 응답 요약: transcript에서 마지막 assistant 텍스트 → 3줄 → 300자 컷
summary=""
if [ -n "$tpath" ] && [ -f "$tpath" ] && command -v jq >/dev/null 2>&1; then
  summary="$(jq -rs '[.[] | select(.type=="assistant") | .message.content[]? | select(.type=="text") | .text] | last // ""' "$tpath" 2>/dev/null | head -3 | head -c 300)"
fi

# 메시지 조립
# top-level text = 플레인 헤더 → 토스트/푸시 미리보기 소스(이게 비면 "no preview")
top="[CC] ${proj} [${branch}]"
[ -n "$sid" ] && top="${top} ${sid}"
top="${top} · 응답 완료 ${ts}"
# attachment 본문 = 색바 안에 들어갈 내용(요약). 요약 없으면 헤더로 대체.
body="$summary"
[ -n "$body" ] || body="$top"

# payload를 임시파일에 UTF-8 기록(인자 경계 우회 → 한글 보존)
# top-level text = 미리보기 / attachment color = 왼쪽 세로 색띠(알림별 구분)
tmp="$(mktemp 2>/dev/null || echo "${TMPDIR:-/tmp}/notify-slack.$$.json")"
if command -v jq >/dev/null 2>&1; then
  jq -nc --arg top "$top" --arg b "$body" --arg c "$color" \
    '{text:$top, attachments:[{color:$c, fallback:$top, blocks:[{type:"section",text:{type:"mrkdwn",text:$b}}]}]}' > "$tmp" 2>/dev/null
else
  # jq 부재 폴백: ASCII만(한글·요약 생략). 절대 실패 안 하게 최소 전송
  printf '{"text":"[CC] %s [%s] %s response done %s","attachments":[{"color":"%s","text":"done"}]}' "$proj" "$branch" "$sid" "$ts" "$color" > "$tmp"
fi

curl -s -m 10 -X POST -H 'Content-Type: application/json' -d @"$tmp" "$URL" >/dev/null 2>&1 || true
rm -f "$tmp" 2>/dev/null || true
exit 0
