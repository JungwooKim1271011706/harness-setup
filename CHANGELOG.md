# 하네스 CHANGELOG

semver `MAJOR.MINOR.PATCH`. `VERSION` 파일이 SSOT. 최신이 위.
레벨 기준·bump 의식: `docs/harness-versioning.md`.

## 2.0.0 — 2026-06-15
- **[MAJOR·게이트 불변식 변경] 설계패널 인원 규칙 재정의 + ceo 페르소나 제거.**
  - 인원 규칙: 신규·고복잡도 공통 **최소 3 / 최대 4, 연관(태그)기반**. eng 항상 + cso(보안)/design(UI)/devex(공통API/DAO)는 연관 시에만. 3 미만이면 채움순서(eng→devex→cso)로 3까지만. 4번째는 연관될 때만(강제 채움 금지). 기존 "신규≥3 / 고복잡도≥4(강제)"를 대체.
  - 근거: floor=3은 다수결 corroboration용. 고복잡도 깊이는 인원이 아니라 eng 다라운드(loop-until-dry)가 담당하므로 ≥4 강제 불필요.
  - **ceo 제거**: gstack plan-ceo-review는 "10-star product·expand scope"=제품 야심/범위확장 렌즈로, 사내 법원 시스템(scope 규율)과 충돌. `대규모범위` 태그도 함께 제거. (gstack엔 잔존하나 패널 미참조.)
  - 변경: orchestrator(패널표·인원규칙·라우팅·ascii 6곳), planner ×3(태그·라우팅표·예시), design-panel.js(주석), README(GATE 라벨), versions.md(plan-ceo 행 제거).
  - ⚠ 세션 재시작 필요: 현재 세션은 옛 정의(≥4 강제·ceo 포함)를 사용 중. 다음 구동부터 반영.

## 1.4.1 — 2026-06-15
- **README mermaid 정합화**: 제거된 단독 `/plan-eng-review` 노드(HC1→HCE→PL) 삭제. 고복잡도 트랙을 신규기능과 동일 흐름(office-hours→grill→co-plan→planner-high-complexity)으로 수정하고, eng 심층검증은 설계패널 eng 다라운드(gstack plan-eng-review 렌즈)임을 GATE 노드에 명시.

## 1.4.0 — 2026-06-15
- **sync-skills.sh SOURCES를 gstack 설치 경로로 재정합**. gstack 제공 스킬(office-hours·investigate·review·cso·benchmark·codex)의 원본을 `~/.claude/skills/<skill>`(설치 후 부재) → `~/.claude/skills/gstack/<skill>`로 수정. browse는 기존부터 gstack 경로.
- gstack 미제공 자체 스킬(co-plan·pair-impl·learning-gate·grill-with-docs)은 분리·유지 — 원본 부재 시 sync는 스킵하고 repo 미러로 동작.
- `versions.md`: "gstack 제공" / "자체·비-gstack" 두 표로 분리해 원본 경로 정합화.
- 매핑 근거: gstack v1.58.1.0 설치본에 실존하는 스킬만 gstack 경로로 전환(기계 확인).

## 1.3.0 — 2026-06-15
- **gstack 미러 고아 정리**: `skills/plan-eng-review/` 제거. v1.2.0에서 설계패널이 gstack 글로벌 경로(`~/.claude/skills/gstack/plan-eng-review/`)를 직접 Read하도록 바꾸면서 repo 미러가 미사용이 됨.
- `sync-skills.sh`: `plan-eng-review` SOURCES 엔트리 제거(원본 경로가 gstack 아래로 이동해 기존 경로는 더 이상 존재 안 함).
- ⚠ 알려진 잔여(별도 처리 예정): sync-skills.sh의 나머지 SOURCES 다수가 gstack 설치 후 `~/.claude/skills/<skill>`(없음) → `~/.claude/skills/gstack/<skill>`로 이동 필요. 현재 `browse`만 gstack 경로 사용 중.

## 1.2.1 — 2026-06-15
- `.gitignore`에 `.obsidian/`·`**/.obsidian/` 추가 — Obsidian vault 로컬 설정(머신로컬, 휴대 대상 아님) git 노이즈 제거.

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
