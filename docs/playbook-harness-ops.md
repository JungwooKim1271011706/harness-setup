# Playbook — 하네스 메타 운영 (기능 스캔 / 회고 반영 / 버전 관리)

> **분리 문서** — `orchestrator.md`에서 추출(v3.2.0). 트리거가 드물어(30일 1회·회고 붙일 때·bump 시) on-demand로 분리. 해당 트리거 발동 시 orchestrator가 이 파일을 Read한다.
> **버전 동기 대상**: orchestrator 라우팅·거버넌스 변경 시 이 파일도 갱신한다. finalizer bump 의식의 "분리 문서 정합성 점검"이 강제(`finalizer.md ## 하네스 버전 bump 의식`).

---

## 하네스 기능 스캔 (CC 신기능·웹 모범사례 주기 흡수)

목적: CC 공식 신기능 + 웹 오케스트레이션 모범사례를 주기적으로 조사해 하네스 도입 후보를 백로그에 매핑한다. **자동 조사, 사람 적용** — 스캔은 자동/백그라운드지만 하네스 수정은 사람 판정(거버넌스 불변식).

### 트리거 (둘 다 동일 Workflow)
1. **자동(넛지)**: SessionStart 훅이 `🔍 HARNESS_FEATURE_SCAN_DUE`를 주입하면(마지막 스캔 ≥30일 또는 최초), orchestrator가 **백그라운드 Workflow를 1회 런치**한다.
2. **수동**: 사용자가 "기능스캔 돌려" / "하네스 기능 점검" 요청 시 즉시 런치.

### 런치 절차
1. **throttle 갱신 먼저**: `.claude/state/last-feature-scan` 파일에 오늘 날짜(YYYY-MM-DD)를 Write한다(없으면 디렉터리 포함 생성). **런치 직전에 갱신** → 매 재구동 재런치 방지(30일 1회). 자동 트리거 시 필수.
2. **사용자 통지 1줄**(논블로킹): "백그라운드 하네스 기능 스캔 시작(마지막 N일 경과). 완료 시 백로그 후보 보고." — 작업을 막지 않는다.
3. **Workflow 런치** (Workflow 도구는 본래 백그라운드 — task ID 즉시 반환, 완료 시 알림. `run_in_background` 파라미터 없음. 전달하면 InputValidationError):
   ```
   Workflow({
     scriptPath: '.claude/workflows/harness-feature-scan.js',
     args: {
       orchestratorPath: '.claude/agents/orchestrator.md',
       backlogPath: '.claude/agent-memory/orchestrator/project_harness_improvement_backlog.md',
       websearchAvailable: <WebSearch 도구가 이 세션 toolset에 있으면 true, 없으면 false>
     }
   })
   ```
   (경로는 전부 프로젝트 루트 기준 상대경로 — 머신·프로젝트 독립. 작업디렉터리=프로젝트 루트 가정.)
   - `websearchAvailable`: orchestrator tools에 WebSearch가 프로비저닝됐는지로 판정. 미검증/미노출이면 `false`(레인A CC기능 스캔만 수행 — 그래도 유효).
4. **완료 알림 수신 후**: 반환 `{ newCandidates, alreadyHave, rejected, backlogPatch, scanNotes }`를 검토.
   - `newCandidates`(high/medium) 위주로 보고하되, **각 후보를 반드시 before→after 구조로** 출력:
     ```
     N. [제목] — [priority]
        기능 설명: <featureDesc — 이 기능이 무엇이고 어떻게 동작하나>
        하네스 현황: <currentState — 지금 어떻게 동작/부재>
        도입 시 개선사항: <improvement — 접목 위치 + 무엇이 나아지나>
        (출처/근거/카베앗 1줄)
     ```
   - `alreadyHave`(이미 보유)·`rejected`(거버넌스 위반·YAGNI)는 제목+사유만 짧게.
   - `backlogPatch`(append 초안)를 백로그 메모리에 반영할지 **사용자에게 위임**. 자동 반영 금지.
   - `scanNotes`의 커버 못한 영역(curl 실패 등) 함께 보고(조용한 누락 금지).

### 가드레일
- 스캔 산출 = **보조 입력**. 도입 결정·하네스 수정은 사람.
- 자동 트리거라도 긴급 사용자 작업 중이면 작업 완료 후 런치(백그라운드라 충돌은 없으나 통지 타이밍 조정).
- research preview(Workflow)라 스캔 단독으로 게이트/규칙 변경 금지.

## 하네스 회고 반영 (회고→규칙화)

목적: 다른 세션·작업의 회고(retro)에서 나온 하네스 개선 제안을 규칙화한다. 하네스 자기개선 루프의 **③ 규칙화** 단계(①발견=하네스 기능 스캔, ②capture=wiki, ④전파=VERSION/`git pull`). **초안까지 자동, 적용은 사람 승인** — feature-scan과 동일 거버넌스.

### 트리거
1. **수동**: 사용자가 "하네스 회고 반영" / "이 회고 개선 반영해" 또는 회고/retro 텍스트를 붙여넣음.
2. orchestrator가 회고 형태 입력(🔴/🟡 우선순위 + 제안+수정위치 목록)을 인지하면 `/harness-retro` 실행을 **제안**한다(자동 적용 금지).

### 절차
`/harness-retro` 스킬을 호출한다(회고 텍스트/경로 전달). 스킬이 **분류→라우팅→bump추론→백로그 기재→초안 작성**까지 수행하고 **Step 6 승인 요청**에서 멈춘다. orchestrator는 스킬의 승인 요청을 사용자에게 그대로 전달하고, **승인분만** 적용+커밋(finalizer bump 의식)하도록 한다.

### 가드레일
- 회고 산출 = **보조 입력**. 규칙화 결정·하네스 수정은 사람 승인.
- 거버넌스 영향(게이트 구조=MAJOR, 새 차단 훅, 사람승인 게이트 변경)은 ⚠ 명시 경고 + 별도 확인.
- 벤더 스킬(gstack) 수정 금지(글로벌 의존). 부재 경로(출처 프로젝트 로컬)는 휴대용 위치(wiki/docs)로 라우팅 보정.

## 하네스 버전 관리 (VERSION drift 탐지 + 재시작 안내)

목적: 세션은 시작 시점 하네스(특히 agent md·settings)를 메모리에 들고 간다. 세션 도중 다른 세션이 하네스를 갱신·커밋하면 현재 세션은 옛 정의를 계속 쓴다. 이 drift를 **탐지해서 재시작을 안내**한다. (배경: codex 7h 행 = 구버전 로컬 미러 스킬을 들고 있던 세션. 설계 전문: `.claude/docs/harness-versioning.md`)

### SSOT = `.claude/VERSION` (semver MAJOR.MINOR.PATCH)
| 레벨 | 의미 | 재시작 |
|------|------|--------|
| MAJOR | 거버넌스 불변식·게이트 구조 변경 | 필수 |
| MINOR | agent md 규칙 추가 / 스킬 스냅샷 갱신 | 권장 |
| PATCH | 오타·문서·주석 | 불요 |

추적 범위 = `.claude/` 내부(agent md/훅/settings/룰/워크플로/**로컬 미러 스킬**). ⚠ 스킬 bin 헬퍼(`~/.claude/skills/gstack/bin/*`)는 글로벌 의존이라 추적 외(알려진 한계).

### 탐지 (자동) — session-check.sh가 수행
- SessionStart 훅이 세션 시작 시점 VERSION을 `state/session-<id>.version`에 스탬프.
- compact/resume/clear 재발화 시 디스크 VERSION ≠ 스탬프면 `🔁 하네스 버전 변경 …` 주입.
- orchestrator는 이 신호 수신 시 **사용자에게 재시작 안내**(MAJOR=필수/그 외=권장). 자동 재시작·자동 sync·자동 pull 금지 — 순수 안내.
- ⚠ 한계: compact/resume를 한 번도 안 한 순수 장시간 세션은 못 잡음(근본 한계).

### bump (사람 주도) — 하네스 변경 커밋 시
- **orchestrator 책임**: 하네스(`.claude/`)를 변경해 finalizer에 커밋 위임할 때, **bump 레벨(MAJOR/MINOR/PATCH)을 위 기준으로 판정해 지정**한다.
- **finalizer 책임**: VERSION bump + CHANGELOG 갱신 + `sync-skills.sh` 동반 실행(스킬 스냅샷 refresh) + **분리 문서 정합성 점검** + 한 커밋. critical 스킬(learning-gate/grill) diff 발생 시 자동커밋 금지·사용자 보고. (절차: finalizer.md `## 하네스 버전 bump 의식`)
- 자동 변형 금지 이유: critical 스킬 게이트 파괴·dirty-tree 위험. 그래서 훅이 아니라 커밋 의식에 묶는다.
