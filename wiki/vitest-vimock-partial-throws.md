---
title: vitest vi.mock 부분대체 — 팩토리 미반환 named export는 undefined 아닌 throw
type: gotcha
links: [[electron-vitest-vimock-createrequire]], [[vitest-mockresolvedvalue-microtask-flush]], [[vue-vmodel-select-jsdom-artifact]]
sources:
  - 발생세션: trackB-web-export-paging-workspace-removal 프론트 tester LOOP1 (2026-07-16)
  - inbox: ~/.claude/harness-retro-inbox/20260716T142937Z__DEVUNIT-authpatch_draft-trackB.md
updated: 2026-07-16
---

**증상:** developer가 프로덕션에 `PAGE_SIZE_OPTIONS ?? fallback` 폴백을 "vi.mock 부분대체 시 undefined일 수 있음" 가정으로 넣었으나, 실제 vitest strict mock guard는 팩토리 미반환 named export 접근 시 **undefined가 아니라 즉시 throw** → 폴백 실행 전 script setup 전체가 죽어 파일 12/12 FAIL.

**진짜 원인:** vitest `vi.mock(mod, factory)` 부분대체에서 **factory가 명시하지 않은 named export는 자동 제공되지 않고, 접근 시 throw**한다(undefined 반환 아님). 컴포넌트가 쓰는 export 하나라도 factory에서 빠지면 모듈 로드 시점에 터진다.

**회피:**
- 컴포넌트가 쓰는 **모든 named export를 factory에 넣는다**(`importOriginal()`로 원본 스프레드 후 필요분만 오버라이드하는 패턴 권장).
- 프로덕션에 `?? fallback` 방어를 넣지 마라 — **테스트커플링 안티패턴**이다. 프로덕션은 정상 import를 전제하고, mock 누락은 테스트를 고쳐서 잡는다.
- tester-frontend가 이 클래스를 변경검증서 잡는다(mock 누락 throw = 전량 FAIL 신호).

**교훈:** 부분 mock은 "안 준 건 undefined"가 아니라 "안 준 건 throw". 프로덕션 폴백으로 우회하지 말고 factory를 완전하게 채운다.
