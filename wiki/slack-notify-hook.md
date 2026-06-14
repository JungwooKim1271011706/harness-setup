---
title: Slack 응답완료 알림 훅
type: operational
links: [[jq-korean-encoding]], [[windows-path-jq]]
updated: 2026-06-14
---

CC가 응답을 마칠 때(폰+PC) Slack으로 알림을 보내는 **글로벌 Stop 훅**.

## 배치
- **훅 등록**: 글로벌 `~/.claude/settings.json`의 `Stop` 훅 → `bash "$HOME/.claude/hooks/notify-slack.sh"`. repo의 per-project `settings.json`이 아니라 글로벌이라 **모든 프로젝트/세션**에서 발동.
- **활성 스크립트**: `~/.claude/hooks/notify-slack.sh`. **소스 사본**은 repo `skills/claude-notify/notify-slack.sh` (수정 시 양쪽 미러링).
- **웹훅 비밀**: `~/.claude/.secrets/slack-webhook` (스크립트가 `$SCRIPT_DIR/../.secrets/slack-webhook`로 읽음). 실제 Slack incoming webhook — 절대 echo/커밋 금지. repo `.gitignore`가 `**/slack-webhook` 차단.

## 메시지 구성
- top-level `text` = `[CC] 프로젝트 [브랜치] 세션ID · 응답 완료 HH:MM:SS` (푸시/토스트 미리보기).
- attachment = 응답 요약 3줄(300자 컷) + cwd 해시 기반 프로젝트별 색띠.

## 알아둘 의존성/함정
- 한글 보존은 [[jq-korean-encoding]] 참조 — payload를 임시파일에 UTF-8로 쓰고 `curl -d @file`로 보내야 안 깨진다.
- jq가 PATH에 없을 때의 자가탐색은 [[windows-path-jq]] 참조.
- 알림 훅이라 어떤 경로로도 `exit 0` — 응답 흐름을 절대 막지 않는다.

## 바꾸려면
문구·요약 줄수는 `~/.claude/hooks/notify-slack.sh` 수정 후 repo 소스 사본에 미러링. 훅 등록 변경은 CC 재시작 또는 `/hooks`로 리로드 필요.
