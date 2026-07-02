# 스킬 버전 관리

> **정책 (v3.11.0~)**: 스킬은 **세 출처**다. 동기화(sync) 대상은 **외부 제3자 스킬뿐**.
> 1. **자체 authored 스킬** — repo `skills/`가 곧 origin(SSOT). 받아올 상류 없음 → **sync 대상 아님**.
> 2. **외부 제3자 스킬** — 외부에서 받아와 repo로 vendoring(track). `sync-skills.sh`로 글로벌 원본→repo 미러. 현재 `grill-with-docs`(Matt Pocock) 1개.
> 3. **gstack 스킬** — repo에 미러하지 **않는다**. 글로벌 `~/.claude/skills/gstack/`에 의존. 미설치/staleness 시 `session-check.sh`가 안내(advisory). 갱신은 `gstack-upgrade`.
>
> **동기화 방법(외부 스킬)**: `bash .claude/skills/sync-skills.sh`
> **마지막 동기화**: 2026-07-02

## 외부 제3자 스킬 (sync 대상 — repo vendoring track)

### ⚠ 하드코딩 참조 (critical — 자동복사 금지, 업데이트 시 사용자 검토 필요)

| 스킬 | 출처 | 원본 경로 | 마지막 동기화 | 참조 위치 |
|------|------|---------|------------|---------|
| `grill-with-docs` | Matt Pocock (외부) | `~/.agents/skills/grill-with-docs/` | 2026-05-09 | `orchestrator.md`: CONTEXT.md 업데이트 포맷 / planner-backend·frontend·high-complexity 참조 |

> `grill-with-docs`는 외부 스킬이라 글로벌 원본을 받아와야 갱신된다. 영향 표면이 넓어(planner 3종 + finalizer + orchestrator) critical로 지정 — sync 시 자동복사하지 않고 diff만 감지·알림, 사람이 검토 후 수동 `cp`.

## 자체 authored 스킬 (repo SSOT — sync 안 함)

> 아래는 이 하네스에서 직접 만든 스킬. repo가 origin이라 동기화할 상류가 없다. 글로벌 sync 소스 경로도 두지 않는다(과거 phantom 경로 제거 — v3.11.0).

| 스킬 | 비고 |
|------|------|
| `co-plan` | planner 호출 전 인터랙티브 계획. orchestrator 참조. (v3.0.0 직접 수정) |
| `pair-impl` | developer 호출 전 페어 구현. orchestrator 참조. |
| `learning-gate` | orchestrator 하드코딩 트리거 `"학습 게이트 완료. 계속 진행해."` 의존. |
| 그 외 | claude-notify·harness-setup·harness-retro·harness-check·manage-skills·merge-worktree·rule-maker·verify-implementation — repo SSOT. |

> `harness-retro`(v2.4.0~): 회고→하네스 규칙화 진입점. orchestrator `## 하네스 회고 반영` 참조.
> `harness-check`(v3.1.0~): 운영 고통 자가 탐지 → 개선 후보 → `/harness-retro` 위임. orchestrator `## 하네스 운영 자가 회고` 참조.

## gstack 글로벌 의존 (repo 미러 아님 — 추적 외)

> 글로벌 `~/.claude/skills/gstack/`(현재 v1.58.1.0)가 제공. repo `skills/`로 미러하지 않는다.
> - **Read 참조**(설계패널 렌즈): orchestrator가 설치 경로를 직접 Read.
> - **슬래시 호출**(`/office-hours`·`/review`·`/cso`·`/context-save`·`/context-restore` 등): `./setup --no-prefix` 등록 필요(top-level 노출). 미등록 시 호출 불가 → session-check.sh 안내.
> - **staleness**: session-check.sh가 gstack 마지막 갱신 후 경과일(7일 임계)을 점검 → `gstack-upgrade` 권장(네트워크 0, mtime 기반).

| 항목 | 설치 경로 | 참조 방식 |
|------|---------|---------|
| `plan-eng-review` | `~/.claude/skills/gstack/plan-eng-review/` | 설계패널 eng 렌즈(Read) |
| `plan-design-review` | `~/.claude/skills/gstack/plan-design-review/` | 설계패널 design 렌즈(`UI` 태그, Read) |
| `plan-devex-review` | `~/.claude/skills/gstack/plan-devex-review/` | 설계패널 devex 렌즈(`공통API/DAO` 태그, Read) |
| `context-save` · `context-restore` | `~/.claude/skills/gstack/context-{save,restore}/` | orchestrator 자동 save / 사용자 명시 restore(슬래시) |
| `office-hours`·`review`·`cso`·`investigate`·`codex`·`browse`·`benchmark` | `~/.claude/skills/gstack/<skill>/` | 흐름 내 슬래시 호출 |
| `gstack/bin/*` | `~/.claude/skills/gstack/bin/` | `session-check.sh`(gstack-slug), 로깅 헬퍼 |

> ⚠ 보안(cso) 계획 렌즈는 gstack 스킬이 아니다 — design-panel.js `CSO_LENS`가 `claude-security-guidance.md`(repo track)를 Read. (gstack은 plan-ceo-review도 제공하나 패널이 ceo를 미사용해 미참조 — v2.0.0.)
