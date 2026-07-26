---
source_session: DEVUNIT-authpatch_draft / feature-dashboard-commitlog-2 (커밋상세 서브모듈 diff 설계패널 재게이트)
project: DEVUNIT-authpatch_draft
date: 2026-07-26
signal: 출력·런타임 실패 (모델 슬롯 무음 강등 → 게이트 기준 저하)
priority: high
---

# 회고 후보: `fable` 슬롯이 미가용 계정에서 **에러 없이 sonnet으로 조용히 강등**되어 최고위험 게이트 폴백 규칙이 전면 무력화

## 증상 (무엇이 얼마나)
설계패널 재게이트(R2) 실행 후 사용자가 "workflow 모델이 왜 다 소넷이지?"라고 지적. 실측:

| 라운드 | 실제 스폰 모델 | 비고 |
|--------|---------------|------|
| R1 (계정 전환 전) | `claude-fable-5` 4 + `claude-sonnet-5` 2 | 정상(eng 다라운드 3+cso=fable, design/devex=sonnet) |
| R2 (`/login` 계정 전환 후) | **`claude-sonnet-5` 6** | eng·cso가 sonnet으로 실행 — 기준 미달 |

세션 도중 `organization has disabled Claude subscription access` 에러 → 사용자가 `/login`으로 계정 전환. 새 계정은 fable 미가용.

**결정적 probe**(code-reviewer 서브에이전트, 도구 미사용 1줄 응답):
- `Agent(model:'fable')` → 실제 스폰 `"model":"claude-sonnet-5"` — **에러·null 아님, 조용히 강등**
- `Agent(model:'opus')` → 실제 스폰 `"model":"claude-opus-5"` — 정상

즉 fable 요청은 **실패하지 않는다**. 그래서 "실패를 감지해 opus로 폴백"하는 기존 안전망이 전부 발동하지 않는다. 게이트 기준이 **소리 없이** opus(규칙상 폴백 기준)보다 아래인 sonnet까지 내려간다 — 무음 저하라 사람이 /workflows 화면을 눈으로 보지 않았으면 그대로 통과됐을 것(실제로 사용자 지적으로 발각).

## 추정 원인
하네스의 fable 폴백 규칙 3곳이 전부 **"fable 요청이 실패(null/스폰 실패)한다"**는 전제 위에 서 있는데, 실제 런타임은 미가용 모델을 **성공 강등**시킨다. 전제 오류.

1. `.claude/workflows/design-panel.js:110-114` — `res = await agent(..., opts('fable'))` 후 `if (res === null) fableDown = true` → null이 아니라 sonnet 산출이 돌아오므로 `fableDown`이 영영 false. **실증됨**.
2. `.claude/agents/tester/tester-quality.md:4` — `model: fable` frontmatter 핀. orchestrator.md:734 "스폰 실패가 fable 미가용 신호면 `model:'opus'` 오버라이드로 1회 재스폰" → 스폰이 실패하지 않으므로 동일하게 무력화(미실증, 동일 메커니즘 강추론). **7.7 품질게이트가 무음으로 sonnet 판정이 됨.**
3. `.claude/agents/orchestrator.md:406, 455` — "fable 미가용·사망 시 워크플로가 opus로 자동 폴백하고 `perPersona[].model`에 `opus(fable 폴백)`로 표출" / "fable 미가용 시 opus 폴백(종전 기준으로 후퇴, 게이트 구조 불변)" → 규칙 문구 자체가 감지 가능성을 전제. 실제로는 표출도 안 되고(`perPersona[].model`이 'fable'로 보고됨) 후퇴 기준도 안 지켜짐.

## 제안 개선 방향 (라우팅은 harness-retro가 결정)
- **1순위(design-panel.js + orchestrator.md)**: 폴백 트리거를 "호출 실패 감지"에서 **"orchestrator의 사전 가용성 probe + 명시 주입"**으로 전환. 세션 1회 fable probe(경량 서브에이전트 1줄 응답 후 transcript의 `"model":"claude-*"` 실측 — 자기보고 금지, codex 가용성 SSOT 패턴과 동형) → 미가용이면 패널 args에 `topModel:'opus'`를 명시 주입하고, 스크립트는 `const topModel = _a.topModel ?? 'fable'`로 받아 fable 시도 자체를 건너뛴다. tester-quality도 orchestrator가 Agent `model:'opus'` 오버라이드로 스폰.
- **2순위(사후 검증 백스톱)**: 게이트 산출 수령 시 실제 스폰 모델을 transcript(`subagents/**/agent-*.jsonl`의 `"model"`)로 1회 대조해, 최고위험 슬롯이 sonnet이면 **승인화면 통과 전에 차단**하고 재실행. 자기보고(`perPersona[].model`)를 신뢰하지 않는다 — 이번 사건에서 그 필드는 'fable'로 거짓 보고했다.
- **3순위(문서)**: orchestrator.md:406/455/734의 "미가용·사망 시 자동 폴백" 서술을 "미가용은 실패가 아니라 **무음 강등**으로 나타난다 — 사전 probe로만 탐지 가능"으로 정정. 계정 전환(`/login`) 후 모델 가용성이 바뀔 수 있다는 점 명시.
- **wiki 후보**: "claude 모델 오버라이드는 미가용 시 에러가 아니라 조용히 강등된다 — 가용성은 요청 결과가 아니라 transcript 실측으로 확인" gotcha 페이지(디버깅·게이트 신뢰도 작업 전 Grep 대상).

## 근거 (이번 실행 인용)
- probe 실측: `subagents/agent-ad485d480ec4005b8.jsonl` → `"model":"claude-sonnet-5"`(fable 요청분), `agent-a03f132ba3592cf46.jsonl` → `"model":"claude-opus-5"`(opus 요청분).
- 라운드 비교: `subagents/workflows/wf_6a9f22cf-60a/agent-*.jsonl`(R1, fable 4) vs `wf_1eb6316a-89e/agent-*.jsonl`(R2, sonnet 6).
- 규칙 원문: `.claude/agents/orchestrator.md:406,455,734`, `.claude/workflows/design-panel.js:95-121`, `.claude/agents/tester/tester-quality.md:4`.
- 발각 경로: 자동 감지 실패 — **사용자 육안 지적**으로만 발견됨(하네스는 정상으로 보고 중이었다).

## 관련 파일
- `.claude/workflows/design-panel.js` (95-121)
- `.claude/agents/orchestrator.md` (406, 455, 734)
- `.claude/agents/tester/tester-quality.md` (frontmatter model 핀)
- `.claude/docs/playbook-tdd.md` (7.7 모델 서술)
- `wiki/index.md` (신설 gotcha 등록처)
