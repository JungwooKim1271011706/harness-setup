---
source_session: 소비자 세션 (worktree feature-dashboard-commitlog-2 / 작업 repo C:\crinity\workspace\sideproject\authpatch_draft)
project: DEVUNIT-authpatch_draft
date: 2026-07-28
trigger: post_commit 자가점검 (커밋 89dbbbf7 — 커밋그래프 무한스크롤)
---

# 하네스 자가 회고 — 커밋 89dbbbf7 라운드

전체 흐름은 성공(설계패널 3R + codex 3R → TDD 합의 → GREEN → 리뷰 2소스 → 커밋).
단 **7.6 프론트 RED sanity에서 LOOP 3/3을 전량 소진**했고, 소진 원인이 구현 결함이 아니라
**spec 위생 결함 2종**이었다. 둘 다 특정 프레임워크(Vue Test Utils) 함정이고 재현성이 높아 규칙화 가치가 있다.

---

## 후보 1 — `attachTo: document.body` spec에 파일 전역 cleanup 안전망 강제 (R-급)

**증상 (무엇이 얼마나 비효율적이었나)**
7.6 프론트 RED sanity가 4라운드 돌았다(LOOP 3/3 소진). 매 라운드 tester-frontend 실행 ~5~9분 + tester-design 수정 라운드까지 합쳐 **약 40분 + 5회 위임**을 여기서 썼다.
그런데 실제 결함은 프로덕션이 아니라 spec이었다:
- 어떤 케이스가 `mountModal()`(`attachTo: document.body`)로 마운트한 뒤 **본문 앞부분 `expect()`에서 throw** 되면, 블록 끝의 `wrapper.unmount()`에 **도달하지 못한다**.
- 이 프로젝트 `vitest.config.ts`에는 `setupFiles`가 없어 **자동 정리가 없다** → 실패한 wrapper의 DOM이 `document.body`에 파일 끝까지 잔존.
- 뒤이어 실행되는 무관 케이스(`ETD-02`)가 `document.body.querySelectorAll(...)`로 **잔존 노드까지 함께 조회**해 오염 FAIL.

**RED 단계에서 특히 치명적인 이유**: RED는 **의도적으로 실패**하는 단계다. 즉 "실패 시 cleanup 미도달"이라는 조건이 **RED 단계에서 100% 성립**한다. 평소엔 잠복하다가 TDD 게이트에서만 터진다.

**추가 낭비 — 스코프 오판 1라운드**: 1차 수정이 오염원을 `ET-LM`(신규 케이스)으로 지목해 그 describe에만 로컬 안전망을 달았으나, 검증자가 3단계 `-t` 격리 실행으로 실제 오염원이 **`ET-01`**(다른 describe, afterEach 자체가 없던 곳)임을 밝혀 무효화됐다. → "오염원 = 방금 추가한 신규 케이스"라는 직관이 틀렸다.

**추정 원인**
- `tester-design.md`의 RED 규칙(R1~R18)에 **테스트 격리/정리(teardown) 축이 없다**. R14(mock.calls 스코프 한정)는 mock 축만 다루고, DOM/전역 상태 잔존은 커버 안 된다.
- `playbook-tdd.md` 7.6의 "모달/오버레이 spec 선점검 체크리스트"는 ① teleport stub ② onMounted API mock 2개뿐 — **cleanup 보장이 없다**.

**제안 개선 방향**
1. `tester-design.md`에 **R19 신설**: "전역 DOM에 붙는 마운트(`attachTo: document.body`)를 쓰는 spec은 **파일 전역 `afterEach`로 강제 정리**를 둔다(마운트 헬퍼가 wrapper를 배열에 추적 → afterEach에서 배수 + `document.body.innerHTML=''` 폴백). 개별 `it()` 말미의 수동 `unmount()`에 의존 금지 — **RED 단계에서는 그 라인에 도달하지 않는 것이 정상**이기 때문."
2. `playbook-tdd.md` 7.6 "모달/오버레이 spec 선점검 체크리스트"에 ③번 항목으로 추가: "`attachTo: document.body` 사용 시 파일 전역 cleanup 안전망 존재 확인 — 없으면 7.6 불통과."
3. (선택) 오염 진단 절차 명문화: "cross-test 오염 의심 시 `-t` 격리 실행으로 **오염원 케이스를 이분탐색**하라. 신규 케이스가 오염원이라고 가정하지 마라." — 이번에 스코프 오판 1라운드를 만든 지점.

**근거 (이번 실행 인용)**
- 7.6 프론트 1차: `ExportTriggerModal.spec.ts` PARSE_ERROR로 0 tests → 별건(후보 2)
- 7.6 프론트 2차: ETD-02 FAIL, 격리 시 PASS → cross-test DOM 잔존 확정
- 7.6 프론트 3차: ET-LM 로컬 안전망 적용했으나 ETD-02 여전히 FAIL. 검증자 3단계 격리(`-t "ETD-01|ETD-02"` PASS / `-t "ET-LM|ETD-01|ETD-02"` PASS / `-t "ET-01|ETD-01|ETD-02"` FAIL)로 **오염원 = ET-01** 확정
- 7.6 프론트 4차: 파일 전역 `activeWrappers` + 최상위 `afterEach`(배수 + `document.body.innerHTML=''`)로 통과

**관련 파일**
- `.claude/agents/tester/tester-design.md` (R19 신설)
- `.claude/docs/playbook-tdd.md` (7.6 모달/오버레이 체크리스트)

**bump 추정**: MINOR (규칙 신설, 기존 게이트 구조 불변)

---

## 후보 2 — VTU `teleport: true` 스텁의 stale `DOMWrapper` (R-급 또는 wiki)

**증상**
변경검증(GREEN 후)에서 프론트 456/457 중 **유일 FAIL이 `ET-LM-02`**였고, 원인 규명에 tester-frontend가 디버그 하네스(MutationObserver)까지 만들어 **1 라운드를 통째로 썼다**(codex 교차검증 포함). 결론은 **프로덕션 정상, 테스트 인프라 아티팩트**.

**메커니즘 (실측 확정)**
`@vue/test-utils`의 `teleport: true` 스텁은 리렌더마다 `<teleport-stub>` **서브트리를 remove+add로 교체**한다(패치 아님). VTU 소스 `vue-test-utils.cjs.js:7737~7742`가 `isTeleport`/`isKeepAlive`에 대해 vnode 변환 캐시를 **의도적으로 스킵**(GitHub #1829/#1888 주석). 따라서 클릭 **전에** `wrapper.find(...)`로 잡아둔 `DOMWrapper` 참조가 클릭 후 stale이 되어 `disabled` 반영을 못 본다. 리렌더 직후 fresh `wrapper.find()`로 조회하면 정확히 반영됨.

**같은 결함 클래스가 2건이었다**: `ET-LM-02`(stale 참조로 단언) + `ET-LM-05`(stale 노드에 **재클릭** — disabled 게이트를 우회해 케이스 목적 자체가 무력화될 뻔). 후자는 검증자가 아니라 sweep 지시로 발견됐다.

**추정 원인**
- 이 저장소는 `teleport: true` 스텁을 쓰는 spec이 다수인데, "리렌더 후 참조 재조회" 규칙이 어디에도 없다.
- R14(mock.calls 스코프 한정)의 DOM판이 없다.

**제안 개선 방향**
1. `tester-design.md` R14에 항목 추가 또는 R19에 병합: "**클릭·상태전이 이후의 DOM 단언은 fresh re-query**(`wrapper.find(...)`)로 한다. 전이 전에 캡처한 `DOMWrapper`를 재사용 금지 — VTU `teleport` 스텁은 리렌더마다 서브트리를 교체해 참조가 stale해진다. 특히 stale 노드에 **재클릭**하면 `disabled` 게이트를 우회해 케이스 목적이 무력화된다."
2. wiki 페이지 신설 후보: `vtu-teleport-stub-stale-domwrapper.md` (기존 `vue-immediate-watch-template-ref` 류와 동렬)

**근거**
- 변경검증 tester-frontend 보고: MutationObserver로 서브트리 remove+add 실측, VTU 소스 라인 인용, codex AGREE("실 Vue Teleport는 타입 정체성을 유지하며 정상 패치 — 프로덕션 포커스 손실 아님")
- 수정 후 457/457 PASS

**관련 파일**
- `.claude/agents/tester/tester-design.md`
- `wiki/` (신규 페이지 + `index.md` 등록)

**bump 추정**: MINOR (R 규칙 보강) / wiki는 PATCH

---

## 후보 3 — "fable 0건 = 강등" 판정식이 **정상 폴백과 무음 강등을 구분 못 한다** (low, 정밀화)

**증상**
`orchestrator.md ### 모델 실측`은 "최고위험 슬롯에 `claude-fable-*`가 **0건**이면 강등이다 → args에 `topModel:'opus'` 명시 주입해 **재실행**"으로 되어 있다.
이번 7.7 실측 결과는 `claude-opus-5`(fable 0건)였다. 규칙 문면대로면 **opus로 재실행**해야 하는데, 이미 opus로 돈 상태라 **재실행이 순수 낭비**다. orchestrator가 수동으로 "이건 정상 폴백"이라 판단해 넘어갔다.

**추정 원인**
규칙이 방어하려는 사고는 **무음 sonnet 강등**인데, 판정식이 `fable 0건`이라 **opus 폴백 성공 케이스까지 같이 걸린다**. 이 계정은 fable이 `Fable 5 requires usage credits`로 **명시 실패**하므로 폴백이 정상 작동하는데, 그걸 강등으로 오탐한다.

**제안 개선 방향**
판정식을 `fable 0건` → **`실제 모델이 sonnet인가`**로 바꾼다:
- `claude-opus-*` → **정상 폴백**. `⚠ fable 폴백(opus)` 태그만 붙이고 **재실행 안 함**.
- `claude-sonnet-*` → **무음 강등 확정** → `model:'opus'` 명시 주입 재실행(차단).
- fable 실행분 → 정상.

**주의**: 이건 규칙 완화가 아니라 **정밀화**다. 방어 대상(sonnet 무음 강등)은 그대로 차단되고, 오탐(opus 폴백)만 제거된다.

**근거**
- 이번 7.7 실측: `agent-a9f641cd2cd1c87ff.jsonl` → `"model":"claude-opus-5"`, fable 0건
- 직전 세션 체크포인트 기록: "fable 미가용은 `Fable 5 requires usage credits`로 명시 실패 → opus 폴백 정상 작동(무음 강등 아님)"

**관련 파일**
- `.claude/agents/orchestrator.md` (`### 모델 실측 (게이트 산출 수령 직후, 필수)`)
- `.claude/docs/playbook-tdd.md` (7.7 모델 주석)

**bump 추정**: PATCH (판정식 정밀화)

---

## 관찰만 (규칙화 제외 — 외부요인/1회성)

- **finalizer 위임 1회 중단 후 재발행**: 세션 인터럽트. 산출 손실 0(착수 전 중단), 상태 실측 후 그대로 재발행해 복구. 하네스 레버리지 없음.
- **`@SpringBootTest` 클래스당 ~5분(JLine dumb-terminal 폴백)**: 기존 알려진 환경 이슈(`env_jline_terminal_hang_springboottest.md`). tester가 `-DargLine=-Dorg.jline.terminal.provider=dumb`로 우회해 17클래스 35초까지 단축 — **이 우회 플래그가 tester-backend.md에 없다면 추가 가치 있음**(중간 가치, 후보로 승격할지는 dev clone 판단).
- **전체회귀 부채 N=102**(이번 커밋 포함). 이 프로젝트 고질(`last_full_regression.sha` 상시 null). 비차단.
