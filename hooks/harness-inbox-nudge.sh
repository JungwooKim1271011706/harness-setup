#!/bin/bash
# UserPromptSubmit 훅 (글로벌 ~/.claude/settings.json에 등록해 사용).
# 하네스 회고 inbox pending을 매 프롬프트마다 감지해 알린다 — 모아서 일괄 적용용.
#
# 왜 글로벌 등록인가: dev clone(harness-setup 단독 repo)은 자체 .claude/ 서브디렉터리가
#   없어 repo settings.json/훅이 세션에 안 걸린다. 매 턴 발동시키려면 글로벌 훅이어야 한다.
# 왜 매 세션 안 시끄러운가: 글로벌 훅은 모든 프로젝트 세션서 돌지만, origin=harness-setup
#   (=dev clone, 적용 가능한 유일한 자리)일 때만 출력한다. 제품/worktree 세션은 침묵(적용 불가).
# inbox = 머신글로벌 ~/.claude/harness-retro-inbox. 설계: skills/harness-retro + skills/harness-check.
# 비차단(exit 0) — 프롬프트를 막지 않는다. 안내(additionalContext)만 주입한다.

ORIGIN=$(git -C "$PWD" remote get-url origin 2>/dev/null)
printf '%s' "$ORIGIN" | grep -q 'harness-setup' || exit 0   # dev clone 아니면 침묵

INBOX="${HOME}/.claude/harness-retro-inbox"
[ -d "$INBOX" ] || exit 0

N=$(find "$INBOX" -maxdepth 1 -name '*.md' -type f 2>/dev/null | wc -l | tr -d ' ')
[ "$N" -gt 0 ] || exit 0   # pending 0이면 침묵

LIST=$(find "$INBOX" -maxdepth 1 -name '*.md' -type f 2>/dev/null \
  | xargs -n1 basename 2>/dev/null | head -5 | tr '\n' ',' | sed 's/,$//')
MSG="🔧 하네스 회고 inbox 미처리 ${N}건 (${LIST}) — 모아서 /harness-retro 무인자 호출로 일괄 적용 가능"

ESCAPED=$(printf '%s' "$MSG" | sed 's/\\/\\\\/g; s/"/\\"/g')
printf '{"hookSpecificOutput":{"hookEventName":"UserPromptSubmit","additionalContext":"%s"}}' "$ESCAPED"
