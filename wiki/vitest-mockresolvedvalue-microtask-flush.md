---
title: vi.fn().mockResolvedValue()는 continuation 재개에 ~3 microtask tick 필요 — 고정 틱 flush 금지
type: gotcha
links: [[jsdom-missing-browser-apis]]
sources:
  - inbox 20260709T062556Z / repostitch quit-abort 세션 IH-1
updated: 2026-07-09
---

## 증상
async 핸들러 테스트에서 `await Promise.resolve()`×2로 microtask를 flush했는데, mocked 비동기 게이트(`await detectGit()` 등, `detectGit=vi.fn().mockResolvedValue(x)`) 뒤 코드에 도달 못 해 `resolveRun` 등이 `undefined`인 채 TypeError. 7.7 정적리뷰는 통과하고 **GREEN 실행서야** flaky FAIL.

## 진짜 원인
순수 native `await Promise.resolve(x)`는 1 microtask tick이면 재개하지만, `vi.fn().mockResolvedValue(x)`를 await하면 **스파이 래핑 오버헤드로 ~3 tick** 걸린다. 고정 `await Promise.resolve()`×2로는 mocked 게이트 뒤 continuation에 도달하기 전에 단언이 실행돼 취약.

## 회피 (검증됨)
고정 틱 개수 대신 **조건 충족까지 상한 루프로 flush**(flush-until-condition):
```js
for (let i = 0; i < 20 && !cond; i++) await Promise.resolve();
```
틱 개수에 비의존이라 스파이 래핑 tick 수가 달라져도 견고.

## 하네스 적용
tester-design R16(`## RED 보안/negative 테스트 규칙`)이 이 패턴을 강제 — async 핸들러 flush는 고정 틱 금지, flush-until-condition. 7.7 tester-quality가 고정 틱 flush를 취약으로 지적.
