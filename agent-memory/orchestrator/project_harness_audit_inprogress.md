---
name: harness-audit-inprogress
description: 하네스 점검 작업 큐 (P2/P3 남음). 임시 파일 — 작업 완료 후 이 파일과 MEMORY.md 인덱스 항목 둘 다 삭제할 것
metadata:
  type: project
---

# 작업 큐 — 하네스 점검

> **임시 파일** — 다음 세션에서 P2/P3 완료 후 이 파일과 MEMORY.md 인덱스 항목 둘 다 삭제할 것 (orchestrator 시스템 프롬프트의 ephemeral task details 저장 금지 라인 준수)

## 완료된 작업
- **P0~P1** — 커밋 5개 푸시: `9b10e78` (tester-design 필수), `75ac82b` (/co-plan 필수), `6805f3e` (learning-gate 경로), `502c8df` (/codex review 필수), `ceaa7d2` (Bash 부여 + context-save 도입)
- 글로벌 학습 게이트 SKILL.md도 동일 패턴 수정 (git 추적 X)

## 남은 작업

### P2-1 — `/verify-implementation` 라우팅 추가 (작업량 작음)
- 이미 `.claude/skills/verify-implementation/` 설치되어 있음
- 위치: `tester-runtime PASS → /verify-implementation → /review` (orchestrator.md 5곳 동기화 필요: 핵심 규칙, 라우팅 규칙 3곳, 흐름도, 라우팅 표)

### P2-2 — 미등록 훅 2개 정책 결정 (결정만, 구현 작음)
- `.claude/hooks/commit-session.sh`
- `.claude/hooks/load-recent-changes.sh`
- 두 훅의 내용 먼저 읽어보고 의도 비활성화인지 잊혀진 건지 확인 → 등록 or 삭제

### P3-1 — 누락 에이전트 메모리 디렉터리 초기화 (8개)
대상:
- planner-frontend, planner-backend, planner-high-complexity
- developer-frontend, developer-backend
- tester-design, tester-frontend
- finalizer

각 에이전트의 `.claude/agent-memory/{agent}/MEMORY.md`만 빈 인덱스로 생성

### P3-2 — `/health` 도입 (수동 호출 전용)
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
