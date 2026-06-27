---
title: renderer가 jsdom 미구현 브라우저 전역 API를 쓰면 단위테스트서 전수 폭발
type: gotcha
links: [[vite-stale-served-source-windows]], [[vue-immediate-watch-template-ref]]
sources:
  - ~/.claude/harness-retro-inbox/applied/20260624T120100Z__DEVUNIT-repostitch__wiki-css-escape-jsdom.md
  - DEVUNIT-repostitch PR-S2 (submodule-ff-import) 실측
updated: 2026-06-27
---

renderer 코드가 **jsdom이 구현하지 않은 브라우저 전역 API**(`CSS.escape`, `matchMedia`, 일부 `Range`/`Selection` 등)를 쓰면, 프로덕션(Electron/Chromium)에선 동작하지만 **vitest+jsdom 단위테스트 환경에선 `TypeError`로 해당 코드경로가 전수 폭발**한다. jsdom의 `globalThis.CSS`가 `undefined`이기 때문.

## 증상 (PR-S2 실측)
`import-mapping.js`의 `querySelector` 4곳을 인젝션 방어로 `CSS.escape(name)` 래핑 → 변경검증서 `TypeError: Cannot read properties of undefined (reading 'escape')`로 **63 FAIL**. 프로덕션에선 멀쩡 — jsdom만 미구현.

## 회피책
브라우저 전역 API를 renderer에서 쓰기 전 jsdom 지원 여부를 확인한다. 미지원이면 환경 가드 헬퍼로 감싼다:

```js
function _cssEsc(s) {
  return (typeof CSS !== 'undefined' && CSS.escape)
    ? CSS.escape(String(s))
    : String(s).replace(/[^\w-]/g, '\\$&');  // jsdom fallback
}
```

정상 입력엔 투명, jsdom선 fallback, Electron선 진짜 `CSS.escape`. (대안: vitest setup에 polyfill 주입 — 단 프로덕션 코드가 `CSS` 존재를 가정하게 되므로 가드 헬퍼가 더 안전.)

## 일반화
"프로덕션 OK, jsdom 폭발" 패턴. jsdom 미구현 브라우저 API는 다수(`CSS.escape`·`matchMedia`·일부 `Range`/`Selection`·`IntersectionObserver` 등). renderer DOM 코드를 테스트하기 전 env 호환을 확인하라 — NB(no-brainer)성 수정이라도 적용 전 테스트 env 호환을 안 보면 1라운드 churn. 디스크≠서빙([[vite-stale-served-source-windows]])·mount 타이밍([[vue-immediate-watch-template-ref]])과 함께 "프론트는 실행 환경이 진실을 가른다" 클래스.
