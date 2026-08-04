#!/bin/bash
# UserPromptSubmit 훅 (글로벌 ~/.claude/settings.json에 등록해 사용).
# 하네스 회고 inbox pending을 매 프롬프트마다 감지해 알린다 — 모아서 일괄 적용용.
#
# 왜 글로벌 등록인가: dev clone(harness-setup 단독 repo)은 자체 .claude/ 서브디렉터리가
#   없어 repo settings.json/훅이 세션에 안 걸린다. 매 턴 발동시키려면 글로벌 훅이어야 한다.
# 왜 매 세션 안 시끄러운가: 글로벌 훅은 모든 프로젝트 세션서 돌지만, dev clone
#   (=적용 가능한 유일한 자리)일 때만 출력한다. 제품/worktree 세션은 침묵(적용 불가).
# 판별식 SSOT = wiki/_schema.md "어디로 가나".
#   ⚠ 이 훅의 basename 체크(L22)는 **L17 origin 필터와 한 쌍이다. 떼어서 인용하지 마라.**
#   L17을 통과하는 건 origin이 harness-setup일 때뿐 = cwd가 dev clone이거나 **중첩 .claude 안**일 때다.
#   그 조건에서만 basename이 .claude면 소비자가 된다. 소비자 세션의 cwd는 보통 **제품 repo 루트**라
#   origin이 제품 origin이고 L17에서 이미 침묵한다(실측 2026-08-04) — L22까지 오지도 않는다.
#   → basename만 떼어 "≠ .claude면 dev clone"으로 쓰면 **소비자를 dev clone으로 오판**한다.
#     문서 6곳이 그렇게 인용해 함께 틀려 있었다(v4.11.0에서 구조 판별로 정정).
#   ⚠ origin 단독 판별도 오판 — 소비자의 중첩 .claude도 자체가 harness-setup 클론이라 origin이
#     같다(2026-07-15 실사고: 소비자서 하네스 직접 커밋 → 폐기). 그래서 둘을 **함께** 본다.
#   문서·에이전트가 쓸 판별식은 3단계다(_schema.md SSOT, 순서 필수):
#     ① basename .claude → 소비자  ② $ROOT/.claude/.git 존재 → 소비자
#     ③ $ROOT/agents/orchestrator.md + VERSION → dev clone
#   이 훅은 origin 필터가 ②를 대신하므로 ①만으로 충분하다. 문서는 ②가 있어야 한다.
# inbox = 머신글로벌 ~/.claude/harness-retro-inbox. 설계: skills/harness-retro + skills/harness-check.
# 비차단(exit 0) — 프롬프트를 막지 않는다. 안내(additionalContext)만 주입한다.

ORIGIN=$(git -C "$PWD" remote get-url origin 2>/dev/null)
printf '%s' "$ORIGIN" | grep -q 'harness-setup' || exit 0   # 하네스 repo 아니면 침묵(남의 프로젝트)

# 중첩 .claude(=소비자 세션 vendoring)면 침묵 — 적용 자리 아님. origin은 여기서도 harness-setup이라
# origin만으론 못 거른다(위 주석 참조). toplevel basename이 판별키.
TOPLEVEL=$(git -C "$PWD" rev-parse --show-toplevel 2>/dev/null)
[ "$(basename "$TOPLEVEL")" = ".claude" ] && exit 0

INBOX="${HOME}/.claude/harness-retro-inbox"
[ -d "$INBOX" ] || exit 0

N=$(find "$INBOX" -maxdepth 1 -name '*.md' -type f 2>/dev/null | wc -l | tr -d ' ')
[ "$N" -gt 0 ] || exit 0   # pending 0이면 침묵

LIST=$(find "$INBOX" -maxdepth 1 -name '*.md' -type f 2>/dev/null \
  | xargs -n1 basename 2>/dev/null | head -5 | tr '\n' ',' | sed 's/,$//')
MSG="🔧 하네스 회고 inbox 미처리 ${N}건 (${LIST}) — '하네스 inbox 처리해줘' 요청 시 일괄 적용(dev clone은 /harness-retro 슬래시 미등록 → skills/harness-retro/SKILL.md 절차 실행)"

ESCAPED=$(printf '%s' "$MSG" | sed 's/\\/\\\\/g; s/"/\\"/g')
printf '{"hookSpecificOutput":{"hookEventName":"UserPromptSubmit","additionalContext":"%s"}}' "$ESCAPED"
