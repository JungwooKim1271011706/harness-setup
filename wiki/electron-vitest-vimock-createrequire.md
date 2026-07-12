---
title: vitest vi.mock('electron')이 createRequire(import.meta.url) 경로를 못 가로챈다
type: gotcha
links: [[electron-builder-config-precedence]], [[jsdom-missing-browser-apis]], [[vitest-mockresolvedvalue-microtask-flush]]
sources:
  - 발생세션: bundle-mingit M-A 스파이크 실측 (repostitch product, 2026-07-12)
  - 커밋 36ac6d1
  - inbox: ~/.claude/harness-retro-inbox/20260711T161349Z__DEVUNIT-repostitch.md
updated: 2026-07-12
---

**증상:** vitest `vi.mock('electron')`을 걸었는데 `createRequire(import.meta.url)('electron')` 경로가 mock을 못 받는다 → `require('electron').app === undefined` → crash.

**진짜 원인:** `createRequire`는 vitest 모듈러너 **밖에서** 네이티브 require를 생성한다 → vitest의 모듈 mock 그래프를 우회. `vi.mock`은 vitest가 관리하는 모듈 해석만 가로채므로, 러너 밖 네이티브 require는 손대지 못한다.

**회피:**
- electron을 **lazy-require**하는 모듈은 electron을 mock하지 말고 **인자화 seam**으로 테스트: 함수에 `app` override 파라미터를 추가하고 `process.resourcesPath`는 직접 스텁.
- 프로젝트 모듈 자체를 `vi.mock`하는 소비자 테스트(git-detect/git-runner 등)는 정상 동작 — createRequire(electron) 문제가 없다. 즉 문제는 electron 네이티브 모듈 mock 시도에 한정.

**교훈:** `createRequire`로 로드되는 네이티브 의존은 `vi.mock` 사각지대. mock 대신 인자화 seam으로 주입해 테스트.
