# 하네스 CHANGELOG

semver `MAJOR.MINOR.PATCH`. `VERSION` 파일이 SSOT. 최신이 위.
레벨 기준·bump 의식: `docs/harness-versioning.md`.

## 3.10.0 — 2026-06-19
- **feature-12 oauth-guard 버그수정 회고 5건 반영 — tester 규칙 + 운영 wiki 3건 (harness-retro).** feature-12 bug-fix의 /harness-check 자동 회고(출처 9cf2ae4)에서 도출. 거버넌스 불변식 불변(agent md 규칙 추가·wiki 신설) → bump MINOR. (feature-1-harness-ing 브랜치 머지 — 원 라벨 v3.8.0이 main v3.8/3.9 선점과 충돌해 **v3.10.0 재라벨**.)
  - **`tester-backend.md` ## 핵심 규칙**: `*IT`/`*ITCase` 기본 스캔 누락 가드 추가. surefire 기본 include 4패턴 미매칭 시 `mvn test` 무음 누락 → `-Dtest=`만 PASS 판정 금지. 배경 `wiki/surefire-it-naming-skip.md`(신설, [[surefire-nested-skip]] 상호링크).
  - **`tester-design.md` RED 규칙 R7/R8 추가** + `playbook-tdd.md` 주입 표기 `(R1~R4)`→`(R1~R8)`(기존 stale 정정). R7=메시지 단언 프로덕션 소스 verbatim 복사(현지화 추측 금지), R8=기존 테스트파일 보존(통째 replace 금지, git diff 점검).
  - **운영 wiki 신설**: `codex-python-shim-windows.md`(codex --json이 Windows Store python shim 선택 → exit 101, PYTHON_CMD 명시 + 차단훅 mvn 오탐 회피 노트), `spring-profile-bean-eval-timing.md`(@Profile 등록시점 평가 → ApplicationContextRunner withPropertyValues로). index 등록.
  - **reject**: C4 차단훅 heredoc mvn 오탐 — `block-orchestrator-exec.sh`는 이미 워드바운더리 매칭, 본문 안전제외엔 쉘파싱 필요(fragile+우회위험). 호출측 리터럴 회피로 대체.

## 3.9.0 — 2026-06-19
- **회고 inbox 알림 — 매 프롬프트(UserPromptSubmit) 감지, dev clone 한정 (사용자 요청 + v3.8.0 §7 정정).** v3.8.0이 inbox 넛지를 `session-check.sh`(SessionStart)에 넣었으나 **실효 없음이 드러남**: dev clone은 자체 `.claude/` 서브디렉터리가 없어 repo 훅이 세션에 안 걸리고(글로벌 `~/.claude`로만 동작), 소비자 세션은 origin 게이트로 막혀 양쪽 다 안 떴다. 사용자 의도 = "dev clone 띄워두고 매 상호작용마다 감지·알림, 모아서 일괄 적용". → 비차단 훅 신설 → bump MINOR.
  - **신규 `hooks/harness-inbox-nudge.sh`** (비차단): `UserPromptSubmit`마다 inbox pending 스캔 → `additionalContext`로 "미처리 N건" 알림. **origin=harness-setup(dev clone)일 때만** 출력 — 글로벌 등록이라 모든 세션서 돌지만 제품/worktree 세션은 침묵(적용 불가 자리라 오인 방지).
  - **`session-check.sh`**: v3.8.0 §7(SessionStart inbox 넛지) **제거** — dev clone에 안 걸리는 죽은 자리였음. 주석으로 UserPromptSubmit·글로벌 등록 경로 명시.
  - **머신 셋업(repo 밖)**: 글로벌 `~/.claude/settings.json`에 `UserPromptSubmit` → `bash <dev-clone>/hooks/harness-inbox-nudge.sh` 1회 등록. README "회고 inbox" 절에 문서화. 크로스머신 비공유 한계 정직 명시.
  - **검증**: pending 0=침묵 / pending N=유효 JSON 알림 / gitlab origin=침묵 확인.

## 3.8.0 — 2026-06-19
- **회고 inbox 자동화 — check 드롭 / retro 드레인, 머신글로벌 transport (사용자 요청).** 실작업 세션(worktree)서 check가 후보를 만들면 적용 자리(harness-setup SSOT dev clone)와 다른 repo이라 지금껏 **수동 복붙**으로 날랐음. 게다가 worktree `.claude`=gitlab 제품 vendoring이라 harness-setup remote가 없어 거기선 적용·push 불가. 적용 게이트(사람 승인)는 불변 → transport만 자동화 → bump MINOR.
  - **`~/.claude/harness-retro-inbox/`** = 두 repo(harness-setup·gitlab 제품) 밖 중립 드롭박스. 같은 머신 모든 세션 공유.
  - **`harness-check/SKILL.md`** Step 2.5: 후보를 inbox 파일(`<UTC-ts>__<slug>.md`)로 **자동 드롭**(운반, 적용 아님). dev clone 세션이면 바로 `/harness-retro` 위임, 소비자 세션이면 드롭+안내까지.
  - **`harness-retro/SKILL.md`**: 무인자 호출 = **inbox 모드**(pending 스캔·드레인, 복붙 0). 적용 후 파일을 `applied/`·`rejected/`로 이동 → 상태 영속 + **원장 드리프트 해소**(딴 세션 로컬원장 draft ↔ dev backlog applied 단일 체인화).
  - **`session-check.sh`** §7: 세션 시작 시 inbox pending N건 넛지 — **dev clone(origin=harness-setup)에서만**(소비자 세션엔 적용 불가하니 오인 방지). 비차단 안내. (v3.9.0서 UserPromptSubmit로 이전·제거.)
  - **한계(정직)**: 크로스머신은 `~/.claude` 비공유 → 그 경우만 수동 복붙 폴백. 같은 머신 가정.

## 3.7.0 — 2026-06-19
- **커밋요청 시 사람 E2E 점검 안내 신설 — finalizer (사용자 요청).** 워크트리 병렬 진행 시 "이 변경에서 사람이 직접 봐야 할 게 뭔지"를 놓침. 커밋요청과 함께 **변경 표면 + 자동 커버 vs 사람 E2E 필요**를 짚어준다. 기존 게이트 판정로직 불변(비차단 통지 추가) → bump MINOR.
  - **`finalizer.md` `## 사람 E2E 점검 안내`**: 커밋 직전, **전체회귀 부채 안내와 동일한 비차단 단방향 통지**(출력 후 커밋 무조건 진행, AskUserQuestion·차단 금지). 변경 표면(워크트리/브랜치 식별 + `git diff --cached` 모듈 매핑 + feature 문서명) → 자동 커버(tester 변경검증 PASS) → 사람 E2E 필요(실기동 UI/통합) 단계형 점검표.
  - **항상 단계형**: `review/human-script.template.md`(옆집 아저씨) 구조 차용. oracle = feature 문서 요구사항(신규/고복잡도) / 원 요청(단순수정). 추출 못한 라우트·버튼은 `<...>` 정직 플레이스홀더(추측 금지). 민감값 평문 금지(scenarios.local.md 참조).
  - **근거**: CONTEXT.md `회귀 oracle 이원화`(자동 JUnit이 못 보는 실기동 UI/통합은 사람이 본다)의 풀사이클 적용 — 기존엔 리뷰모드에만 옆집아저씨 스크립트가 있었음.

## 3.6.0 — 2026-06-19
- **검증단계 디자인 폴리시 리뷰 — design-reviewer 서브에이전트 신설 (사용자 요청).** 목업 게이트(v3.5.0)는 구현 *전* 시각 확인만이라, 구현 *결과*의 미적 폴리시·목업 정합 QA가 비어 있었음. tester-frontend 영역3은 기능 UI QA(깨짐/WCAG/콘솔)뿐. 기존 게이트 판정로직 불변 → bump MINOR.
  - **신규 `agents/reviewer/design-reviewer.md`** (read-only: Read/Glob/Grep/Bash, Edit/Write 없음 → 물리적 소스 수정 불가, 커밋 안 함). tester-frontend PASS 후 **목업↔구현 드리프트 + 디자이너 시선 폴리시**(간격/위계/일관성/AI슬롭/느린 인터랙션) 리뷰 → 발견→developer-frontend.
  - **거버넌스**: gstack `/design-review` 스킬은 소스 자동수정+원자커밋(CHECKPOINT_MODE)이라 하네스 불변식(수정=developer, 커밋=finalizer) 충돌 → **fix-loop 안 쓰고 루브릭만 재사용**(SKILL.md Read). report-only 강제.
  - **범위**: 디자인 목업 게이트가 발동한 경우(UI+신규화면)만. 기존화면 소소수정은 tester-frontend 영역3로 충분(중복 금지 경계 명시).
  - `orchestrator.md`: Agent() 허용목록 + flow(300/302) + 라우팅표 + 목업 게이트 "검증단계 짝" 노트. `tester-frontend.md`: 영역3 범위 경계. drift 동기: `docs/routing-map.md`(검증측), `README.md`(mermaid DR 노드).

## 3.5.0 — 2026-06-19
- **설계단계 디자인 목업 게이트 신설 — gstack design-* 통합 (사용자 요청).** "설계에서 디자인도 포함, mock UI 만들어 실제로 보고 진행." 현 하네스는 계획 디자인 리뷰(design-panel UI 페르소나) + 기능 UI QA(tester-frontend)만 있고 **"어떻게 보일지" 시각 확인 부재**가 설계 약점이었음. 게이트 판정로직·거버넌스 불변식 불변(조건부 단계 추가) → bump MINOR(재시작 권장).
  - **새 게이트**: 설계패널 통과 후·사용자 승인 전, **`UI` 태그 + 신규화면/큰 레이아웃**일 때 `/design-shotgun`(변형 N + 비교보드, 사용자 택1) → `/design-html`(택1을 실 HTML로 마감) 파이프라인. orchestrator **직접 실행**(인터랙티브·사용자 대면이라 서브에이전트 위임 안 함).
  - **거버넌스 불변식**: 목업 = **승인 아티팩트(볼 용도), 산출물 아님**. standalone HTML(Pretext)이라 JSP 아님 → `developer-frontend`가 승인 목업을 시각 스펙으로 삼아 프로젝트 JSP/taglib/CSS로 **변환** 구현, 목업 마크업 제품 미커밋. 목업 산출은 머신로컬(`~/.gstack/...`)/scratch → bump·전체회귀 부채 무관. gstack 미설치/비대면 세션은 스킵 폴백.
  - **결정**: shotgun→html 파이프라인 + 트리거(UI+신규화면). design-review(verify-time, 소스 자동수정 = developer/finalizer 독점 거버넌스 충돌)·design-consultation(기존 엔터프라이즈앱 저fit)은 강제 체인서 제외.
  - `orchestrator.md`: `## 디자인 목업 게이트` 섹션 + 승인 게이트 목업 첨부 + flow(199/300/302) + 라우팅표. `planner-{frontend,high-complexity}.md`: `## 화면 규모` 명시(발동 판단). `developer-frontend.md`: 목업 JSP 변환 규칙.
  - drift 동기: `docs/routing-map.md`, `docs/playbook-design-mode.md`(설계모드 동일 시퀀스), `README.md`(mermaid MOCK 노드).
  - **동반 버그픽스(v3.4.0 후속)**: `orchestrator.md` frontmatter `Agent()` 허용목록에 **code-reviewer 누락** 수정 — v3.4.0서 신설했으나 허용목록 미등재로 orchestrator가 spawn 불가였음.

## 3.4.0 — 2026-06-19
- **/review 실행주체 부재 해소 — code-reviewer 서브에이전트 신설 (harness_pain 신호3, feature-10 세션).** orchestrator가 `/review ∥ /codex review` 병렬 시 claude `/review`를 위임할 수단이 없어(general-purpose/code-reviewer subagent_type 부재) 직접 코드대조로 우회하던 문제 — orchestrator 자기검토 = 가짜 2소스. 게이트 구조·불변식 변경 없음 → bump MINOR.
  - **신규 `agents/reviewer/code-reviewer.md`** (read-only: Read/Glob/Grep/Bash/Skill, 수정권한 없음). 개발을 안 본 fresh 컨텍스트에서 **기존 `/code-review` 스킬 재사용**(0에서 루브릭 신설 안 함) → codex(타모델)와 상관없는 독립 둘째 의견. 보안룰 SSOT(`claude-security-guidance.md`)·rule 경로 Read 주입. `--fix`/`--comment` 금지.
  - **결정**: 옵션 A 변형(스킬 재사용 + 서브에이전트 래퍼). B(orchestrator 인라인)·C(직접대조 공식화)는 독립성 약화로 기각.
  - `orchestrator.md`: 라우팅표 실행주체 명시 + `▸ /review 실행주체 (SSOT)` 권위 노트 신설 + flow 라인(고수준 요약·3트랙) + codex 미가용 폴백 문구를 전부 `/review(code-reviewer)`로 정정.
  - drift 동기: `docs/routing-map.md`(flow), `README.md`(mermaid REV 노드 + `agents/` 구조표에 reviewer 추가).
  - sync-skills 실행(글로벌 소스 미설치 → 미러 변경 0, critical diff 없음).

## 3.3.0 — 2026-06-19
- **harness_pain_2026-06-19 회고 4건 반영 — `/harness-check` 자가회고 → `/harness-retro` 적용.** 출처 세션(authpatch_draft feature-9) 운영 고통 4신호를 규칙으로 승격. 게이트구조·차단훅·거버넌스 불변식 변경 없음 → bump MINOR.
  - **[#1] RED craft 체크리스트 R5/R6** — `tester-design.md ## RED 보안/negative 테스트 규칙`: (R5) 단언·호출 대상 DTO/메서드는 작성 전 grep 실존확인(유사명 DTO 혼동 → 컴파일에러로 RED 무효 방어 — web `TokenResponse` vs shell `GitLabTokenResponse`). (R6) ArgumentCaptor는 verify() 전용, when()/given() 스텁에 captor 금지(captor-in-when = NPE/무의미 스텁).
  - **[#2] 변경검증 강화 + verdict 필수** — `tester-{backend,frontend}.md ## 핵심 규칙`: 변경검증 전체실행 금지(수십분/수백클래스 징후 = 스코프 미한정 의심 → 중단·재산정, 전체회귀는 tester-runtime 전담) + 판정 없이 종료 금지(PASS/FAIL/ESCALATION 필수). 근거: 신호2 — 42분 전체실행 + verdict 없이 종료 → 재spawn.
  - **[#3] codex TMP Windows 경로 gotcha 문서화** — 신규 `wiki/codex-tmp-windows-path.md`: gstack-paths TMP_ROOT가 `C:Users`(슬래시 누락)라 mktemp 실패 → /tmp 폴백 1회 재시도 지연. 벤더 수정 금지(sync 대기), 회피만. `wiki/index.md` 등록.
  - **[#4] planner 핵심 참조대상 실존확인 우선** — `planner/{backend,frontend,high-complexity}.md ## 탐색 규칙`: 계획이 의존하는 메서드/시그니처/시크릿/설정키는 '미확정' 방치 금지, 탐색한도 내 1파일 더 읽어 실존 확인(미확정 핵심항목 = 설계패널 critical 재발견). 근거: 신호4 — readSecret/stubUrl 미확정 방치 → 패널 critical 재발견.
  - sync-skills 실행(글로벌 소스 미설치 → 미러 변경 0, critical diff 없음). orchestrator.md 미변경 → 분리문서 정합성 점검 스킵.

## 3.2.0 — 2026-06-19
- **orchestrator.md 문서 분리 (비대화 해소 + drift 방지).** GPT 지적("orchestrator가 하는 일이 너무 많다")을 검토 → 실행 부하가 아니라 **프롬프트 부하**(885줄이 매 세션 시스템프롬프트로 로드 → 컨텍스트 세금 + 규칙 희석)가 문제로 판정. 에이전트 분리 불가(메인스레드 단일)이므로 **트리거-조건부 절차/시각자료를 on-demand playbook으로 분리**, 항상 쓰는 라우팅 뇌만 인라인 유지.
  - 신설 `docs/playbook-harness-ops.md`(기능스캔·회고반영·버전관리), `docs/playbook-design-mode.md`(설계모드·WI 게이트·템플릿), `docs/playbook-tdd.md`(TDD 7a~8 상세), `docs/routing-map.md`(전체 흐름 ASCII). orchestrator.md엔 트리거+요지+Read 지시 스텁만 남김.
  - `orchestrator.md`: codex 호출 가드 압축(기계강제 detail → 1블록, 실패신호·폴백 라우팅·백스톱은 인라인 유지). `## 분리 문서 (버전 동기 대상)` 매니페스트 신설(4파일 매핑 + drift 방지 규칙). 세션 경고 테이블·내부 참조 갱신.
  - **drift 방지 (사용자 요청)**: 분리 문서는 orchestrator.md와 한 몸. `finalizer.md ## 하네스 버전 bump 의식`에 **"분리 문서 정합성 점검"(1.5단계)** 추가 — orchestrator.md 라우팅/게이트/시퀀스/WI 템플릿 변경 시 대응 playbook 동기 여부를 기계 체크리스트로 대조, stale하면 자동커밋 금지·보고.
  - 라우팅 뇌(모드판정·0단계·3트랙·설계패널 게이트·승인·FAIL분기·codex 가드)는 **인라인 유지** — 추출 안 함(매 턴 필요 + 게이트 판정은 orchestrator-only). 거버넌스 불변식·게이트 구조 변경 없음 → bump MINOR.
  - **[감사 후속] 이식성 버그 수정**: Workflow `scriptPath`/`args` 경로의 하드코딩 절대경로 `C:/workspace/scourt/sb/.claude/...`(원저작 프로젝트 잔재 — 이 repo도 배포본도 아닌 제3 경로)를 **프로젝트 루트 기준 상대경로** `.claude/...`로 일반화(`orchestrator.md` 설계패널 + `playbook-harness-ops.md` 기능스캔). 다른 머신·프로젝트에서 Workflow 런치 실패하던 것 해소.
  - **[감사 후속] README 정합**: 구조표에 분리 동작문서(playbook-*·routing-map) 명시. bump 규칙에 "`docs/playbook-*`·`routing-map`은 순수문서 예외 = 동작문서라 bump 대상" 카브아웃 추가(v3.2.0 분리로 생긴 "docs만=bump아님" 모순 해소).

## 3.1.0 — 2026-06-18
- **하네스 운영 자가 회고 — `/harness-check` 스킬 신설.** 자기개선 루프 ③ 규칙화의 **입력을 자동 생성**: 사람이 회고를 가져오지 않아도, 하네스가 자기 운영 고통을 스스로 탐지해 `/harness-retro`에 먹인다. (사용자 요청: "하네스가 돌면서 겪은 실패·과다 루프를 스스로 회고해 개선사항을 사용자에게 승인 노티")
  - `skills/harness-check/SKILL.md`(repo SSOT): 운영 고통 신호 4종(과다 루프 LOOP≥2/3·게이트 escalation·출력/런타임 실패·설계 반려 반복) 수집 → 개선 후보 변환 → `/harness-retro` 위임 → 승인 노티. **탐지=자동, 적용=사람 승인**(불변식 유지).
  - 트리거: 워크플로 종료 시 자동(고통 감지) / 동일영역 failure_ 2건+ / "하네스 자가 점검" / session-check 넛지.
  - `orchestrator.md`: `## 하네스 운영 자가 회고 (post_commit 자가점검)` 절 신설(wiki capture와 같은 시점). 기존 `## 하네스 자가 점검`을 `/harness-check` 위임으로 재배선(옛 ad-hoc agent md 직접수정 경로 제거 → /harness-retro 분류·승인 게이트 경유). 경고 테이블 `미처리 실패 패턴` 행을 /harness-check로 갱신.
  - **dangling 해소**: session-check `⚠ 미처리 실패 패턴 N건 — /harness-check`가 가리키던 스킬이 v3.1.0 이전엔 실존하지 않았음(참조만). 이제 실존.
  - `versions.md`·`README.md`(자기개선 루프 표에 ③-입력 행) 갱신. bump MINOR(새 스킬 + 알림 규칙, 게이트 구조·불변식 변경 아님).

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
