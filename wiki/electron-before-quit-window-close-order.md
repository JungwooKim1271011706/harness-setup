---
title: Electron before-quit는 창 X경로서 창 파괴 後 발화 — 종료확인은 window close에서
type: gotcha
links: [[jsdom-missing-browser-apis]]
sources:
  - inbox 20260709T062556Z / repostitch quit-abort 세션 (설계패널 3인+codex 1차계획 critical 적발)
updated: 2026-07-09
---

## 증상
창 X버튼 실제 이벤트 순서 = window `close` → 창 파괴 → `window-all-closed`(여기서 `session.clear`+`app.quit`) → **그제서야** `before-quit`. 즉 `before-quit` 단일 게이트로 종료확인 dialog를 걸면 X경로에선 이미 창·세션이 파괴된 후라 "취소→유지"가 불성립한다.

## 진짜 원인
`before-quit`는 앱 종료 시퀀스의 **끝**에 온다(X경로에선 창 파괴·세션 클리어 이후). 실행 중 "정말 종료?" 확인은 창이 살아있을 때 걸어야 하는데 before-quit 시점엔 늦다.

## 회피 (검증됨)
실행 중 종료확인이 필요하면 **BrowserWindow `close` 이벤트에서 `event.preventDefault()`로 창 파괴를 먼저 차단**하고 그 컨텍스트에서 dialog를 띄운다. `before-quit`는 `app.quit`/ipc quit/OS quit 경로 전용으로 남긴다. 두 경로 공유 로직을 quit-guard로 분리.

## 근거
repostitch quit-guard.js. 1차 계획(before-quit 단일 게이트)을 설계패널 3인+codex가 critical로 적발 → 재설계.
