---
name: harness-audit-inprogress
description: 하네스 점검 작업 큐 (P3-2만 남음). 임시 파일 — P3-2 완료 후 이 파일과 MEMORY.md 인덱스 항목 둘 다 삭제할 것
metadata:
  type: project
---

# 작업 큐 — 하네스 점검

> **임시 파일** — P3-2 완료 후 이 파일과 MEMORY.md 인덱스 항목 둘 다 삭제할 것 (orchestrator 시스템 프롬프트의 ephemeral task details 저장 금지 라인 준수)

## 완료된 작업
- **P0~P1** — 커밋 5개 푸시: `9b10e78` (tester-design 필수), `75ac82b` (/co-plan 필수), `6805f3e` (learning-gate 경로), `502c8df` (/codex review 필수), `ceaa7d2` (Bash 부여 + context-save 도입)
- 글로벌 학습 게이트 SKILL.md도 동일 패턴 수정 (git 추적 X)
- **P2-1** (2026-05-29) — `/verify-implementation` 라우팅 6곳 동기화. **"verify-* 스킬 등록 시" 조건부**로 추가 (현재 등록 verify 스킬 0개라 무조건 필수는 빈 실행 유발하므로). 위치: `tester-runtime PASS → /verify-implementation → /review`
- **P2-2** (2026-05-29) — 미등록 훅 2개 삭제(git rm): `commit-session.sh`(자동 커밋이 승인 게이트와 충돌), `load-recent-changes.sh`(python3 의존 + SessionStart는 session-check.sh로 일원화)
- **P3-1** (2026-05-29) — 누락 메모리 디렉터리 8개 생성: planner×3, developer×2, tester-design/frontend, finalizer (각 빈 MEMORY.md)

## 남은 작업

### P3-2 — `/health` 도입 (수동 호출 전용) — 별도 세션 진행 예정
- 자동 라우팅 X
- 모듈별 점수 추적 (tocFramework/tocProcess/tocServer)
- 도구 설치 + 가중치 결정 필요

## 상세 컨텍스트
- `~/.gstack/projects/{slug}/checkpoints/` 의 최근 `harness-audit` 파일 참조 (24시간 이내 session-check.sh가 자동 안내)

## 다음 세션 자가검증 권장 (Bash 가용 확인)
1. 간단한 Bash 명령으로 도구 가용 확인 (`bash --version` 같은 것)
2. `/context-save 테스트` 호출 → 표준 경로(`~/.gstack/projects/{slug}/checkpoints/`)에 파일 생성되는지 확인
3. session-check.sh가 P4 메모를 감지해서 시작 시 안내했는지 확인 (안 됐으면 훅 로직 검증)

## 사용자 학습 레벨
- Claude harness workflow governance: **중급** (3회 연속 정답)
- 다음 게이트는 약점/한계 질문 → 정답 시 고급 상향
