---
title: VTU가 <Teleport> 노드를 못 찾는다 — stub은 제자리 렌더라 오답, 네이티브 DOM으로 탐색
type: gotcha
links: [[vue-vmodel-select-jsdom-artifact]], [[jsdom-missing-browser-apis]]
sources:
  - sources/20260724T134253Z__DEVUNIT-authpatch_draft.md
  - sources/20260728T041316Z__DEVUNIT-authpatch_draft.md
  - ../CHANGELOG.md — v3.83.0 "VTU Teleport spec"
updated: 2026-07-31
---

**증상:** `<Teleport to="body">`를 쓰는 컴포넌트의 RED spec이 **3라운드**(attempt1→2→3) 재작업 끝에 GREEN. 매 라운드 실패 양상이 달라 원인이 안 보였다.

**원인 — 두 겹이다.**

**① `wrapper.find()`는 마운트 서브트리 안만 뒤진다.** Teleport는 컴포넌트 트리상 자식이지만 **실제 DOM 노드를 `document.body`로 옮긴다**(조상의 `overflow:hidden`·스택 컨텍스트 탈출이 목적). 서브트리 밖이라 `find()`/`findAll()`이 못 찾는다 → "요소 없음" 실패.

**② 흔한 회피책 `global.stubs.teleport: true`가 더 나쁜 오답이다.** 이건 텔레포트를 꺼서 **제자리 렌더**시킨다. 찾기는 찾지만:
- DOM 위치가 원래 자리라 **클리핑·리페어런팅 검증이 무의미**해진다 — 정작 Teleport를 쓴 이유를 검증 못 한다.
- 모달 재열림/remount 사이클에서 노드가 남거나 겹쳐 **단언이 흔들린다**(라운드마다 다른 실패의 정체).

**회피 — stub 버리고 네이티브 DOM:**

```js
// ❌ wrapper.find('.modal')            teleport 노드는 서브트리 밖
// ❌ global: { stubs: { teleport: true } }   제자리 렌더 = 검증 대상 소멸
// ✅
const el = document.body.querySelectorAll('.modal')
el[0].dispatchEvent(new Event('click', { bubbles: true }))
```

`wrapper.trigger()`도 같은 이유로 안 먹으므로 `dispatchEvent`로 간다. 정리(cleanup)에서 body에 남은 노드를 걷어내야 다음 케이스가 오염되지 않는다.

**③ stub을 그래도 쓴다면 — 참조가 리렌더마다 stale해진다 (2026-07-28 규명).**

②의 "단언이 흔들린다"의 **정확한 메커니즘**이다. `teleport: true` 스텁은 리렌더마다 `<teleport-stub>` **서브트리를 remove + add로 교체**한다(패치가 아니다). VTU 소스 `vue-test-utils.cjs.js:7737~7742`가 `isTeleport`/`isKeepAlive`에 대해 vnode 변환 캐시를 **의도적으로 스킵**한다(GitHub #1829/#1888 주석).

→ 클릭 **전에** `wrapper.find(...)`로 잡아둔 `DOMWrapper`는 클릭 후 **stale**이라 `disabled` 반영을 못 본다. 리렌더 직후 fresh `wrapper.find()`로 조회하면 정확히 반영된다.

```js
// ❌ const btn = wrapper.find('.submit');  await btn.trigger('click');  expect(btn.attributes('disabled'))...
// ✅ await wrapper.find('.submit').trigger('click')
//    expect(wrapper.find('.submit').attributes('disabled')).toBeDefined()   // fresh re-query
```

⚠ **더 위험한 변종 — stale 노드 재클릭**: stale 참조에 두 번째 클릭을 날리면 **`disabled` 게이트를 우회**한다. 단언은 통과하는데 케이스 목적(중복 제출 차단 검증)이 통째로 무력화된다 — 검증력 0인 채 GREEN.

**프로덕션은 정상이다.** 실 Vue Teleport는 타입 정체성을 유지하며 정상 패치한다(codex 교차검증 AGREE). 이건 **테스트 인프라 아티팩트**다 — 프로덕션 버그로 오진하고 코드를 고치면 안 된다.

비용 실측: 456/457 중 유일 FAIL의 원인 규명에 tester-frontend가 MutationObserver 디버그 하네스까지 제작해 **1라운드 통째** 소모. 같은 결함 클래스가 2건이었다(단언용 1 + 재클릭 1) — 후자는 검증자가 아니라 sweep 지시로 발견됐다.

**판단 기준 — 애초에 Teleport가 맞나:** 클리핑 회피가 목적이면 **재배치가 먼저**다. 프로젝트 rule에 이미 같은 취지가 있다 — "`overflow-x:auto` 컨테이너 안의 절대배치 드롭다운 클리핑 → Teleport보다 재배치 우선". Teleport는 재배치가 불가능할 때만.

**하네스 함의:** tester-design·RED 작성자가 이 관용구를 **선제 인지**해야 3라운드를 안 태운다. Teleport를 쓰는 컴포넌트의 spec을 설계할 때 이 페이지를 먼저 본다. 규칙화: `tester-design.md` **R20**(상태전이 후 fresh re-query) + `playbook-tdd.md` 7.6 체크리스트 ④.

**같은 계열 (VTU/jsdom DOM 단언 함정):** [[vue-vmodel-select-jsdom-artifact]](DOM `.value` 단언이 jsdom 아티팩트) · [[jsdom-missing-browser-apis]](jsdom 미구현 전역 API). 공통 교훈 — **jsdom+VTU의 DOM 표현은 브라우저와 다르다. 단언은 DOM 상태가 아니라 리액티브 귀결에 걸고**, DOM을 봐야만 할 땐 VTU 래퍼 대신 네이티브 API로 실체를 본다.
