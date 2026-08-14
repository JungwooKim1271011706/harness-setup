---
source_session: 단일 커밋 범위(start==end) TDD 풀사이클 — 시간비용 구조 후속 (커밋 0a6e1d88 / 2177a7a0)
project: DEVUNIT-authpatch_draft (worktree feature-monitor-test-1)
date: 2026-08-04
detected_by: /harness-check (사용자 질의 "오래 걸린 원인이 담겼나" 후속 분석)
signals: 시간비용 구조 2건 — 순차실행 비용 미계산 · 실DB 통합 반복실행
relates_to: applied/20260804T130851Z__DEVUNIT-authpatch_draft.md (같은 세션 품질결함 6건, 별건)
---

# 하네스 자가 회고 (후속) — 총소요 ~4시간의 주 원인은 품질결함이 아니었다

같은 세션의 선행 드롭(품질결함 6건, `applied/20260804T130851Z…`)은 **"왜 라운드가 늘었나"** 를 담았다. 그러나 subagent duration을 합산(~14,000s)해보니 총소요의 큰 덩어리는 **"한 라운드가 왜 그렇게 비싼가"** 쪽이었고, 그 축이 선행 드롭에 없다. 이 파일이 그 보완이다.

---

## 후보 7 — "병렬 발사"가 실제로는 순차인데 비용 계산에 반영되지 않는다 (우선순위: 높음)

**증상**: 이 환경은 tmux 부재로 `Agent(run_in_background:true)`가 즉시 실패하고, `orchestrator.md` `## 병렬 위임 폴백` 규칙대로 **Agent는 foreground 고정**이다. 그런데 orchestrator는 매 검증 라운드를 "BE ∥ FE 병렬"로 선언하고 한 메시지에 Agent 2개를 쏜다 — 실제로는 **순차 실행**되어 라운드 소요가 두 배다. 이번 실행에 검증 라운드가 6회 이상(7.6 1차·수정·재검증·재확인 / 7.7 1차·재검증) 있었고 각각 BE+FE 2배치라, 순차 누적이 총소요의 최대 덩어리였다.

**추정 원인**: 폴백 규칙이 "Agent는 foreground 고정 / 병렬이 필요하면 Bash background(codex) ∥ Agent foreground 조합"이라 **이미 명시돼 있는데**, orchestrator가 이를 *발사 방식*으로만 이해하고 **배치 설계·비용 추정에는 반영하지 않는다**. 그래서 "병렬이니 싸다"는 전제로 배치를 2개로 쪼개는데 실제 비용은 합산이다.

**제안 개선**: `orchestrator.md` `## 병렬 위임 폴백`에 1~2줄 —
> 이 환경에서 Agent 2개를 한 메시지에 보내도 **순차 실행**이다. 배치를 쪼갤 때 "병렬이라 싸다"를 전제하지 마라 — **두 배치의 소요는 합산**이다. 라운드 수를 줄이는 쪽(한 배치로 묶기·검증 스코프 축소)이 배치를 쪼개는 쪽보다 총소요에 유리할 수 있다. 진짜 병렬은 **Bash background(codex 등) ∥ Agent foreground** 조합에서만 나온다.

**근거(실측)**: 이번 실행 subagent duration 합산 ~14,000s. codex(Bash background)는 실제로 tester Agent와 겹쳐 돌아 시간을 벌었으나, BE/FE Agent 2배치는 전부 순차였다. 예: 7.5 작성 BE 1069s + FE 980s = 2049s(겹침 0).

**관련 파일**: `.claude/agents/orchestrator.md`

---

## 후보 8 — 검증 라운드마다 실DB 통합테스트 전량 재실행 (우선순위: 높음)

**증상**: 백엔드 검증 스코프에 `@SpringBootTest` + 실 MySQL 클래스가 포함돼 매 라운드 8~18분이 든다. 실측: GREEN 자가검증 **1057s**, 변경검증 회귀확인 **870s**, developer 보고 `"10:47 min (2개 @SpringBootTest 기동 포함)"`. 7.6/7.7 다회전에서 **같은 통합테스트를 6회 이상 반복 실행**했고, 그 라운드 대부분은 순수 단위 케이스(Mockito) 결함만 고친 것이라 통합 재실행이 불필요했다.

**추정 원인**: 회귀 스코프를 "계획서 명시 클래스 목록"으로 위임하는 규칙(`orchestrator.md`)은 **무음 부분실행을 막는 데는 옳지만**, 라운드 성격(단위 결함 수정 vs 계약·스키마 변경)에 따라 실DB 통합을 미룰 수 있다는 구분이 없다. 그래서 매 라운드 전량이다.

**제안 개선**: `orchestrator.md` 변경검증 절(또는 `playbook-tdd.md` 7.6)에 1줄 —
> 7.6/7.7 **재검증 라운드**에서 수정 범위가 순수 단위 케이스(mock 기반)에 한정되면 실DB `@SpringBootTest` 클래스는 **최종 1회로 미루고** 그 라운드는 단위만 돌린다. 단 **계약·스키마·배선을 건드린 라운드는 전량 필수**이며, 생략한 클래스는 반환에 명시해 무음 축소가 되지 않게 한다.
> ⚠ 스코프 명시 위임 규칙은 유지 — 축소는 orchestrator가 **명시 지시**할 때만이고 tester 재량이 아니다(무음 부분실행 방어와 충돌하지 않게).

**근거(실측)**: M1 단건 수정(`verify` 1줄 추가) 검증에 7클래스 전량 + 실DB 2기동으로 268s~716s 소요. 그 라운드에 실DB가 검증한 내용은 직전 라운드와 동일했다.

**관련 파일**: `.claude/agents/orchestrator.md`, `.claude/docs/playbook-tdd.md`

---

## 선행 드롭과의 관계

`applied/20260804T130851Z__DEVUNIT-authpatch_draft.md`(품질결함 6건: 부정단언 지시 / tester 탐색폭주 / 제목grep 오판 / codex review 누락 / 상수 잔존 / 세션판별식 오류)와 **직교**한다. 6건은 라운드 *횟수*를, 이 2건은 라운드 *단가*를 다룬다. 둘 다 적용해야 총소요가 줄어든다.

⚠ **확인 필요**: 선행 드롭이 `applied/`로 이동됐으나 `wiki/sources/`에 사본이 없고 `.claude` repo 커밋(v4.4.0 = 구조 감사 3건)에 6건 내용이 보이지 않는다. **이동만 되고 규칙화가 안 됐을 가능성** — dev clone에서 `orchestrator.md`/`playbook-tdd.md`/`wiki/index.md`에 6건 반영 여부를 확인할 것.
