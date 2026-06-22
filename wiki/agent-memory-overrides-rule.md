---
title: stale agent-memory가 agent md 규칙을 덮어쓴다 (codex 거짓 미가용 재발)
type: gotcha
links: [[codex-python-shim-windows]], [[codex-tmp-windows-path]]
sources:
  - ~/.claude/harness-retro-inbox/applied/20260620T054002Z__DEVUNIT-repostitch.md  # PR-D2 후보1
  - ~/.claude/harness-retro-inbox/20260620T102121Z__DEVUNIT-repostitch.md          # PR-D4 후보1 (재발)
  - ~/.claude/harness-retro-inbox/applied/20260622T063542Z__DEVUNIT-repostitch.md  # PR-S1 관찰 (또 재발 → surface 제거)
  - ../CHANGELOG.md  # v3.17.0(232b168) 1차 → v3.19.0 소프트룰 보강 → v3.28.0 surface 제거
updated: 2026-06-22
---

**증상**: tester-frontend/backend가 agent md에 "codex 가용성은 orchestrator probe가 SSOT, probe 없이 미설치 단정 금지" 규칙이 **있는데도** 보조의견란에 "Codex CLI 비대화형 stdin 오류로 실행 불가 → Claude 단독 폴백"을 반복 보고. probe(`codex --version`+`< /dev/null`)를 **호출조차 안 함**. PR-D2서 잡아 v3.17.0(232b168)로 규칙 적용했으나 PR-D4서 3/3 또 거짓보고.

**진짜 원인**: 규칙 텍스트 미적용이 아니다. **소비자 프로젝트의 per-agent 메모리**가 규칙을 덮어쓴다.
`<project>/.claude/agent-memory/tester-frontend/feedback_codex_stdin.md` 의 "How to apply"가
> `codex --version` 성공해도 실제 호출 시 stdin 오류 → **항상** Claude 단독 폴백, "Codex 미사용" 기록

이라는 **잘못된 일반화**를 박아둠. tester 시작 시 이 메모리가 컨텍스트에 로드 → agent 관점선 "새 미가용 단정"이 아니라 "기존 메모리 인용"이라 규칙의 "단정 금지"를 빠져나감. **agent md는 휴대(SSOT)되지만 per-agent 메모리는 프로젝트 로컬이라 안 따라온다** → 규칙이 메모리를 명시적으로 못 이기면 소비자 세션마다 재발.

(실측: 이 PC codex-cli 0.139.0은 `codex exec "..." -s read-only < /dev/null` 텍스트캡처로 정상. stdin 오류는 `< /dev/null` 누락 호출형 오류이지 codex 자체 불가가 아님. `--json` 파이프 broken pipe는 별개 → [[codex-python-shim-windows]].)

**회피 (3차 — surface 제거, 결정판)**:
소프트 규칙은 **또 졌다**. v3.19.0이 "메모리 비신뢰, SSOT=probe"를 명시했으나 PR-S1(2026-06-22)서 tester가 또 거짓 폴백 보고. in-context 오염 메모리는 "비신뢰하라"는 같은-컨텍스트 규칙도 이긴다. → **판단 surface 자체를 제거**한다(v3.28.0):
1. **tester의 가용성 판단 권한 0.** orchestrator 주입값이 유일 입력. tester는 판단·추론·self-probe 안 함. `tester-{frontend,backend}.md ## Codex 보조 리뷰 → 실행 조건` 재작성.
2. **self-probe(`codex --version`) 탈출구 제거.** 그게 오염 메모리가 기어드는 문(주입 없으면 self-probe→메모리→거짓 폴백). 주입 없으면 `NEEDS_CONTEXT`로 반환(self-probe·메모리 참조 금지).
3. **tester는 "폴백/미가용" 출력 금지.** 호출 raw 결과·정확한 실패 신호만 보고, 폴백 판정은 orchestrator. 출력형식의 "상태: 폴백(Claude 단독)" 제거(그게 tester에게 판정을 시키던 잔재).
4. orchestrator는 **모든 tester·review 호출에 가용성 주입 의무**(`orchestrator.md ### 가용성 확정`).
5. (병행) stale 메모리 삭제는 여전히 유효하나 **근본책임 아님** — surface가 없으면 메모리가 끼어들 자리가 없다.

**일반 교훈 (격상)**: 규칙을 agent md에 넣어도 **모순 per-agent 메모리가 같은 컨텍스트에 로드되면 메모리가 이긴다**. "메모리 비신뢰" 소프트 명시도 in-context 메모리에 **반복 패배**한다(1차 규칙 부재 → 2차 소프트룰 → 둘 다 재발). 결정적 해법 = **그 판단을 모델 권한에서 빼서 deterministic 입력(orchestrator 주입)으로 강제**한다. "모델에게 X 믿지마"가 아니라 "모델이 X를 판단할 자리를 없앤다". 모델이 규칙대로 안 움직이는 재발 클래스는 소프트룰 추가 말고 **판단 surface 제거**를 먼저 고려.
