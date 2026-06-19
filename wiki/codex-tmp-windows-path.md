---
title: codex 호출 시 TMP 경로 mktemp 실패 → /tmp 폴백
type: gotcha
links: [[windows-path-jq]], [[gstack-install-windows]]
updated: 2026-06-19
---

## 증상
codex CLI 호출 시 `mktemp`이 실패하고 `/tmp` 폴백으로 1회 재시도한 뒤 동작한다. 첫 시도 실패로 재시도 지연이 1회 붙는다.

## 원인
벤더 `gstack-paths`의 `TMP_ROOT`가 Windows에서 `C:Users...` 형태로 생성된다 — 드라이브 콜론 뒤 슬래시가 누락(`C:Users` ≠ `C:\Users`)되어 유효하지 않은 경로라 `mktemp`이 거기에 임시파일을 못 만든다.

## 회피
- `/tmp` 폴백이 자동 동작하므로 기능은 정상. 단 1회 재시도 지연이 발생한다.
- ⚠ 벤더 코드(`gstack-paths`)는 직접 수정 금지(다음 sync 시 덮어써짐). 근본 수정은 벤더 sync 대기.
- 같은 Windows 경로 부류 함정: [[windows-path-jq]], [[gstack-install-windows]].
