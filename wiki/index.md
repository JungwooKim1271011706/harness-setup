# wiki 인덱스

> 하네스 운영 지식 카탈로그. 새 페이지 추가 시 여기 한 줄 등록. 작성 규칙은 [[_schema]].

## 운영 (operational)
- [[slack-notify-hook]] — CC 응답 완료 시 Slack 알림(글로벌 Stop 훅)의 구조·배포·비밀 관리

## Gotcha (함정·교훈)
- [[jq-korean-encoding]] — Slack 알림 한글이 깨지는 진짜 원인과 회피(파일 경유 vs curl 인자)
- [[windows-path-jq]] — Windows에서 CC가 stale PATH를 상속 → 훅에서 jq 못 찾는 문제와 자가탐색 해법
- [[gstack-install-windows]] — gstack/setup이 브라우저 추출에서 hang → 스킬 미등록. 등록만 수동 재현 + bun stale PATH
- [[surefire-nested-skip]] — Surefire 2.22.2 `-Dtest=클래스` 격리 실행이 JUnit5 @Nested를 무음 스킵 → 거짓 GREEN. 전체실행/`$Nested` 명시로 회피

## 관련 (repo 내 다른 지식 — 중복 금지, 링크만)
- 설계·ADR: `../docs/` (예: `../docs/harness-versioning.md` — 하네스 버전관리 설계 전문)
- 도메인·운영 용어 정의: `../CONTEXT.md`
- 로컬/머신 한정 메모: auto-memory `~/.claude/projects/.../memory/` (휴대 안 됨)
