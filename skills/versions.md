# 스킬 버전 관리

> **정책 (v2.1.0~)**: 스킬은 **두 출처**다.
> 1. **자체 스킬** — repo `skills/`에 vendoring(track). `sync-skills.sh`로 원본에서 동기화.
> 2. **gstack 스킬** — repo에 미러하지 **않는다**. 글로벌 `~/.claude/skills/gstack/`에 의존하며, 미설치/미등록 시 `session-check.sh`가 설치를 안내(advisory). 갱신은 `gstack-upgrade`.
>
> **동기화 방법(자체 스킬)**: `bash .claude/skills/sync-skills.sh` — 마지막 동기화 2026-06-11.

## 자체 스킬 (repo vendoring — track)

### ⚠ 하드코딩 참조 (업데이트 시 사용자 검토 필요)

| 스킬 | 원본 경로 | 마지막 동기화 | 참조 위치 |
|------|---------|------------|---------|
| `learning-gate` | `~/.claude/skills/learning-gate/` | 2026-05-09 | `orchestrator.md`: `"학습 게이트 완료. 계속 진행해."` 트리거 문구 |
| `grill-with-docs` | `~/.agents/skills/grill-with-docs/` | 2026-05-09 | `orchestrator.md`: CONTEXT.md 업데이트 포맷 |

### 일반 (원본 부재 시 sync 스킵, repo 미러로 동작)

| 스킬 | 원본 경로 | 마지막 동기화 |
|------|---------|------------|
| `co-plan` | `~/.claude/skills/co-plan/` | 2026-05-09 |
| `pair-impl` | `~/.claude/skills/pair-impl/` | 2026-05-09 |

> 그 밖의 자체 스킬(claude-notify·harness-setup·harness-retro·manage-skills·merge-worktree·rule-maker·verify-implementation)은 sync 대상이 아니라 repo가 SSOT.
>
> `harness-retro`(v2.4.0~): 회고→하네스 규칙화 진입점. 글로벌 미존재 = repo SSOT, sync 안 함. orchestrator `## 하네스 회고 반영` 참조.

## gstack 글로벌 의존 (repo 미러 아님 — 추적 외)

> 글로벌 `~/.claude/skills/gstack/`(현재 v1.58.1.0)가 제공. repo `skills/`로 미러하지 않는다.
> - **Read 참조**(설계패널 렌즈): orchestrator가 설치 경로를 직접 Read.
> - **슬래시 호출**(`/office-hours`·`/review`·`/cso`·`/context-save`·`/context-restore` 등): `./setup --no-prefix` 등록 필요(top-level 노출). 미등록 시 호출 불가 → session-check.sh 안내.

| 항목 | 설치 경로 | 참조 방식 |
|------|---------|---------|
| `plan-eng-review` | `~/.claude/skills/gstack/plan-eng-review/` | 설계패널 eng 렌즈(Read) |
| `plan-design-review` | `~/.claude/skills/gstack/plan-design-review/` | 설계패널 design 렌즈(`UI` 태그, Read) |
| `plan-devex-review` | `~/.claude/skills/gstack/plan-devex-review/` | 설계패널 devex 렌즈(`공통API/DAO` 태그, Read) |
| `context-save` · `context-restore` | `~/.claude/skills/gstack/context-{save,restore}/` | orchestrator 자동 save / 사용자 명시 restore(슬래시) |
| `office-hours`·`review`·`cso`·`investigate`·`codex`·`browse`·`benchmark` | `~/.claude/skills/gstack/<skill>/` | 흐름 내 슬래시 호출 |
| `gstack/bin/*` | `~/.claude/skills/gstack/bin/` | `session-check.sh`(gstack-slug), 로깅 헬퍼 |

> ⚠ 보안(cso) 계획 렌즈는 gstack 스킬이 아니다 — design-panel.js `CSO_LENS`가 `claude-security-guidance.md`(repo track)를 Read. (gstack은 plan-ceo-review도 제공하나 패널이 ceo를 미사용해 미참조 — v2.0.0.)
