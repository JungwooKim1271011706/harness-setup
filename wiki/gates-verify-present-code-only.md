---
title: 기계 게이트는 있는 코드만 검증한다 — 승인 항목 미구현은 전 게이트를 무사통과
type: gotcha
links: [[claude-model-override-silent-downgrade]], [[agent-memory-overrides-rule]]
sources:
  - sources/20260727T070040Z__DEVUNIT-authpatch_draft.md
  - ../CHANGELOG.md — v3.84.0 "위임 커버리지 대조"
updated: 2026-07-27
---

**증상:** 계획서가 승인한 FROZEN 예외 1건(`RestTemplate` 소켓 타임아웃 프로퍼티화)이 **구현되지 않은 채로** 아래를 전부 통과했다.

```
7.7 tester-quality      PASS (critical 0)
변경검증 backend        PASS 77/77
변경검증 frontend       PASS + 실브라우저 실측
/review (code-reviewer) blocking 0
/codex review           major 2 (해당 항목 무관)
/cso                    findings 0
```

finalizer 직전 워크스루에서야 발각. 한 발 늦었으면 미구현으로 커밋됐다.

**원인 — 게이트 설계의 구조적 사각:**

| 게이트 | 보는 것 | 못 보는 것 |
|---|---|---|
| 7.7 | 작성된 RED의 품질 | 그 RED가 커버해야 할 승인항목 누락 |
| 변경검증 | 실행된 테스트의 통과 | 구현이 없어 아무도 안 부른 항목 |
| /review · /codex review | **diff** | diff에 없는 것 |
| /cso | 존재하는 공격표면 | 없는 안전망 |

전부 **있는 코드**를 검증한다. **있어야 하는데 없는 코드**는 어느 게이트의 시야에도 안 들어온다. 게이트를 아무리 늘려도 이 축은 안 메워진다 — 종류가 다르다.

**연쇄 피해:** codex review finding(`Thread.interrupted()` 지적)을 기각한 근거가 *"소켓 타임아웃만이 이 스택의 유일한 실질 상한"*이었는데 **그 상한이 미구현이었다**. 기각 판정 자체는 유효(인터럽트는 blocking IO에 무력)하나, **없는 안전망을 근거로 리뷰 지적을 기각**한 셈이다. 부재는 조용히 다른 판단의 전제로 흘러든다.

**회피 — 부재를 보는 그물은 따로 쳐야 한다(2겹):**

1. **8.0 위임 커버리지 대조**(`../docs/playbook-tdd.md`) — 배치 확정 직후·**발사 전**. 계획서 승인항목 ↔ 위임 배치 1:1 매핑표. 미매핑 1건이라도 있으면 발사 금지. 여기서 잡으면 **구현 전**이라 재작업 0.
2. **워크스루 3단계 양방향 대조**(`../agents/orchestrator.md`) — 최종 그물. 종전엔 *초과*(diff에 있는데 계획에 없음)만 봤다. **누락**(계획에 있는데 diff에 없음)을 명시적으로 추가해야 한다.

⚠ **승인 항목은 기억이 아니라 계획서를 다시 Read해서 열거한다.** 이번 사고의 뿌리가 orchestrator의 오기억이었다 — 승인 예외 2건을 다른 항목으로 잘못 기억해 배치 지시에서 1건이 빠졌다.

**비대칭이 원인이었다:** 7c.1은 "승인 major → 최소 1 RED"를 강제한다. 그런데 "**승인 수정대상 → 최소 1 위임 배치**"는 강제가 없었다. 같은 모양의 규칙이 한쪽에만 있었다.

**일반 교훈:** [[claude-model-override-silent-downgrade]]·[[agent-memory-overrides-rule]]과 같은 클래스 — **무음 실패**다. 셋 다 "에러가 안 나는데 틀린" 상태이고, 셋 다 사람 육안으로만 발각됐다. 게이트를 추가할 때 *"이 게이트가 못 보는 축은 무엇인가"*를 같이 적어두면 사각이 누적되지 않는다.
