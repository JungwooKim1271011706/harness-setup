---
title: Vue v-model/select 리셋 검증 RED는 DOM .value 단언 금지 (jsdom 아티팩트)
type: gotcha
links: [[jsdom-missing-browser-apis]], [[vitest-vimock-partial-throws]], [[vitest-mockresolvedvalue-microtask-flush]]
sources:
  - 발생세션: export-range-direction-guard 프론트 (DEVUNIT-authpatch_draft, 2026-07-16)
  - agent-memory project_export-trigger-modal-select-reset-jsdom-artifact.md
  - inbox: ~/.claude/harness-retro-inbox/20260716T144500Z__DEVUNIT-authpatch_draft.md
updated: 2026-07-16
---

**증상:** `<select>` v-model 리셋·전환 검증 RED를 native DOM `element.value === ''`로 단언하면, 리액티브 상태(endRef)는 정상인데 DOM `.value`만 옛값이라 FAIL(환경 아티팩트). 실브라우저(`$B`)에선 정상. 이 한 케이스가 3라운드 루프를 태움(변경검증 2회 FAIL + 재작업 3회).

**진짜 원인 (이중 아티팩트):**
1. jsdom + `@vue/test-utils`의 `vModelSelect` `_assigning` 가드가 'disabled 옵션 변경 + 값 리셋 동시' 시 native select DOM 동기화를 스킵 → 상태는 맞고 DOM만 옛값.
2. `wrapper.find()`가 remount 이전 노드를 정적 캡처 → `:key` 강제 리마운트해도 detach된 옛 노드 참조.

**회피:** native DOM 표시(`.value`/`.selectedIndex`)로 단언하지 마라. 대신 **관찰가능 리액티브 귀결**로 단언한다 — 컴포넌트가 상태를 노출하면 그 값, 아니면 리셋의 사용자 관찰 결과(생성버튼 disabled·emit 차단 등). ⚠ **구별력 자가검증 필수**: 리셋 로직을 임시 제거하면 그 단언이 실제 FAIL해야 한다(공허 아님).
- **픽스처 ≥3요소**: 2요소면 'A→B 전환'이 '이전 선택과 동일값'이 되어 별개 가드(동일값 체크)와 우연 일치 → 변별 불능(공허단언). 3요소로 변별값 확보(상세 tester-quality 7.7 §9-⑥).

**교훈:** v-model/select + jsdom은 DOM 표시를 신뢰하지 마라. 리액티브 귀결로 단언 + 리셋 제거 시 FAIL하는지 자가검증 + 픽스처 ≥3.
