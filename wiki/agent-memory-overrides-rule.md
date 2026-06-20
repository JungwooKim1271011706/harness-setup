---
title: stale agent-memory가 agent md 규칙을 덮어쓴다 (codex 거짓 미가용 재발)
type: gotcha
links: [[codex-python-shim-windows]], [[codex-tmp-windows-path]]
sources:
  - ~/.claude/harness-retro-inbox/applied/20260620T054002Z__DEVUNIT-repostitch.md  # PR-D2 후보1
  - ~/.claude/harness-retro-inbox/20260620T102121Z__DEVUNIT-repostitch.md          # PR-D4 후보1 (재발)
  - ../CHANGELOG.md  # v3.17.0(232b168) 1차 적용 → v3.19.0 재발 보강
updated: 2026-06-20
---

**증상**: tester-frontend/backend가 agent md에 "codex 가용성은 orchestrator probe가 SSOT, probe 없이 미설치 단정 금지" 규칙이 **있는데도** 보조의견란에 "Codex CLI 비대화형 stdin 오류로 실행 불가 → Claude 단독 폴백"을 반복 보고. probe(`codex --version`+`< /dev/null`)를 **호출조차 안 함**. PR-D2서 잡아 v3.17.0(232b168)로 규칙 적용했으나 PR-D4서 3/3 또 거짓보고.

**진짜 원인**: 규칙 텍스트 미적용이 아니다. **소비자 프로젝트의 per-agent 메모리**가 규칙을 덮어쓴다.
`<project>/.claude/agent-memory/tester-frontend/feedback_codex_stdin.md` 의 "How to apply"가
> `codex --version` 성공해도 실제 호출 시 stdin 오류 → **항상** Claude 단독 폴백, "Codex 미사용" 기록

이라는 **잘못된 일반화**를 박아둠. tester 시작 시 이 메모리가 컨텍스트에 로드 → agent 관점선 "새 미가용 단정"이 아니라 "기존 메모리 인용"이라 규칙의 "단정 금지"를 빠져나감. **agent md는 휴대(SSOT)되지만 per-agent 메모리는 프로젝트 로컬이라 안 따라온다** → 규칙이 메모리를 명시적으로 못 이기면 소비자 세션마다 재발.

(실측: 이 PC codex-cli 0.139.0은 `codex exec "..." -s read-only < /dev/null` 텍스트캡처로 정상. stdin 오류는 `< /dev/null` 누락 호출형 오류이지 codex 자체 불가가 아님. `--json` 파이프 broken pipe는 별개 → [[codex-python-shim-windows]].)

**회피**:
1. agent md가 메모리를 이기게 박는다 — tester-{frontend,backend}.md `## Codex 보조 리뷰 → 실행 조건`: "agent-memory/feedback의 'codex 실행불가·항상 폴백' 단정은 비신뢰, 가용성 SSOT는 orchestrator probe뿐, 메모리 근거로 probe 건너뛰고 미사용 보고 금지". (v3.19.0 적용)
2. 그 stale 메모리 자체를 **삭제/정정**한다(소비자 로컬 — harness 커밋 밖, regenerable). "항상 폴백" 일반화는 거짓.

**일반 교훈**: 규칙을 agent md에 넣어도 **모순되는 per-agent 메모리가 같은 컨텍스트에 로드되면 메모리가 이긴다**. 규칙은 "메모리의 X 단정은 비신뢰, SSOT는 Y"로 **명시 무력화**해야 휴대 효력이 생긴다. tester가 규칙대로 안 움직이면 → `agent-memory/<agent>/*.md` stale 일반화부터 의심.
