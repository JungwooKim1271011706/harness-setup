---
title: 모델 오버라이드는 미가용 시 에러가 아니라 조용히 강등된다 — 가용성은 transcript로만 확인
type: gotcha
links: [[agent-memory-overrides-rule]]
sources:
  - sources/20260726T060029Z__DEVUNIT-authpatch_draft.md
  - ../CHANGELOG.md — v3.82.0 "fable 무음 강등"
updated: 2026-07-26
---

**증상:** 설계패널 재게이트 후 최고위험 슬롯(eng·cso)이 전부 sonnet으로 돌았다. 에러 0건, 경고 0건, `perPersona[].model`은 `fable`로 정상 보고. 발각 경로는 **사용자 육안 지적**("workflow 모델이 왜 다 소넷이지?") — 하네스는 내내 정상이라고 보고하고 있었다.

**원인:** `Agent(model:'fable')`이 미가용 계정에서 **실패하지 않는다.** 에러도 null도 아니고, 정상 산출 + 실제 모델 `claude-sonnet-5`로 **조용히 강등**된다.

독립 재현(2026-07-26, dev clone):

```
Agent(model:'fable') → transcript "model":"claude-sonnet-5"   ← 정상 반환
Agent(model:'opus')  → transcript "model":"claude-opus-5"     ← 정상
```

계정 전환(`/login`)으로 **세션 도중** 가용성이 바뀐 것이 방아쇠였다. 같은 세션 R1은 fable 4슬롯으로 정상 실행됐다.

**왜 안전망이 전부 죽었나:** 하네스의 fable 폴백 규칙 3곳이 모두 *"fable 요청이 실패한다"*는 전제 위에 있었다. 실패가 안 일어나므로 전부 무발동:

| 위치 | 죽은 이유 |
|---|---|
| `workflows/design-panel.js` | `if (res === null) fableDown = true` → 영영 false |
| `agents/tester/tester-quality.md` | `model: fable` 핀 + "스폰 실패 시 opus 재스폰" → 스폰이 실패하지 않음 |
| `agents/orchestrator.md` | `perPersona[].model` 자기보고가 `fable`로 **거짓 보고** |

결과: 최고위험 게이트가 폴백 기준(opus)보다 **아래인 sonnet**으로 무음 저하.

**회피 — 요청 결과가 아니라 transcript를 봐라:**

```
~/.claude/projects/<proj>/<session>/subagents/
  agent-<id>.meta.json   → {"model":"fable"}          ← 요청값
  agent-<id>.jsonl       → {"model":"claude-sonnet-5"} ← 실제값   ★ 이게 진실
  workflows/wf_<id>/agent-<id>.jsonl                   ← 워크플로 슬롯(실제값만)
```

워크플로 슬롯의 meta는 `{"agentType":"workflow-subagent","spawnDepth":1}`뿐이라 요청값이 없다 → **`claude-fable-*` 건수 0이면 강등**으로 판정한다.

절차·차단 규칙은 `../agents/orchestrator.md` **§모델 실측 (게이트 산출 수령 직후, 필수)** 가 SSOT.

**사전 probe는 오답이다:**
- 사고 원인이 세션 **도중** 가용성 변화라서, 세션 시작 probe는 "OK"를 반환하고 그대로 통과시킨다 — 같은 사고 재발.
- probe 1회 = **~33k 서브에이전트 토큰**(1단어 응답 실측). 사후 transcript 대조는 파일 읽기라 토큰 0.
- probe는 대리 실행이라 **실제 게이트 슬롯**이 뭘로 돌았는지 검증하지 않는다.

**교훈(일반화):** [[agent-memory-overrides-rule]]과 같은 클래스다 — "모델에게 X를 믿지 마라"는 소프트룰 대신 **판단 자리를 자기보고에서 실측으로 옮긴다.** 자기보고 필드(`perPersona[].model`, frontmatter 핀)는 의도의 기록이지 실행의 증거가 아니다.

**적용 범위:** fable 한정이 아니다. 모든 `model:` 오버라이드(Agent 도구, 서브에이전트 frontmatter, 워크플로 `opts.model`)가 같은 성질일 것으로 본다 — 미가용 티어는 조용히 하위 티어로 내려간다. 게이트 신뢰도가 모델 티어에 걸려 있는 자리라면 전부 실측 대상이다.
