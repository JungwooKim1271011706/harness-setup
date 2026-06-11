# 하네스 버전 관리 (Harness Versioning) — v1 설계

## 문제

세션이 시작 시점의 하네스를 메모리에 들고 간다. 세션 도중 하네스가 갱신돼도(다른 세션이 커밋) 현재 세션은 옛 정의를 계속 쓴다.

실제 사고: 다른 세션의 `/codex review`가 7시간 무응답 행. 근본원인 = 타임아웃 가드 없던 **구버전 로컬 미러 스킬**을 들고 있었음. (글로벌은 2026-05-24부터 가드 보유했으나 런타임은 로컬 미러를 읽음 → 아래 §실측 참조)

## 레이어별 reload 특성

| 레이어 | 로드 시점 | 디스크 갱신 시 | 재시작 |
|--------|----------|--------------|--------|
| 스킬(codex 등) | invoke 때 lazy read | 다음 invoke가 최신 | ❌ 자가치유 |
| agent md(orchestrator.md 등) | 세션시작 → 시스템프롬프트 | 재주입 안 됨(추정) | ✅ 필요 |
| 훅(block-*.sh) | fire 때 read | 다음 fire가 최신 | ❌ |
| settings.json | 세션시작 | 미반영 | ✅ 필요 |

→ 재시작이 진짜 필요한 건 **agent md / settings**. 스킬은 자가치유.
→ ②(agent md가 compact/resume 시 재주입되는지)는 CC 내부동작이라 **미검증**. 안전기본값 = "재시작 필요"로 간주(틀려도 불필요 재시작 1회뿐, 손해 없음).

## 실측 (2026-06-11): 런타임은 로컬 미러를 읽는다

- 글로벌 `~/.claude/skills/codex/SKILL.md` mtime=2026-05-24, 타임아웃 wrapper 보유.
- 로컬 미러 `.claude/skills/codex/SKILL.md` mtime=2026-06-11(sync 시각), sync 전엔 구버전.
- **모순 추론**: 글로벌을 읽었다면 05-24부터 가드 있어 7h 행 불가. 행이 났다 = 구버전 로컬 미러를 읽음. ∴ 런타임 = 로컬 미러.
- 보강: sync-skills.sh가 글로벌→로컬 복사 존재 / 로컬이 `.claude` repo에 git-tracked / CC 우선순위(프로젝트 스킬이 유저 스킬 섀도잉).
- 신뢰도 높음(직접 주입테스트 아닌 논리추론, 7h 행이 로컬-읽기로만 설명됨).

## 설계 결정

### VERSION = SSOT
`.claude/VERSION` 단일 파일. semver `MAJOR.MINOR.PATCH`.

| 레벨 | 의미 | 재시작 |
|------|------|--------|
| MAJOR | 거버넌스 불변식·게이트 구조 변경 | 필수 |
| MINOR | agent md 규칙 추가 / 스킬 스냅샷 갱신 | 권장 |
| PATCH | 오타·문서·주석 | 불요 |

### 추적 범위
VERSION이 "이번에 바뀐 하네스 동작"을 대표하는 개념적 범위: agent md + 훅 + settings + 룰 + 워크플로 + **로컬 미러 스킬 스냅샷**. **네트워크 0**(전부 디스크 로컬).
- git-tracked: agent md, 훅, settings, 워크플로, 스킬 미러, VERSION/CHANGELOG.
- gitignore(머신로컬, git 추적 외지만 동작엔 영향 → 변경 시 bump 대상): `rules/`, `agent-memory/`, `state/`.

⚠ **알려진 한계 — bin 헬퍼는 추적 외**: 스킬 본문(SKILL.md)은 로컬 미러를 읽지만, 스킬이 호출하는 bin 헬퍼(`~/.claude/skills/gstack/bin/*`)는 본문에 글로벌 경로 하드코딩 → 미러 안 됨. VERSION이 bin 변경은 못 잡는다. bin은 gstack 관리(우리 하네스 아님)라 수용.

### bump = 사람 주도 (자동 변형 금지)
훅이 자동 sync·git pull·재시작 **안 한다**. 이유:
1. **critical 스킬 게이트 파괴**: `versions.md`가 learning-gate/grill을 수동검토로 막음(orchestrator.md가 트리거 문구 하드코딩 참조). 자동 sync면 계약 깨짐.
2. **dirty-tree**: 상시 미커밋분 존재. 자동 변형 = 충돌·유실.
3. 자동 = 사람이 결과 안 봄.

→ bump는 **finalizer가 하네스 변경 커밋 시 수행**(커밋 의식). 같은 커밋에서 `sync-skills.sh`도 실행(non-critical 자동, critical은 플래그→사용자 검토). 폐쇄망 무관(sync는 로컬 복사).

### 탐지 = 순수 안내
`session-check.sh`(SessionStart 훅) 확장. 새 훅 0개.
- 세션마다 시작 시점 VERSION을 `state/session-<id>.version`에 스탬프.
- compact/resume/clear 재발화 시 디스크 VERSION ≠ 스탬프면 → "하네스 vX→vY 갱신됨, 재시작 {필수|권장}" 안내. 자동 실행 없음.
- startup은 스탬프만 기록(이미 최신).

⚠ **근본 한계(솔직)**: compact/resume/clear를 한 번도 안 하는 순수 장시간 세션은 훅이 재발화 안 해 drift를 못 잡는다. PreToolUse마다 체크는 노이즈라 비채택. 이 경우는 사용자가 인지하거나 다음 세션에서 잡힘.

## 메커니즘 상세

### 스탬프 (state/session-<id>.version)
- 키 = SessionStart 훅 stdin의 `session_id`(없으면 `$PPID`). compact/resume는 같은 session_id 유지 → 스탬프 키 안정. 재시작 = 새 session_id = 새 스탬프 = fresh.
- startup → 스탬프=디스크VER 기록, 무경고.
- 비-startup + 스탬프 존재 + 디스크 ≠ 스탬프 → 경고. **스탬프 갱신 안 함**(재시작까지 매 compact 재알림).
- `state/`는 gitignore(머신로컬). 오래된 스탬프는 mtime +1일 청소.

### drift 메시지
- MAJOR 다름: `🔁 하네스 vX→vY (MAJOR) — 거버넌스/게이트 변경. 세션 재시작 필수(현 세션은 옛 정의 사용 중).`
- 그 외: `🔁 하네스 vX→vY — agent 정의/스킬 갱신. 세션 재시작 권장.`

### bump 의식 (finalizer, 하네스 변경 커밋 시)
1. 하네스 파일 편집(orchestrator가 이미 수행했을 수 있음).
2. `sync-skills.sh` 실행(로컬 미러 refresh).
3. critical 스킬(learning-gate/grill-with-docs) diff 있으면 → **자동커밋 금지, 사용자에 보고**. non-critical만 자동 포함.
4. `VERSION` bump(orchestrator가 지정한 레벨) + `CHANGELOG.md` 최상단 항목 추가.
5. 하네스 변경 + VERSION + CHANGELOG 한 커밋. push는 기존 규칙.

레벨 판정은 orchestrator가 finalizer 위임 시 지정(위 표 기준).

## 비채택 (명시적 거부)
- 자동 git pull / 자동 sync 실행 / 자동 재시작 — 거버넌스·dirty-tree 위험.
- PreToolUse 매턴 버전체크 — 노이즈.
- 기존 7일 스킬 staleness 경고(block #3)는 **유지**(별개 안전망, "sync 깜빡" 캐치).
