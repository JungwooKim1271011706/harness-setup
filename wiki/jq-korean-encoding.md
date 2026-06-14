---
title: Slack 알림 한글 인코딩 함정
type: gotcha
links: [[slack-notify-hook]], [[windows-path-jq]]
updated: 2026-06-14
---

Windows에서 bash → `curl.exe`로 한글(UTF-8)을 보낼 때, **전달 방식**에 따라 깨지냐 마느냐가 갈린다.

## 증상
Slack에 한글이 `?׽?ƮB ??ڰ?` 처럼 깨져 보임.

## 원인
한글을 **curl 명령행 인자로** 넘기면(`curl -d '{"text":"한글"}'`), Windows의 인자 경계에서 UTF-8 → **cp949 변환**이 일어나 깨진다.

## 회피 (스크립트가 이미 채택한 방식)
payload를 **임시파일에 UTF-8로 기록**한 뒤 `curl -d @파일`로 보낸다. 인자 경계를 안 거치므로 바이트가 그대로 전송돼 한글이 보존된다.
- jq가 있으면 `jq -nc ... > tmp` 로 UTF-8 기록 (라벨·요약 한글 보존).
- jq가 없으면 ASCII 폴백(영어만). → jq 의존성은 [[windows-path-jq]] 참조.

## 교훈
[[slack-notify-hook]] 스크립트를 "간단하게" 인라인 `-d '{...}'`로 바꾸지 말 것. 그러면 한글이 다시 깨진다. ASCII(브랜치·시간)는 어느 경로든 안전하지만 한글·요약은 반드시 파일 경유.
