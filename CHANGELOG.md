# 하네스 CHANGELOG

semver `MAJOR.MINOR.PATCH`. `VERSION` 파일이 SSOT. 최신이 위.
레벨 기준·bump 의식: `docs/harness-versioning.md`.

## 1.2.0 — 2026-06-15
- **gstack(v1.58.1.0) 설치 후 plan-*-review 경로 정합화**. gstack은 스킬을 `~/.claude/skills/gstack/<skill>/`(한 단계 아래)에 설치 → 하네스 하드코딩 경로가 어긋나던 것 정정.
  - `orchestrator.md` 설계패널: eng/ceo/design/devex 렌즈 Read 경로 `~/.claude/skills/plan-*-review/` → `~/.claude/skills/gstack/plan-*-review/`. 이로써 design/devex/ceo lens "무력화"(스킬 못 읽고 통과) 구멍 해소.
  - `planner-{backend,frontend,high-complexity}.md`: `보안` 태그 유발 페르소나 라벨 `plan-cso-review`(실존 안 함) → `cso` (design-panel `CSO_LENS` → `claude-security-guidance.md`)로 정정. orchestrator 선언과의 모순 제거.
  - `skills/versions.md`: plan-eng/ceo/design/devex-review + `gstack/bin/*`을 "gstack 글로벌 의존(repo 미러 아님)" 섹션으로 분리. plan-eng-review를 repo 미러 표에서 제거.

## 1.1.0 — 2026-06-15
- **wiki 운영지식 capture 트리거 도입**. `orchestrator`가 `post_commit` 학습게이트 시점에 "비자명하게 배운 운영지식·gotcha가 있나?" 자가점검 → 있으면 wiki 기록 제안(advisory, 자동커밋 X).
- `wiki/_schema.md`에 **"언제 기록하나 (capture 트리거)"** 절 신설 = 기록 시점·기준의 SSOT. orchestrator는 가리키기만(중복금지).

## 1.0.0 — 2026-06-11
- **하네스 버전 관리 도입 (baseline)**. `VERSION`/`CHANGELOG.md` 신설.
- `session-check.sh` 확장: SessionStart VERSION drift 탐지 → 세션 재시작 안내(순수 안내, 자동 변형 없음). 세션별 스탬프 `state/session-<id>.version`.
- `.gitignore`에 `state/` 추가(머신로컬 스탬프·스캔 산출 → git 노이즈 제거).
- `finalizer` bump 의식 + `orchestrator` 버전관리 섹션.
- 소급 기록(버전화 이전 변경): 직전 커밋 `8aa24bf` = codex 호출 무한대기 가드(`## codex 호출 가드`).
