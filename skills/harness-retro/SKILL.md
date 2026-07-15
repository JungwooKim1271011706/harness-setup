---
name: harness-retro
description: 다른 세션·작업의 회고(retro)에서 도출된 하네스 개선 제안을 규칙화한다. 회고 텍스트를 입력받아 항목별 분류·대상파일 라우팅·bump레벨 추론·diff/wiki/bump 초안 작성·백로그 원장 기재까지 자동 수행하고, 적용·커밋은 사람 승인 후. "하네스 회고 반영", "이 회고 개선 반영해", retro/회고 텍스트를 붙여넣을 때 사용.
argument-hint: "[회고 텍스트 또는 회고 파일 경로]"
---

# 하네스 회고 반영 (회고 → 규칙화)

회고에서 도출된 하네스 개선 제안을 **분류 → 라우팅 → 초안 → 백로그 → 사람 승인 → 적용**으로 규칙화한다.
하네스 자기개선 루프의 **③ 규칙화** 단계 진입점이다. (①발견=`harness-feature-scan`, ②capture=`wiki/`, ④전파=VERSION/`git pull`)

## 불변식 (절대 위반 금지)
- **초안까지 자동, 적용은 사람 승인 게이트.** 발견·분류·라우팅·diff 초안·백로그 기재까지는 자동. 실제 파일 수정·커밋은 사용자 승인 후에만.
- 하네스 자동수정 금지 (feature-scan과 동일 거버넌스). 초안 산출은 **보조 입력** — 단독으로 게이트/규칙 변경 금지.
- **거버넌스 영향 항목**(게이트 구조 변경=MAJOR, 차단 훅 신설/변경, 사람승인 게이트 자체 변경)은 승인 요청 시 반드시 ⚠ 명시 경고하고 별도 확인을 받는다.

## 입력
- 회고 텍스트(붙여넣기) 또는 회고 파일 경로. 보통 "🔴 우선순위 높음 / 🟡 중간" 형태의 제안 목록.
- **inbox 모드(무인자 호출)**: 인자 없이 호출되면 머신글로벌 inbox `~/.claude/harness-retro-inbox/*.md`(pending — `applied/`·`rejected/` 하위 제외)를 전부 읽어 입력으로 삼는다. check가 딴 세션(worktree 등)서 드롭한 후보를 **복붙 없이** 드레인한다. 여러 파일이면 묶어서 한 번에 분류(같은 결함클래스는 통합).
- 둘 다 없으면(inbox도 비었으면) 사용자에게 회고 텍스트/경로를 요청한다.
- ⚠ **적용은 dev clone에서만**. 소비자 세션(제품 repo에 vendoring된 중첩 `.claude`)은 거기서 커밋하면 제품 repo에 갇히거나 SSOT와 갈린다 — 거기선 check 드롭까지만, 적용은 dev clone에서. **판별식 = `wiki/_schema.md` "어디로 가나" SSOT**(`basename $(git rev-parse --show-toplevel)` = `.claude` → 소비자. origin 판별 금지 — 중첩 `.claude`도 origin=harness-setup이라 오판, 2026-07-15 실사고).

## Step 1 — 회고 항목 파싱
각 제안을 개별 항목으로 분해한다. 항목마다 추출: `title`, 문제(증상), 제안 수정, 제안한 수정 위치(있으면), 근거(인용 failure 메모/사건).

## Step 2 — 분류 + 대상 파일 라우팅
각 항목을 종류로 분류하고 정확한 대상 파일로 라우팅한다:

| 종류 | 대상 파일 | 비고 |
|------|----------|------|
| RED/테스트 작성 규칙 | `agents/tester/tester-design.md` | TDD 7.5 RED 작성 |
| 테스트 실행/검증 규칙 | `agents/tester/tester-{backend,frontend}.md`, `agents/developer/developer-*.md` | |
| 테스트 품질 게이트 기준 | `agents/tester/tester-quality.md` | 7.7 |
| 게이트 구조·순서 변경(단계 신설 등) | `agents/orchestrator.md` TDD/게이트 구간 | ⚠ MAJOR 후보 |
| planner 작성 규칙 | `agents/planner/*.md` | |
| 설계 컨텍스트(OOP/co-plan) | `skills/co-plan`, co-plan 컨텍스트 | |
| 훅/경계 기계강제 | `hooks/*.sh` + `settings.json`, 또는 `/freeze` | ⚠ 거버넌스/MAJOR-ish |
| 운영 gotcha(증상→원인→회피) | `wiki/<slug>.md` (+ index 등록) | [[_schema]] capture 트리거 |
| 설계 전문(why)·용어 | `docs/`·`CONTEXT.md` | 링크만(중복금지) |
| **reject** | — | YAGNI / 거버넌스 불변식 위반 / 코드·git이 이미 기록 |

- 한 항목이 여러 파일에 걸치면 **모두** 라우팅한다(예: 외부 API DTO JSON 규칙 = tester-design + co-plan).
- 같은 결함 클래스 규칙은 중복 페이지를 새로 만들지 말고 기존 규칙에 통합한다.

## Step 3 — bump 레벨 추론
- **MAJOR**: 게이트 구조·순서 변경, 거버넌스 불변식·사람승인 게이트 변경, 새 차단 훅 → 세션 재시작 필수.
- **MINOR**: agent md 규칙 추가, 비차단 훅·스킬 추가/갱신.
- **PATCH**: 오타·문서·주석.
- 배치에 MAJOR 항목이 하나라도 있으면 그 커밋 bump는 MAJOR. 설계: `docs/harness-versioning.md`.

## Step 4 — 백로그 원장 기재 (feature-scan과 단일 원장)
`agent-memory/orchestrator/project_harness_improvement_backlog.md`(feature-scan과 **동일 파일**)에 각 항목을 정리한다:
- 항목별: 종류 / 대상파일 / bump / before→after / 근거 / **상태**(draft → approved → applied → rejected).
- 실제 파일 쓰기는 사용자 승인 후. 이 단계는 초안 제시까지.

## Step 5 — diff / wiki / bump 초안 작성
승인받을 수 있도록 항목별 구체 초안을 만든다(아직 적용 금지):
- agent md 규칙: 삽입할 정확한 문장(어느 절에) — 기존 규칙과 충돌·중복 점검.
- 게이트 구조: 변경 전/후 단계 시퀀스를 명시.
- 훅: 스크립트 초안 + `settings.json` 등록 위치.
- wiki: [[_schema]] 형식 페이지 스텁 + index 한 줄. **Step1에서 추출한 근거를 frontmatter `sources`에 보존**(회고 텍스트·failure·CHANGELOG·docs 경로). inbox 모드면 inbox 파일 경로 + `source_session`/`project`/`date`를 sources 후보로. 같은 결함 클래스가 기존 wiki에 있으면(Step2 "기존 통합" 규칙) 새 페이지 말고 **기존 페이지 갱신 + sources 병합**. 근거 없으면 sources invent 금지 — 승인요청에 "근거 부족" 표시.
- VERSION/CHANGELOG 초안.

## Step 6 — 사람 승인 게이트 (필수)
항목별로 승인/보류/거부를 받는다. 출력:
```
## 하네스 회고 반영 — 승인 요청 (N건)
| # | 항목 | 종류 | 대상 | bump | 거버넌스⚠ |
### 항목별 초안
(각 항목 diff/스텁)
### ⚠ 거버넌스 영향 항목
- #K [게이트구조/훅]: <무엇이 바뀌나 · 왜 MAJOR · 재시작 필요>
```
거버넌스 영향 항목은 반드시 별도 확인. 사용자가 **일부만** 승인할 수 있다.

## Step 7 — 승인분만 적용 + 커밋 (finalizer 의식)
승인된 항목만 적용한다:
1. 대상 파일을 Edit/Write로 초안 반영.
2. wiki 페이지 신설 시 `wiki/index.md` 등록 + 관련 페이지 `[[링크]]`.
3. **finalizer 버전 bump 의식 수행** — `agents/finalizer.md`의 `## 하네스 버전 bump 의식`을 따른다(VERSION bump + CHANGELOG + sync-skills critical diff 게이트). 절차 중복 문서화 금지.
4. 백로그 원장의 해당 항목 상태 draft→applied(거부분 rejected).
5. **inbox 모드였으면 처리한 파일 이동**: 적용분 inbox 파일은 `~/.claude/harness-retro-inbox/applied/`로, 거부분은 `rejected/`로 옮긴다(`mkdir -p` 후 `mv`). 재처리·중복 방지 + 상태 영속. = 처음 회고가 드러낸 "원장 드리프트"(딴 세션 로컬원장 draft ↔ dev backlog applied)를 단일 체인으로 해소.
6. 한 커밋. push는 사용자 승인 시.

## 경계
- 적용·커밋은 승인 후에만. 초안 단계에서 파일 수정 금지.
- **벤더 파일(`~/.claude/skills/gstack/`)은 수정 대상 아님**(글로벌 의존 — 동기화로 덮어써져 "고쳤다 착각" 사일런트 회귀). 분류·제안까지만.
- 회고가 가리킨 수정 위치가 **출처 프로젝트 로컬 경로**(harness repo에 부재, 예: `docs/learnings/*`)면 휴대용 위치(`wiki/`·`docs/`)로 **라우팅 보정**한다. 부재 경로를 휴대용 agent md에 그대로 박으면 다른 프로젝트에서 dangling.
