# 하네스 CHANGELOG

semver `MAJOR.MINOR.PATCH`. `VERSION` 파일이 SSOT. 최신이 위.
레벨 기준·bump 의식: `docs/harness-versioning.md`.

## 3.0.0 — 2026-06-18
- **[MAJOR·게이트 구조 변경] 셸 OAuth 세션 회고(2026-06-18) 6건 반영 — `/harness-retro` 첫 dogfooding.** v2.4.0에 만든 회고→규칙화 플로우로 분류·라우팅·승인·적용. ⚠ 게이트 시퀀스 변경 포함 → **세션 재시작 필수**.
  - **[#2·MAJOR] 7.6 "RED sanity" 단계 신설** — TDD 합의 구간 시퀀스 `7.5 codex RED → **7.6 RED sanity** → 7.7 품질게이트`로 변경. 7.6 = **tester-backend**가 `mvn test-compile` + RED 1회 실행 → "컴파일 OK + 올바른 이유로 FAIL(UOE/컴파일에러 아님)" 확인. 컴파일도 안 되는 RED 스위트가 7.7을 통과해 8/tester-backend에서야 터지던 것을 한 단계 앞에서 차단. `orchestrator.md`(7.6 절+ascii+라우팅 3곳), `tester-backend.md`(RED sanity 모드), `README.md`(mermaid T76) 동기화.
  - **[#1] RED 보안/negative 4규칙(R1~R4)** — `tester-design.md`: assertThrows(Exception) 금지(R1)·absence는 positive 쌍(R2)·sentinel 실주입(R3)·repo mock 실반환(R4). orchestrator 7.5에 codex 작성자 대상 주입 강제. (공허 단언으로 7.7이 3회 FAIL+escalation한 시간손실 방어 — `failure_2026-06-17_tdd77-vacuous-assertions.md`)
  - **[#3] 외부 API DTO JSON round-trip 테스트 필수** — `tester-design.md` + `co-plan`: 외부 API 응답 매핑 DTO는 실제 JSON ↔ DTO round-trip(ObjectMapper) 단위테스트 1건 필수. 목킹 RestTemplate이 @JsonProperty(snake_case) 매핑을 안 타 런타임 100% 실패할 버그가 통과하던 구멍 차단.
  - **[#4] planner diff before=Read 인용 강제** — `planner/{backend,frontend,high-complexity}.md` `### diff 형식`: 모든 diff의 -(before)는 파일 Read해 현재 코드 그대로 인용, 추정·환상변수 금지(불완전·존재하지 않는 코드 = 적용 시 컴파일 불가).
  - **[#5] 품질게이트 FAIL 반환 시 동일 결함 클래스 전수 sweep** — `orchestrator.md` 7.7 + `tester-quality.md`: 인용 케이스만 고치지 말고 모든 테스트 파일에서 같은 결함 클래스를 첫 루프부터 전수 sweep(7.7이 4라운드 걸린 원인 — un-scrutinized 케이스 재발견 방지).
  - **[#6] 금지 패키지 경계 — `/freeze` 배선** — `orchestrator.md` `## 작업 스코프 경계` 절: 트랙 시작 시 `/freeze <scope>`, finalizer 후 `/unfreeze`. 병렬 서브에이전트의 스코프 밖 편집을 프롬프트가 아닌 기계로 차단. (새 차단 훅(a)은 동적 스코프 주입 필요 + 거버넌스 부담으로 보류.)
  - co-plan repo 미러 손편집(글로벌 부재 → repo SSOT, sync 스킵이라 클로버 위험 없음). sync-skills 미실행(글로벌 무관 drift 방지).

## 2.4.0 — 2026-06-18
- **하네스 자기개선 루프 ③ 규칙화 단계 명문화 — `/harness-retro` 스킬 신설.** 그동안 ①발견(feature-scan)·②capture(wiki)·④전파(VERSION/pull)는 장치가 있었으나, "회고에서 나온 개선안을 하네스 규칙으로 승격"하는 ③ 규칙화는 매번 ad-hoc 수작업이었던 갭을 메움.
  - `skills/harness-retro/SKILL.md`(repo SSOT, 글로벌 미존재 → sync 안 함): 회고 텍스트 입력 → ① 항목 파싱 → ② 분류·대상파일 라우팅(agent-md/게이트구조/훅/wiki/docs/**reject**) → ③ bump레벨 추론(게이트구조·차단훅=MAJOR) → ④ 백로그 원장 기재(feature-scan과 단일 원장) → ⑤ diff/wiki/bump 초안 → ⑥ **사람 승인 게이트** → ⑦ 승인분만 적용+finalizer bump 의식.
  - **거버넌스 정합**: 초안까지 자동, **적용은 사람 승인**(불변식 = 하네스 자동수정 금지 유지). 거버넌스 영향 항목(게이트구조 MAJOR·차단훅·승인게이트 변경)은 ⚠ 명시 경고 + 별도 확인.
  - 세션 교훈 경계 내장: 벤더 파일(gstack) 수정 금지(분류·제안까지만), 부재 경로(출처 프로젝트 로컬 `docs/learnings/*`)는 휴대용 위치(wiki/docs)로 라우팅 보정.
  - `orchestrator.md`: `## 하네스 회고 반영` 절 신설(트리거·절차·가드레일). `versions.md`: repo-SSOT 목록에 harness-retro 추가. `README.md`: `## 하네스 자기개선 루프` 4층 표 추가.

## 2.3.0 — 2026-06-18
- **task3-picker 회고(2026-06-17)에서 도출한 테스트 검증 규칙 3종 추가.** agent md 규칙 추가(게이트 구조·불변식 변경 아님 → MINOR). critical 스킬(learning-gate/grill) diff 없음.
  - **[A] @Nested 무음 스킵 방지** — `developer-backend.md`·`tester-backend.md`: 테스트 검증은 전체 실행(`mvn -o test`) 또는 `-Dtest='클래스명$Nested클래스명'`로 @Nested 명시 포함. Surefire 2.22.2는 `-Dtest=클래스명` 격리 실행에서 JUnit5 `@Nested`를 조용히 스킵 → 격리 PASS만으로 GREEN/완료 판정 금지. (developer가 격리로 거짓 GREEN 보고 → 1사이클 낭비 사건)
  - **[B] 7.7 품질게이트 RED 픽스처 구조결함 검사** — `tester-quality.md` 기준9 신설(전부 critical): ① 테스트 간 논리모순(@Nested/형제가 같은 mock 입력에 상충 기대) ② Mockito strict stub 겹침(`anyLong()` vs `eq(0L)` 동일 호출 겹침 → UnnecessaryStubbing) ③ primitive 매처(`long`/`int`에 `any()` 금지 → unbox NPE, `anyLong()`/`anyInt()` 요구, 교정은 매처로). 통과한 RED에 잠복 시 GREEN 단계 표면화 → 재교정+재라운드 방지.
  - **[C] 계획서 diff 준수** — `developer-backend.md` 핵심 규칙: planner diff가 정확한 식·시그니처(예: `getApiBaseUrl()`)를 지정하면 임의 변경 금지, 이탈 근거 있으면 멈추고 보고. (임의 이탈이 단위테스트 mock으로 가려지는 라이브 배선버그를 부른 `getUrl()`↔`getApiBaseUrl()` 사고)
  - **라우팅 보정**: 회고가 가리킨 `docs/learnings/testing-surefire-nested-skip.md`는 출처 프로젝트(task3-picker) 로컬 경로라 harness 레포에 부재 → 휴대용 gotcha를 harness `wiki/surefire-nested-skip.md`로 신설(index 등록). agent md 양쪽이 긴 근거를 중복하지 않고 wiki 1곳을 가리킴(no-duplication).
  - 세션 한도 사망(#4)은 외부 토큰 문제라 제외(핸드오프 메모리·context-save로 완화 중, 레버리지 작음).

## 2.2.0 — 2026-06-16
- **codex provider 역할 분리(A2) 명문화.** 공식 OpenAI codex 플러그인(`codex@openai-codex`) 설치 후 provider가 둘이 됨 → 용도별로 가름.
  - **자동 흐름**(orchestrator의 5 진입점: TDD 7b·7.5 RED·7.7·/codex review 단계) = **gstack `/codex`**(Skill 자동호출 가능). 기존 `## codex 호출 가드`가 그대로 유효.
  - **사용자 주도 임의 리뷰** = **공식 플러그인**(`/codex:review`·`/codex:adversarial-review`). 공식 슬래시는 `disable-model-invocation`이라 orchestrator 자동호출 불가 → 자동 흐름과 충돌 없음.
  - `orchestrator.md`: `## codex provider — 역할 분리` 절 신설(명칭충돌 `codex:rescue` vs 공식 `codex-rescue` 에이전트 구분 포함). `README.md`: 셋업 §5 공식 플러그인 설치(선택) 안내.
  - 전면 전환(A1) 안 함 이유: 공식 슬래시가 자동호출 불가라 자동 흐름엔 gstack이 구조적으로 맞고, 분리가 안전장치(7시간-행 가드)를 안 건드림.

## 2.1.0 — 2026-06-16
- **gstack 스킬 de-vendor → 글로벌 단일출처 + 미설치 안내 모델로 전환.** gstack 스킬은 bin/lib/node_modules/브라우저 바이너리 의존이라 SKILL.md만 미러하면 반쪽(로깅 bin 등 깨짐) + 드리프트 누적 문제. 글로벌 `~/.claude/skills/gstack/`를 단일출처로 삼는다.
  - repo `skills/`에서 gstack 미러 7종 제거: office-hours·investigate·review·cso·benchmark·codex·browse.
  - `session-check.sh`: gstack 미설치/미등록(setup --no-prefix 안 함) 탐지 → 설치·등록 안내 추가(advisory).
  - `sync-skills.sh`: SOURCES에서 gstack 7종 제거, 자체 스킬(co-plan·pair-impl·learning-gate·grill-with-docs)만 동기화.
  - `tester-frontend/runtime.md`: browse 바이너리 경로의 repo-미러 분기 제거 → gstack 글로벌 경로로 단순화.
  - `versions.md`: "자체 스킬(track) / gstack 글로벌 의존(미러 아님)" 두 출처로 재구성. context-save·context-restore 등 슬래시 호출 스킬도 명시.
  - `README.md`: 셋업 4단계에 gstack 설치(--no-prefix 필수) 추가, 구조 테이블 skills 행 갱신.
- 배경: 이전까지 gstack 의존이 잠복(미설치 상태에서 plan-*-review·context-save 등이 조용히 미동작)했던 것을 명시적 의존+안내로 전환.

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
