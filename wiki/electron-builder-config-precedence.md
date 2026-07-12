---
title: electron-builder — package.json build 키가 electron-builder.yml을 완전무시(병합 아님)
type: gotcha
links: [[electron-vitest-vimock-createrequire]], [[electron-before-quit-window-close-order]]
sources:
  - 발생세션: bundle-mingit slice (repostitch product, 소비자 세션, 2026-07-12)
  - 커밋 36ac6d1
  - node_modules/read-config-file/out/main.js loadConfig 소스 실측
  - inbox: ~/.claude/harness-retro-inbox/20260711T161349Z__DEVUNIT-repostitch.md
updated: 2026-07-12
---

**증상:** `package.json`에 `build` 섹션을 추가했더니 기존 `electron-builder.yml`이 조용히 죽고 배포계약이 바뀐다 — target `portable`→`nsis`, productName `RepoStitch`→`repostitch`. 빌드는 GREEN, 변경검증 단계서야 tester+codex 2소스로 발견.

**진짜 원인:** electron-builder `read-config-file`의 `loadConfig`는 `package.json`에 `build` 키가 **존재하면** `electron-builder.yml`을 **완전 무시**한다(병합이 아니라 우선순위 완전대체). 두 곳에 build 설정이 있으면 yml이 통째로 죽어 target/productName/files 계약이 소리 없이 바뀐다.

**회피:**
- build 설정은 **한 곳에만** 둔다.
- 신규 build 필드 추가 **전** 기존 `electron-builder.yml`/`.json` 존재를 코드베이스 스캔한다. 같은 설정이 여러 곳이면 어느 게 이기는지(병합 아닌 완전대체) 먼저 확인.
- 하네스 연동: orchestrator §설계검증의 "config 병합/우선순위 주입(필수)"이 grill-with-docs에 이 스캔을 강제한다(신규 빌드/배포/실행 config 도입 시).

**교훈:** 신규 config 필드는 "추가"처럼 보여도 기존 동종 config를 **완전대체**할 수 있다. 도입 전 동종 파일 존재 + precedence 확인.
