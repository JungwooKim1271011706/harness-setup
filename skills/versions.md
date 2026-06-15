# 스킬 버전 관리

> **마지막 전체 동기화**: 2026-06-11
> **동기화 방법**: `bash .claude/skills/sync-skills.sh`

## ⚠ 하드코딩 참조 스킬 (업데이트 시 사용자 검토 필요)

| 스킬 | 원본 경로 | 마지막 동기화 | 참조 위치 |
|------|---------|------------|---------|
| `learning-gate` | `~/.claude/skills/learning-gate/` | 2026-05-09 | `orchestrator.md`: `"학습 게이트 완료. 계속 진행해."` 트리거 문구 |
| `grill-with-docs` | `~/.agents/skills/grill-with-docs/` | 2026-05-09 | `orchestrator.md`: CONTEXT.md 업데이트 포맷 |

## 일반 스킬 (변경 시 자동 적용 가능)

| 스킬 | 원본 경로 | 마지막 동기화 |
|------|---------|------------|
| `office-hours` | `~/.claude/skills/office-hours/` | 2026-05-09 |
| `co-plan` | `~/.claude/skills/co-plan/` | 2026-05-09 |
| `pair-impl` | `~/.claude/skills/pair-impl/` | 2026-05-09 |
| `investigate` | `~/.claude/skills/investigate/` | 2026-05-09 |
| `review` | `~/.claude/skills/review/` | 2026-05-09 |
| `cso` | `~/.claude/skills/cso/` | 2026-05-09 |
| `benchmark` | `~/.claude/skills/benchmark/` | 2026-05-09 |
| `codex` | `~/.claude/skills/codex/` | 2026-05-09 |
| `browse` | `~/.claude/skills/browse/` | 2026-05-09 |

## gstack 글로벌 의존 (repo 미러 아님 — 추적 외)

> gstack 글로벌 설치(`~/.claude/skills/gstack/`)가 제공하는 스킬. repo `skills/`로 미러하지 않고 **설치 경로를 직접 Read**한다(gstack bin 헬퍼와 동일 정책). 버전은 gstack VERSION이 핀 — 업데이트는 `gstack-upgrade`로.

| 스킬 | 설치 경로 | 버전(gstack) | 참조 위치 |
|------|---------|------------|---------|
| `plan-eng-review` | `~/.claude/skills/gstack/plan-eng-review/` | 1.58.1.0 | `orchestrator.md` 설계패널 eng 렌즈(Read) |
| `plan-ceo-review` | `~/.claude/skills/gstack/plan-ceo-review/` | 1.58.1.0 | 설계패널 ceo 렌즈(`대규모범위` 태그) |
| `plan-design-review` | `~/.claude/skills/gstack/plan-design-review/` | 1.58.1.0 | 설계패널 design 렌즈(`UI` 태그) |
| `plan-devex-review` | `~/.claude/skills/gstack/plan-devex-review/` | 1.58.1.0 | 설계패널 devex 렌즈(`공통API/DAO` 태그) |
| `gstack/bin/*` | `~/.claude/skills/gstack/bin/` | 1.58.1.0 | `session-check.sh`(gstack-slug), plan-*-review 로깅 헬퍼 |

> ⚠ 보안(cso) 계획 렌즈는 gstack 스킬이 아니다 — design-panel.js `CSO_LENS`가 `claude-security-guidance.md`(repo track)를 Read. `gstack-upgrade` 후 위 4종 경로가 `gstack/` 아래 유지되는지 1회 확인할 것.
