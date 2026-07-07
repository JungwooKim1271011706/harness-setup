# 하네스 CHANGELOG

semver `MAJOR.MINOR.PATCH`. `VERSION` 파일이 SSOT. 최신이 위.
레벨 기준·bump 의식: `docs/harness-versioning.md`.

## 3.53.2 — 2026-07-07
- **README 상단 포트폴리오용 리라이트 — PATCH, 동작 불변.** 면접 공유 자료 목적. 내부자용 첫 문장 위에 평문 요약(무엇을·왜) + 게이트 4종(설계패널·TDD 작성자≠구현자·FAIL 3분기·자기개선 루프) + 주요 목적 4줄 추가. 기존 `## 워크플로 흐름`+mermaid는 유지(파고들 독자용). 비전문 면접관 10초 파악 + 엔지니어링 신호 보존 둘 다. 본문 내 현재버전 표기 동기화.

## 3.53.1 — 2026-07-07
- **흐름도(routing-map.md) 현행화 — 누락 게이트 2건 반영. PATCH, 동작 불변.**
  - `docs/routing-map.md` 다이어그램에 **0단계 ④ 데이터 전제 검증**(v3.53.0)·**office-hours 선제 게이트**(v3.51.0 C2) 반영. finalizer 1.5 정합점검이 grep 검색어 한계로 다이어그램 텍스트(`① 복잡도`)를 못 잡아 두 게이트가 흐름도에만 누락됐던 것 캐치업. orchestrator.md 본문·CHANGELOG엔 이미 반영돼 있었음(흐름도만 stale).

## 3.53.0 — 2026-07-06
- **데이터 전제 검증 게이트 신설 (inbox 드레인 repostitch) — MINOR, 거버넌스 무영향. 재시작 권장.**
  - **C1 `agents/orchestrator.md` 0단계 ④ 신설**: 픽스·구현 correctness가 외부·런타임 데이터(매니페스트 필드·repo config·API 응답·파일 내용·서버/브랜치 default)에 의존하면 planner·패널·TDD 진입 **전에** orchestrator가 실 샘플 ≥1개 직접 inspect(Read/git/grep)해 전제 확정. 확보 불가 시 `⚠ 미검증 전제` 명시. 직전 세션/investigate baked 전제도 무비판 계승 금지. 게이트(패널·TDD·리뷰)는 내부 정합성만 봐 외부 데이터 전제는 아무도 안 봄 → 전제 틀리면 전 게이트 통과 오진 shipped·라이브서 발각(1사이클 낭비). playbook-design-mode 0단계 요약 동기화. 근거: bb1f564(오진)→7ef9cb9(정식), 실 kit `defaultBranch=amd-test`(전제는 main).
  - reject: **C2 codex Bash timeout 재발** = orchestrator §codex 가드(v3.42.0)에 이미 명문화(`review ≥360000ms`). 회고는 여유 없이 `330000ms`(=내부 정확값)로 써서 밟음 — 규칙대로 360000이었으면 안 밟음. 규칙 갭 아님(소비자 stale 하네스 or 미준수). enforcement(훅)는 timeout param intent 검사 불가라 저효율. 관찰 7c.2 stale(자인 저레버리지, 게이트 정상작동) 제외.

## 3.52.0 — 2026-07-05
- **codex workspace-write 오펀 복구 뉘앙스 (inbox 드레인, 기존 통합) — MINOR, 거버넌스 무영향. 재시작 권장.**
  - **`wiki/codex-bash-direct-timeout.md` 회피 절 + sources 병합**: kill 후 복구 bullet 추가 — exit143 후 `tasklist | grep codex.exe` 생존 확인, **workspace-write(파일 편집 中) 오펀은 kill 금지(mid-write 손상 위험)·bounded 폴링 완주 + git diff 재리뷰**, read-only/probe 오펀은 정리 후 재실행. 근거: 07-05 authpatch_draft 7.5 workspace-write.
  - **`agents/orchestrator.md` §codex 호출 가드**: 방금 v3.51.0 C3 "오펀 정리(kill)"를 맥락 분기로 정교화 — read-only/probe=kill, workspace-write=kill 금지·폴링 완주·git diff. (v3.51.0 C3가 read-only 맥락만 상정했던 것 보정.)
  - reject: 신규 wiki 페이지 `codex-direct-exec-bash-timeout.md` 제안 = `codex-bash-direct-timeout.md`(v3.41.0)+orchestrator 가드(v3.42.0)와 동일 gotcha(중복) → 신규 페이지 대신 기존 통합(harness-retro Step2 원칙).

## 3.51.0 — 2026-07-05
- **재개 재작업 방지 게이트 + 프론트-백 REST 계약잠금 + codex 오펀 정리 (inbox 드레인 web-export) — MINOR, 거버넌스 무영향. 재시작 권장.**
  - **C2 `agents/orchestrator.md` §office-hours**: 선제 게이트 신설 — 새 기능·재개 시 office-hours 실행 전에 `docs/features/`에 관련 승인 feature 문서 있나 grep, 있으면 재office-hours 금지·그 SSOT부터 재개. session-check #8(v3.50.0)·decision-log(v3.48.0) 세션시작 surface의 하드 게이트 짝. 근거: web-export 07-05가 06-30 승인설계 모른 채 재office-hours→폐기.
  - **C4 `docs/playbook-tdd.md` 7c.3 + 7.5**: (7c.3) 프론트-백 REST 계약 sub-bullet — 라우트 URL↔프론트 api URL 대조 + DTO 필드명/JSON key를 동결 feature 문서 단일출처에서 양쪽 동일 잠금(각자 mock한 단위 GREEN이 실 HTTP 계약 미검증). (7.5) 테스트 인프라 임의 신규도입 금지·기존 통과 테스트 부트스트랩 복제(H2 임의도입 7.6 LOOP 유발). 근거: web-export 백30/프론트90 단위 GREEN인데 리뷰 계약 blocking 3건.
  - **C3 `agents/orchestrator.md` §codex 호출 가드**: Bash 직접호출 kill(exit 143) 시 detached codex 오펀 재실행 전 정리(taskkill/kill) 1줄. 기존 timeout 규칙(v3.42.0)에 오펀 정리만 보강.
  - reject: **C1 보안 SSOT 오배치** = v3.46.0서 헤더 projectName 런타임 가드 3소비지점(CSO_LENS·/cso·code-reviewer) 이미 배선(제안 (b) 정확히 그것). 파일 교체(a)=소비자-로컬(autoPatch 스택), dev SSOT 무대상. 관찰 developer 강제종료(외부요인) 제외.

## 3.50.0 — 2026-07-05
- **병렬 워크트리 기능 현황 표출: 세션시작 자동 surface + 교차 대시보드 (사용자 요청) — MINOR, 거버넌스 무영향. 재시작 권장(session-check 훅 갱신).**
  - **A `hooks/session-check.sh` #8**: 세션 시작 시 현재 워크트리의 활성 기능(`docs/features/` 중 `## 완료` 없는 in-progress 문서)을 1줄 surface — 기능명·단계(설계中/테스트설계됨/테스트中)·테스트케이스 수·미커밋 초안 여부. 완료본은 노이즈 배제로 침묵, dir 부재(dev clone) 시 무해 침묵. 데이터는 planner·tester-design이 이미 쌓은 feature 문서 재활용, 세션시작 자동표출만 신설.
  - **B `scripts/worktree-status.sh` 신규(읽기전용) + README `scripts/` 등록**: `git worktree list` × 각 워크트리 `docs/features/` 매핑 대시보드 — 워크트리별 활성 기능·단계·테스트 수·미커밋·완료 카운트. 사용자 "워크트리 현황" 질의 시 orchestrator가 온디맨드 실행. `scripts/` 신규 디렉터리(사용자 온디맨드 유틸).
  - **`agents/orchestrator.md` §작업 스코프 경계**: "병렬 워크트리 현황 파악" 절 추가 — A(세션시작 자동)·B(온디맨드 대시보드) 배선 문서화. 기존 데이터(feature 문서) 표출 강화지 신규 게이트 아님.
  - 배경: 사용자 병렬 워크트리 개발 시 "이 워크트리=이 기능=이 테스트" 매번 재파악하던 것을 자동화. 컨텍스트 보존 v3.48.0(승인결정 durable·TDD save)과 같은 "자동 surface" 계열. bump MINOR(session-check는 기등록 훅 인라인 갱신 — settings.json 무변경, 게이트구조·불변식 무변경).

## 3.49.0 — 2026-07-03
- **codex mojibake 라인병합 gotcha + 픽스처 배선/기본UI blind spot 2변종 (inbox 드레인 repostitch) — MINOR, 거버넌스 무영향. 재시작 권장.**
  - **C1 `wiki/codex-review-mojibake-line-merge.md` 신규 + index**: codex review(PowerShell Get-Content)가 한글/혼합인코딩 파일서 인접 라인 병합 렌더 → 정상 코드를 "주석처리"로 오독, 거짓 P1 blocking. 출력 mojibake(`3?몄옄??`)가 신호 → codex P1은 항상 디스크 직접 Read 인용라인 대조(receiving-code-review). python-shim(--json broken pipe)·tmp-path와 별개 렌더축. 근거: repostitch B1 normalizeGitlinkToBranchTip "주석처리" 거짓P1 3중 기각.
  - **C2 `docs/playbook-tdd.md` 7c.3 2변종**: (가) 전 홉 운반 bullet에 store 변종 흡수 — 테스트가 `store.X` 직접 주입하면 그 필드 producer 배선 공백이 GREEN에 숨음, 필드 producer 배선 존재를 별도 케이스로 잠금(근거: CC-2 store.importCfg.targetMeta→_buildCfg 직독→메타타겟 UI 공백). (나) 신규 bullet — 기본 UI 상태(default all-checked)가 픽스처보다 넓은 입력(단일→다중) 만들면 그 조합 트리거 분기를 케이스열거서 명시 probe(근거: B1 CB-MULTI-BRANCH 사후 회귀잠금). mock-hides-wiring(recurring #15) 변종 2종.

## 3.48.0 — 2026-07-03
- **컨텍스트 보존 강화: 승인결정 durable 기록 + TDD 합의완료 save지점 (사용자 요청) — MINOR, 거버넌스 무영향. 재시작 권장.**
  - **P1 `agents/orchestrator.md` §작업 컨텍스트 보존**: 사용자 설계 승인 직후 `gstack-decision-log`로 승인 설계(핵심선택+근거)를 durable decision에 기록 → 다음 세션 **시작 시** gstack Context Recovery가 `decisions.active.json` 자동 surface(수동 `/context-restore` 불요). 하네스가 여태 안 쓰던 자동복원 경로 배선. `--supersede`로 반전 처리, durable(아키텍처·스코프·반전)만.
  - **P2 `agents/orchestrator.md` §작업 컨텍스트 보존**: 자동 save 지점에 **TDD 합의 완료(7.7 PASS)→developer(8) 진입 전** 추가 — 승인 前 ↔ tester FAIL 사이 공백(합의된 RED 스위트+7c 합의가 최고가 미보존, GREEN 중 세션死 시 통째 재도출) 메움. save 컨텍스트에 7c 합의 diff+RED 파일목록+7.7 근거 포함.
  - routing 표 정합(context-save 시점 3개·decision-log 행 추가). 보류: P3(백그라운드 workflow 직전 save) — 413 복구절차가 부분 커버, 재발 시 재검토.

## 3.47.0 — 2026-07-03
- **캡처 단언 스코프 한정(R14) + 신규필드 전홉 운반 seam(7c.3) (inbox 드레인 repostitch) — MINOR, 거버넌스 무영향. 재시작 권장.**
  - **후보1 `agents/tester/tester-design.md` R14**: mock.calls 캡처 단언을 대상 스코프로 한정 — ①`.find`/`.filter` 캡처는 대상 판별 스코프(argv 인자값·`refs/tags/` 접두·repo URL) 필수(공유 mock의 무관 호출 포획 → 구현 정확해도 wrong-reason FAIL) ②`.not.toHaveBeenCalled()` 무인자 지양→`.not.toHaveBeenCalledWith(특정)` ③배열 조회는 `.some()` undefined-safe(`.find().not.toHaveProperty` crash 방지). 근거: repostitch T7-CASE/D-GATE/T7-FALSE/D-FE-3 4회 협소화 루프.
  - **후보2 `docs/playbook-tdd.md` 7c.3 sub-bullet**: 신규 필드/핸들러 추가 시 전 홉 운반 + deps 실주입 e2e 1케이스 — producer payload 화이트리스트·DTO 매핑이 신규필드 운반하나 + 신규 핸들러가 main.js registerHandlers deps에 실주입됐나. payload 우회·deps 직접 mock이 배선 seam 가려 dead-feature GREEN 통과→/review만 적발. config/배선 major는 7c.1 구현위치+grep 병행. 근거: repostitch WS1(payload 화이트리스트 gitlinkCarried/Sha drop)·WS2(main.js previewFf deps 미주입) 2 dead-feature.

## 3.46.0 — 2026-07-02
- **RED anti-pattern 3종 + tester-design 편집주체 + rule실존/보안SSOT 런타임가드 (inbox 드레인 Req2) — MINOR, 거버넌스 무영향. 재시작 권장.**
  - **C1 `agents/tester/tester-design.md` R11~R13**: 7.5 RED 반복 anti-pattern 3종 잠금 — R11 미구현 스텁(UOE throw) 대상 값-단언도 UOE 가드(R1 값-케이스 확장), R12 SUT 생성 타입기반 reflection(생성자 하드코딩 금지, seam 도달 보장), R13 실 static/fs 분기는 @TempDir+픽스처 준비(Mystery Guest·mutation 무력 방지). 근거: Req2 7.6 D1~D3·7.7 critical#1 REPLAY ZipUtil.
  - **C2 `agents/tester/tester-design.md` 편집주체 절 신설(PATCH)**: src/test/** 작성·수정 주체=tester-design(Edit/Write 보유, block-developer-test-edit 훅 대상 아님). 7.5/7.6/7.7/7c.2 마이그레이션 모두 실제 편집으로 수행 — "설계 전용이라 편집 거부" 라운드간 비일관 금지(재spawn 낭비 차단). 근거: Req2 7.7 LOOP2 편집거부 후 재지시.
  - **C3 `agents/orchestrator.md` 0단계 ③(MINOR)**: rule 경로 주입 전 Glob 실존 검증 게이트 — `.claude/rules/` 부재 시 조용한 no-op 대신 "rule 미생성·rule-maker 권장" 경고 + 주입 생략(코딩규칙 대조 silent 실패 차단). 근거: Req2 code-reviewer가 rules/ 부재 발견.
  - **C4 `agents/orchestrator.md` 보안 SSOT 주입부(MINOR)**: `.claude/claude-security-guidance.md` 주입 시(설계패널 CSO_LENS·/cso·code-reviewer 3소비지점) 문서 헤더 projectName ↔ 현 projectName 대조, 불일치면 제너릭 CWE 폴백+미현지화 경고. v3.43.0 setup-time 현지화의 런타임 백스톱(복사 후 재setup 안 한 케이스 자동포착). 근거: Req2 /cso·code-reviewer 둘 다 scourt 타스택 SSOT 지적.
  - reject: **C5 surefire @Nested** = 이미 커버(tester-backend line 61 변경검증 @Nested 명시 규칙 = 회고 제안 (a) 동일; (b) surefire 3.x는 제품 pom 변경 하네스 밖). **C6 한글 메시지 관례** = 프로젝트별 언어관례, 휴대 하네스 부적합(타언어 프로젝트 오적용) → 소비자 CONTEXT.md 권장, R7이 "메시지 verbatim 복사·추측 금지"로 근본 커버. 관찰 C7(gstack-paths Windows tmp) 벤더·저레버리지 제외.

## 3.45.0 — 2026-07-02
- **통합계약 갭 조기잠금 (7c.3 일반화 + tester-backend L1 조기) (inbox 드레인) — MINOR, 거버넌스 무영향. 재시작 권장.**
  - **A-1 `docs/playbook-tdd.md` 7c.3**: "정책/설정 런타임 배선" 불릿 일반화 → 변경 표면이 스프링 빈 배선(@Component/@Service)·설정 바인딩(@Value/@ConfigurationProperties)·auth 헤더·컨트롤러↔서비스 계약을 건드리면 ApplicationContext 로드+빈 등록/설정 non-null 주입/auth 전달을 **L1 통합 케이스 1건**으로 잠금. ⚠ config를 단위RED로 잠그는 7c.1 금지축과 구별(기동·실주입 자체를 통합레벨로 단언 = 별개 축).
  - **A-2 `agents/tester/tester-backend.md` L1**: 변경 표면이 배선/설정/auth/컨트롤러 계약을 건드리면 L1 컨텍스트 기동을 **변경검증 초반에 실행**, context 로드 테스트 부재를 "L1 공백"으로 넘기지 말고 통합계약 갭 신호로 7c.3 락 요구.
  - reject/reconcile: 원 회고 제안(A) "통합계약 락 최소 1건 RED 필수화"는 **7c.1과 정면 충돌**(config/배선 major를 단위RED로 잠그면 '미설정시 차단'만 검증돼 거짓GREEN — M7 allowedDeployRoot 근거). → 신규 규칙 대신 같은 결함클래스인 7c.3 정책/설정 배선 통합케이스를 일반화 + L1 조기화로 재조정. 관찰 2건(codex timeout124 기존커버·세션death 외부요인) YAGNI 제외.
  - 근거: DEVUNIT-authpatch extdep-phase1 checkpoint(2026-07-02) — 단위RED 스켈레톤 GREEN 후 변경검증 통합서 @Component누락·settings빈값·auth·계약불일치 다수 → LOOP 다회전.

## 3.44.0 — 2026-07-02
- **code-reviewer 사망 대칭 폴백 + codex heredoc 메타문자 gotcha (inbox 드레인 2파일) — MINOR, 거버넌스 무영향. 재시작 권장.**
  - **C2 `agents/orchestrator.md` codex 호출 가드 폴백 라우팅**: 기존 폴백은 codex사망→code-reviewer 단독 방향만 문서화 → 역방향(code-reviewer 세션한도 사망) 시 orchestrator가 즉흥 처리. **대칭 케이스 1줄 추가**: /review(code-reviewer) 산출 실패 → codex 단독 review + blocking findings 인용라인 orchestrator 직접 코드대조 1회 + 단일소스 태그(둘 다 불가면 orchestrator 직접 receiving-code-review). 근거: autopatch-cli-2 세션 실제 발생·즉흥.
  - **W1 `wiki/codex-bash-heredoc-metachar.md` 신규 + orchestrator §codex 호출 가드 1줄**: codex를 Bash 직접호출할 때 프롬프트에 셸 메타문자(백틱·`$`·`[]{}`) 있으면 double-quote 조기종료/명령치환으로 `EOF exit 2`(codex 호출조차 안 됨). single-quote heredoc 파일에 써서 `codex exec "$(cat "$PF")"`로 전달(리터럴 보존). [[codex-bash-direct-timeout]] 형제(별 축: 쿼팅 vs timeout). 근거: authpatch_draft TDD 7.7 1차 호출 EOF 에러.
  - reject: **C1 memoryDir stale** = 오진(memoryDir=auto-memory와 `.claude/agent-memory/`는 의도된 별개 두 시스템, 실패패턴 기록은 auto-memory가 정상) + 소비자 머신이동 드리프트(`/harness-setup` 재실행으로 해소, dev SSOT 무대상).

## 3.43.0 — 2026-07-01
- **보안 SSOT 현지화 단계 + finalizer E2E 콘솔 원자커플링 (inbox 드레인) — MINOR, 거버넌스 무영향. 재시작 권장.**
  - **후보1 `skills/harness-setup/SKILL.md`**: `claude-security-guidance.md`는 프로젝트별 보안룰(설계패널 `CSO_LENS`·`/cso`·`/review` 3곳이 SSOT로 Read)인데 harness-setup 재사용 시 원본(scourt 등) 그대로 딸려옴 → 현지화 안 하면 보안비평이 틀린 baseline 참조. Step5 다음단계 + 주의사항에 **보안 SSOT 현지화 체크** 추가(헤더 프로젝트명 불일치=미현지화 신호, 자동탐지 불가라 사람 수행).
  - **후보2 `agents/finalizer.md` 불변식**: 사람 E2E 콘솔 실행형 출력은 v3.35.0서 규칙화됐으나 **훅(check-finalizer-output)이 콘솔을 못 봄**(파일 앵커 부재) → "feature 문서만 append해 훅 통과 + 콘솔 실행형 스킵"이 훅 사각의 사일런트 위반으로 재발. 불변식에 **"콘솔↔문서 append는 원자적, 하나만 하고 스킵 금지, 훅은 문서만 검증(콘솔 사각)"** 명시.
  - reject(기적용): 후보2 ①콘솔필수(v3.35.0)·②복붙명령·③기대결과·④자동커버 라벨(line202) 전부 이미 존재 → 소비자 구버전 vendored 재발(git pull). 진짜 신규는 원자커플링 명시뿐.

## 3.42.0 — 2026-07-01
- **codex Bash 직접호출 timeout 규칙 + 설계패널 재게이트 초점 강화 (inbox 드레인) — MINOR, 거버넌스 무영향. 재시작 권장.**
  - **#1 `agents/orchestrator.md` codex 호출 가드**: v3.41.0서 wiki화(참조)한 codex-bash-timeout을 **행동 규칙으로 강제**. Bash 직접호출(probe·설계패널 형제·7b·review) 시 Bash `timeout` param을 codex 내부 이상(review ≥360000, consult/write ≥620000ms) 명시 — 미설정 시 기본 120s가 `exit 143` SIGTERM으로 run 낭비. probe만 짧게. 근거: 7.5 codex write 2분 조기사망 후 재실행.
  - **#2(c) `agents/orchestrator.md` 패널 재작업 루프**: 재게이트(LOOP≥1) workflow 입력에 **직전 critical + rework diff 명시** → 페르소나가 "해소됐나 + 새 결함 유발했나"에 집중. **재실행 범위·페르소나는 cold 전체 유지**(게이트 완결성 — 1회차 수정의 무관섹션 부작용 방지). 초점만 강화, 커버리지 불변. 근거: JAR관리 고복잡 LOOP2 신규 critical 2건이 1회차 수정 유발분.
  - **보류(적용 안 함)**: #2(a) 재게이트 스코프 축소·(b) eng 라운드 축소 = 게이트 커버리지 축소 → 수정 부작용 놓칠 회귀 위험(게이트 완결성 거버넌스 근접). backlog 기재.

## 3.41.0 — 2026-07-01
- **wiki gotcha 2종 (inbox 드레인, repostitch) — MINOR, 거버넌스 무영향. 재시작 권장.**
  - **`wiki/claude-rules-gitignore-local-only.md` 신규**: `.claude/rules/`는 양쪽 git서 gitignore(제품 repo `.claude/` + harness-setup `rules/`, 실측 `.gitignore:2`) → rule 파일 편집이 어느 git 이력에도 안 남음(로컬 전용). "편집=커밋" 착각 금지, `git check-ignore -v`가 SSOT. 공유할 규칙은 `CONTEXT.md`/`docs/`로. 하네스 구조 자체 함정 = 전 프로젝트 공통.
  - **`wiki/codex-bash-direct-timeout.md` 신규**: codex를 Bash 도구로 직접 호출(probe·설계패널 형제·7b·review) 시 Bash 기본 timeout 2분 < codex 실호출 2~9분 → `exit 143` SIGTERM. 내부 GNU `timeout`과 별개 레이어(짧은 쪽 승) → Bash `timeout` param ≥585000ms 명시. `/codex` 스킬 경유는 무관(스킬이 강제). codex-model-stall·python-shim과 링크.

## 3.40.0 — 2026-06-30
- **테스트 작성/sanity 커버리지 4종 보강 (inbox 드레인) — MINOR, 거버넌스 무영향. 재시작 권장.** export zip 아티팩트 세션: prod 무결, 발견 FAIL/critical 전부 테스트측 결함 → "작성 품질 게이트가 늦게/부분만 걸린다".
  - **C1 `tester-design.md` R9**: 격리/거부(negative) 케이스는 substring 부재(`forEach doesNotContain`, 공허)가 아니라 **금지산출물 count==0 + 허용산출물 positive** 쌍으로 잠금. R2의 격리/필터 구체화. 근거: WPR-15/17/18 7.7 critical 6건.
  - **C2 `playbook-tdd.md` 7.6 + `tester-frontend.md`**: 프론트 vitest RED sanity를 backend(`mvn test-compile`+RED) **대칭 게이트 단계로 격상**(tester-frontend 실행) — 7.7 직행 금지. + 모달/오버레이 spec 선점검 체크리스트(Teleport stub / 자식 onMounted api mock). 근거: teleport·ignoreApi 변경검증 2라운드.
  - **C3 `playbook-tdd.md` 7c.2**: 인벤토리에 **출력 위치/경로 이동의 read-side 소비자** 부류 추가 — 산출 파일을 읽는 테스트 헬퍼(파일 경로 read, 값 단언 아님 = 별개 seam) 전수 grep. 근거: flow2 리포트 경로이동→read 헬퍼 stale→변경검증 14 FAIL.
  - **C4 `tester-design.md` R10 (PATCH)**: 제어문자·개행 fixture는 Java 이스케이프(`\0`·`\r\n`), raw 바이트 금지(grep binary·javac fragile) + `tr -d` 검증. 근거: WPR raw NUL 적발 1회.
  - 관찰만(reject): 8a GREEN agent 세션한도 사망 = 외부 토큰요인, 디스크 산출 보존 재구성 성공 → YAGNI.

## 3.39.0 — 2026-06-30
- **receiving-code-review 게이트에 승인 계약 충돌 체크 + codex 주석오인 경고 (inbox 드레인) — MINOR, 거버넌스 무영향. 재시작 권장.** repostitch 위자드 UI 세션 회고 2건.
  - **`agents/orchestrator.md` (후보1, HIGH)**: findings 타당성 1차 게이트(①전제실재 ②이미막힘 ③YAGNI)에 **④ "승인된 RED 테스트·7c 합의·설계패널 승인 major와 충돌하면 기각"** 추가. 외부 리뷰 finding은 승인 계약보다 **하위 권위**(developer가 테스트 못 고치는 hook 불변식 정신). 충돌인데 테스트가 진짜 틀렸으면 DESIGN_MISMATCH로 사용자 재승인. 근거: 외부 aria-expanded "stale" finding이 승인 RED B-4와 충돌→적용→FAIL→환원 1라운드(커밋 7df3c98). ※ feature-scan #1(생산자 self-challenge)과 상보(주는쪽 자기반박 vs 받는쪽 계약대조).
  - **`docs/playbook-tdd.md` 7.7 (후보2, MEDIUM)**: codex 교차판정(claude 폴백) 호출 컨텍스트에 "trailing `// 설명` 주석과 주석처리된 실행라인 혼동 금지 — '주석처리됨' 주장 시 라인 인용 + `//` 시작 확인" 경고 주입. codex가 `// RED:` 설명주석 많은 파일서 live 단언을 'commented out' 오인→거짓 critical 양산(코드대조로 전부 기각됐으나 호출·검증 비용). 게이트(코드대조) 안전망 유지.
  - 관찰만(reject): developer-frontend API 끊김·code-reviewer 토큰사망 = 외부 1회성, 재투입 복구 + 부분완료 이어받기 정상 → YAGNI.

## 3.38.0 — 2026-06-29
- **Approach D 디버그 일지 분해 → wiki 2종 (inbox 드레인) — MINOR, 거버넌스 무영향. 재시작 권장.** autopatch 비대화형 CI export 복구 종합 stub(함정 6개 체인)을 통째 wiki化하면 앱 특정 내용이 오염 → 휴대 가능 2개만 추출.
  - **`wiki/spring-componentscan-basepackages-root-omission.md` 신규**: 명시 `@ComponentScan(basePackages)`는 `@SpringBootApplication` 기본 스캔을 **대체**(보강 아님) → 루트 패키지 누락 시 @Component 빈 조용히 미등록·`run()` 미호출(예외도 없음). 검증=ApplicationContext 통합테스트(리플렉션 단위테스트는 빈 등록 검증 못함). spring-profile·springshell과 상호링크(결함클래스 구분: 등록시점/실행순서/스캔범위).
  - **`wiki/powershell-set-content-utf8-bom.md` 신규**: PowerShell 5.1 `Set-Content -Encoding UTF8`이 BOM(`EF BB BF`) 붙임 → SnakeYAML 등 첫 키 못읽어 바인딩 null→엉뚱 분기. `WriteAllText(UTF8Encoding($false))`/`-Encoding ascii` 회피, `Format-Hex` 검증. jq-korean-encoding과 인코딩 함정 계열 링크.
  - **reject**: 함정4(키 분리)·5(config import 우선순위)=autopatch 특정 config 구조, 함정6(403 OAuth 비대화형)=미해결 설계과제 → 휴대 불가/하네스 무관. 원 stub이 sources로 보존돼 손실 없음.

## 3.37.0 — 2026-06-29
- **의사결정 위임 시나리오 형식 enforcement 강화 (inbox 드레인) — MINOR, 거버넌스 무영향. 재시작 권장.** `## 사용자 의사결정 요청 형식` 규칙은 완비인데 설계패널 major 위임 시 우회됨: ① 적용지점에 패널 critical만 있고 major 누락 ② 패널 severity/recommendation을 그대로 옵션표로 옮기는 anti-pattern 미명시 → redirect-uri fail-open major가 추상 A/B표로 나가 사용자 2회 "문맥 없어 결정 못함".
  - **`agents/orchestrator.md`**: 규칙 블록에 "패널/리뷰 findings severity·recommendation을 그대로 옵션표로 옮기지 말 것 → '어디서 깨지나+선택 후 흐름' 시나리오로 번역, 미번역 옵션표 제시 금지" 추가. 적용지점에 "설계패널 majors·design-reviewer findings 사용자 위임" 추가(critical 아닌 major도 형식 필수).
  - 후보1 enforcement 제안 중 **Stop/소프트 훅은 reject** — 의사결정 메시지는 콘솔 출력·파일 앵커 부재라 훅이 검증 불가(v3.35.0 finalizer E2E와 동일 한계, 거긴 feature 문서 파일로 우회). 프롬프트 강화로 해결.

## 3.36.0 — 2026-06-29
- **inbox 드레인 (authpatch 후보2 + springshell gotcha) — MINOR, 거버넌스 무영향. ⚠ 훅 로직 변경 → 세션 재시작 권장.**
  - **`hooks/block-orchestrator-exec.sh` (오탐 제거 + 우회 차단)**: command 전체 substring 매치라 `codex exec "...mvn package..."` 프롬프트 본문의 `mvn` 토큰까지 차단(인자≠실행 구분 못함). ① 인용부호 **문자만** 제거(`tr -d`, 내용 보존 — 셸과 동일 정규화) ② 매치를 **명령 위치**(문자열 시작 / 제어연산자 `; & | (` 직후)로 한정. 일반 공백(인자 구분)은 명령 위치 아님 → 프롬프트 인자 내부 `mvn` 오탐 제거. **차단 불변식 강화**: 무따옴표 `mvn`·`&& mvn`·`git commit`뿐 아니라 따옴표 우회(`"git" commit`·`m"v"n package`)도 차단(13케이스 검증). ⚠ 초안의 인용 '내용' 통째 strip은 `"git" commit→" commit"` denylist 우회 구멍 → 보안리뷰 지적 반영해 '문자만 제거 + 명령위치'로 교체. 근거: authpatch_draft 회고 후보2.
  - **`wiki/springshell-noninteractive-runner-order.md` 신규 + index + 역링크**: spring-shell 2.1.14 비대화형 배치(TTY 없음)서 셸 러너가 leftover 인자를 명령 해석→CommandNotFound. 커스텀 ApplicationRunner `@Order(HIGHEST_PRECEDENCE)`로 먼저 실행 보장(CLI 플래그 우회 불가). 결정적 테스트=`OrderUtils.getOrder` 단언. `spring-profile-bean-eval-timing`과 결함클래스 달라 별도. 근거: 커밋 b3626f8.
  - 후보1(tester pom clobber)은 v3.34.0서 기적용 → reject(소비자 구버전 vendored 재발, git pull 필요).

## 3.35.0 — 2026-06-28
- **사람 E2E 런북 강제 출력 (사용자 직접 요청) — MINOR, 거버넌스 무영향. ⚠ 훅 신규 배선 → 세션 재시작 필요.** "다른 세션에서도 E2E 점검 리스트가 안 떨어진다"는 실측 진단: finalizer.md 「사람 E2E 점검」은 v3.7.0부터 있으나 ① 출력 검증 훅 부재(SubagentStop은 planner-*만) ② "비차단"이 "생략 가능"으로 오독 → 구조적 누락. "신설"이 아니라 **기존 강화 + 실행 강제**로 해결.
  - **`finalizer.md` (A, 프롬프트 강화)**: 불변식에 "**출력은 필수 — 비차단은 멈춤만 면제, 생략 ≠ 비차단**" 명시. 절차4 런북 강화 — ⏱소요·🧰필요환경 머리표기 + [준비]/[빌드·실행 명령(CLAUDE.md Build&Run 인용)]/[화면확인] + 스텝별 ✅성공신호·**✗실패힌트**. 절차4.5 **feature 문서 `## 수동 E2E 검증` append**(콘솔+파일 이원). 출력 블록 형식 갱신.
  - **`hooks/check-finalizer-output.sh` 신규 + `settings.json` (B, 기계강제 경고)**: SubagentStop에 `finalizer` matcher 추가 — 커밋 직후 HEAD가 건드린 feature 문서에 `## 수동 E2E 검증` 없으면 경고 주입. **planner 훅(check-planner-output) 동형 경고모드**(`decision:block` 아님 — false-positive 신중, 안정화 후 차단 승격 검토). feature 문서 미변경(단순수정·하네스 자기수정)은 면제.
  - 후보1·2(tester pom clobber·빌드계약 디스크검증)는 v3.34.0서 기적용 — 이 재드롭 회고의 신규분은 후보3뿐.

## 3.34.0 — 2026-06-27
- **inbox 드레인 1파일 deploy-web-singleserve 회고 → 2 applied — MINOR, 거버넌스 무영향.** authpatch_draft 소비자 세션. tester pom 처리 데이터 소실 버그 + 빌드계약 디스크검증.
  - **`tester-backend.md` + `tester-runtime.md` + `orchestrator.md` (후보1, HIGH — 데이터 소실)**: tester 시작 자가치유 **`git checkout -- pom.xml` 무차별 원복 금지** — developer 미커밋 정당 변경(assembly 2분리)을 HEAD로 되돌려 소실 → 삭제된 distribution.xml 참조 → **거짓 BUILD FAILURE 2회**. 실행블록을 if/else로: harnessbak 있으면 복원, 없으면 skipTests 줄만 sed 원복. 불변식 "tester는 미커밋 product 변경(pom 포함) 절대 소실 안 함" 명시. trap의 harnessbak 원복은 그대로(안전).
  - **`orchestrator.md` + `developer-backend.md` (후보2, MED)**: claimed-but-not-applied 디스크검증을 **빌드계약(pom/assembly/descriptor)으로 확장**(v3.32.0 test파일 대상 → build파일 동급). developer는 `mvn package` 금지라 compile 자가확인이 assembly 영향을 못 잡음 → GREEN 보고에 "package/assembly 미검증" 플래그 의무 + 변경검증서 실 package 1회. 근거: pom assembly 거짓보고를 /review 디스크검증이 적발(1라운드).

## 3.33.0 — 2026-06-27
- **inbox 드레인 1파일 PR-F3 회고 → A 신규 + B/C/D 흡수 — MINOR, 거버넌스 무영향.** DEVUNIT-repostitch PR-F3 post-commit 자가회고. 직전 v3.32.0(PR-F2)과 같은 계열 → B/C/D는 기존 절 1줄 흡수(새 부류·페이지 X), A만 신규 영역.
  - **`orchestrator.md` 위임 규칙 (A, 신규)**: **상호의존 작업 병렬위임 금지**. Agent 동시발사 전 "한쪽 산출이 다른쪽 입력 가정을 바꾸나?" 자가체크 — 바꾸면 순차. 구현 계약 변경 ↔ 픽스처/테스트 모사는 상호의존(구현 먼저 확정→접점 SSOT→픽스처 정합). 파일 비충돌 ≠ 의미 독립. 근거: developer(judgeFf `-C tmpDir`) ∥ tester-design(`-C` 없음) 동시발사 → 변경검증 8→57 FAIL 폭증.
  - **`playbook-tdd.md` 7c.2 (B, 흡수)**: "신규 의존 edge" 부류에 — 신규 함수뿐 아니라 **기존 공유 mock(`makeRunner`)이 미stub한 새 서브명령/argv**(`merge-base`·`.code` 분기)도 같은 축. 공유 mock 쓰는 전 케이스 grep해 단일 passthrough 헬퍼로 일괄 보강. 근거: PR-F3 48 케이스 'diverged' 오판 한 라운드 통째 FAIL.
  - **`playbook-tdd.md` 7c.3 (C, 흡수)**: "양끝 동일 단언"에 — 반환 shape뿐 아니라 **입력 형태도 production형 그대로** 주입(테스트 편의형 금지). producer 계약 테스트(`shortName` 생산)가 있으면 consumer도 같은 형태 e2e 1케이스. 근거: PR-F3 renderer `shortName` ↔ 테스트 전부 `fullRef` 주입 → 재조립 분기 미실행, branch선택 import 전멸 버그를 /review가 적발(TDD 미탐).
  - **`tester-design.md` 핵심규칙 (D, 흡수)**: ① 대상 src 실제 argv를 **Read 후 모사**(추정 금지, 모호하면 미확정) ② **통과 주장 금지**(Bash 없음 — 패턴 정합 grep 자가증명만). 근거: PR-F3 tester-design 4회 추정오판 + Bash 없는데 "통과" 주장.

## 3.32.0 — 2026-06-27
- **inbox 드레인 4파일 → 4 applied — MINOR, 거버넌스 무영향.** DEVUNIT-repostitch PR-S2/F2 소비자 세션 4회고. 전부 누적 재발(YAGNI 아님). A/C/D = recurring-test-lessons #2/#3 "mock이 실 계약 우회"의 세 단면.
  - **`playbook-tdd.md` 7c.2 (A)**: stale 인벤토리가 격상(v3.21/3.30) 후에도 재재발(누적 9~10회). ① **matcher 시맨틱 박스** — `toEqual`·`toContainEqual`·객체리터럴=exact key-count(가산필드 깸), `toMatchObject`·`objectContaining`=subset(안 깸). 기존 글이 `toMatchObject`를 exact로 오기재했던 것 수정(planner 6회 오판 뿌리). ② **"교차파일+multi-entry" 부류 신설** — 변경 테스트 파일 밖 전 트리 grep + 여러 항목 중 일부만 거동변경 트리거하는 케이스(multi-sub). 근거: PR-S2 cross-file `toContainEqual`·PR-F2 D3-19.
  - **`playbook-tdd.md` 7c.4 신설 + `tester-design.md` + `developer-backend.md` (C)**: **plan 신규/변경 헬퍼 시그니처 = 픽스처 단언 SSOT**. 메서드 종류(`run`=PAT 인증 vs `runPlain`=비인증)·인자순서·플래그·URL·반환shape를 plan에 정확히 잠근다. 픽스처가 plan과 갈리면 plan이 이긴다(developer가 틀린 픽스처에 수렴 방지). 보안·런타임 임팩트 메서드 선택 특히 고정. 근거: PR-F2 fetch를 `runPlain`서 캡처→PAT 미주입 기존 branch 서브모듈 거짓거부 잠재버그(9-FAIL+2소스+receiving-code-review 3중 적발).
  - **`tester-design.md` + `orchestrator.md` (D)**: **claimed-but-not-applied(디스크 미반영) 차단** — tester-design 산출 말미에 변경 핵심 1~2개 `grep -n` 자가증명 의무 + orchestrator는 테스트파일 편집 위임 후 다음 단계 진입 전 Grep로 디스크 확인. 근거: PR-F2 픽스처 미반영·PR-C2 파일부재 2회(3+회 재발). grep 1회 << 변경검증 1라운드.
  - **`wiki/jsdom-missing-browser-apis.md` 신규 (B)**: renderer가 jsdom 미구현 브라우저 전역(`CSS.escape`·`matchMedia` 등)→프로덕션 OK·단위테스트 TypeError 전수 폭발(PR-S2 63 FAIL). 환경 가드 헬퍼 회피책 + 일반화. index 등록.

## 3.31.0 — 2026-06-25
- **inbox 드레인 4파일 9후보 → 5 applied / 4 rejected·fold — MINOR, 거버넌스 무영향.** DEVUNIT-authpatch_draft 소비자 세션 4회고. TDD 케이스설계·변경검증·설계라우팅 게이트 보강. 새 wiki 페이지 없음(전부 기존 규칙 흡수·확장).
  - **`tester-quality.md` 기준9① (#1)**: 형제 RED 케이스가 **같은 산출물(파일/리스트)에 존재 vs 부재를 상충 단언**하는 모순도 점검(둘 다 GREEN 불가→8 GREEN서 DESIGN_MISMATCH). 근거: IGN-INT-04 exists ↔ 06c doesNotExist.
  - **`playbook-tdd.md` 7c.3 (#2)**: 트리거에 **백엔드 DTO→프론트 소비필드**·**정책/설정→런타임 실배선**(`empty()`/no-op 아님) 추가 + 강제체크 2 bullet. 단위 GREEN이 우회한 교차레이어 계약을 RED로 선잠금. 근거: F1 ExportModule empty 고정·F2 toDto rules null(review 적발 CRITICAL 2).
  - **`playbook-tdd.md` 7c.2 (#7)**: 인벤토리에 **"시그니처/위임 전환"** 부류 신설 — 생성자/메서드 시그니처 변경 호출처 grep + 위임 전환 시 사라지는 부가책임 보존 인벤토리. 근거: 생성자 stale 마이그레이션 + resolveTargetFiles JAR확장 책임소실 blocking.
  - **`tester-backend.md` 영역2 + `orchestrator.md` (#3)**: 변경검증 보고에 **지시 클래스 vs surefire 실행 클래스 대조표**(누락 시 PASS 불가) + orchestrator는 회귀 스코프를 명시 클래스 목록으로 위임. 근거: inclusive-from "61/0/0 PASS"인데 3클래스 미실행→stale 8건 후행.
  - **`orchestrator.md` grill-with-docs (#5)**: 건너뛰는 조건에 ⚠예외 — config 토글/빈 등록/토글 인접 변경이면 "설계 명확"이어도 grill 강제(중복 메커니즘 적발). 근거: deploy-target ↔ 기존 `autopatch.shell.mode` 중복+상충 planner 1차 적발.
  - **기각/통합**: #6(검증자 전체집합, receiving-code-review가 이미 잡음 YAGNI)·#4(크로스-repo, 다repo 한정 1회)·#8(#7에 fold)·D1(@Nested, SSOT 기적용).

## 3.30.2 — 2026-06-25
- **inbox 드레인 2건 (wiki gotcha 짝 — DB 네이밍 drift) — PATCH, 거버넌스 무영향.** authpatch_draft DB 네이밍 drift 풀사이클(commit 42d77a7e)서 발견된 짝 gotcha. 상호 링크 + `spring-profile-bean-eval-timing` 연결.
  - **`wiki/hibernate-naming-strategy-explicit-name.md`**: Spring 기본 `SpringPhysicalNamingStrategy`는 **명시 `@Column/@Table(name=...)` 이름마저** camelCase→snake 변환(Hibernate 순정 `PhysicalNamingStrategyStandardImpl`은 통과시킴 — 설계패널도 혼동). 수동 DDL이 camelCase면 신규설치 `SQL 1364`. 회피=DDL을 snake 출력과 글자단위 일치 + strategy yml 박제 + 라이브는 information_schema 직접조회 확정.
  - **`wiki/information-schema-table-name-ci-collation.md`**: `information_schema.STATISTICS.TABLE_NAME`은 컬럼 collation(기본 `utf8_general_ci`)이 ci → `'Users'`가 snake `users`에 매칭(LCTN=0이어도). 양날: 오타 거짓통과 + "통과=Pascal 테이블" 잘못 추론(설계패널 거짓 critical). 회피=리터럴 snake 일치/`LOWER()` + 이름뿐 아닌 속성(`NON_UNIQUE=0`)까지 단언. index 등록.

## 3.30.1 — 2026-06-24
- **inbox 드레인 1건 (wiki gotcha) — PATCH, 거버넌스 무영향.** `wiki/device-guard-blocks-jdk-javac.md` 신설: Windows Device Guard(WDAC)가 서명 안 된 OpenJDK javac.exe 실행을 차단 → maven fork 컴파일(`<fork>true</fork>` + `${jdk-1.8-home}/bin/javac`)이 `.java` 에러 본문 0줄로 무음 실패. fork stderr 삼킴으로 오인하기 쉬움(실제론 javac 起動 자체 실패). 진단: cmd서 `"<jdk>\bin\javac.exe" -version` 직접 실행(MSYS는 Permission denied로 오인). 회피: 통과 JDK로 `-Djdk-1.8-home` 오버라이드(영구=빌드코드 주입 91bacbd0). authpatch_draft 소비자 세션 발견. index 등록.

## 3.30.0 — 2026-06-24
- **inbox 드레인 1건 (repostitch PR-F1) — MINOR, 거버넌스 무영향. stale 인벤토리 불완전 6회째 근본 격상.**
  - **(누적 6회) 7c.2를 "단순 grep" → "계약 파급 양면 분석"으로 격상 + 값-생성 픽스처 4번째 축**: PR-F1(enum `BRANCH_EXISTS`→`FF_PENDING`)에서 7c.2가 `BRANCH_EXISTS` 문자열 grep으로 detect 21건 마이그레이션했으나, `branchExists:true` **픽스처로 충돌 유발**하고 `conflicts` 카운트·rename 입력만 간접 단언한 3건(D4-DT-3/4, B1-6)을 놓침 → 변경검증 재FAIL 1라운드. 공통 뿌리 = **단언측(바뀐 값 문자열) 1축만 보고 생성측(그 값을 유발하는 입력 픽스처) 안 봄**. `playbook-tdd.md` 7c.2 intro에 양면 원칙(①값 단언 테스트 + ②값 생성/유발 입력 픽스처·seam·edge 둘 다 grep) 명문화 + 4번째 축 "값-생성 픽스처/트리거"(`grep "branchExists:\s*true"` 식 입력측 grep) 추가. 부류=닫힌 목록 아닌 양면 원칙의 사례로 재framing. 재발 누적: failure_06-15 → PR-D1 → 0621 cross-test → PR-F0 가산필드 → PR-S1 mock 팩토리 → PR-F1 픽스처.

## 3.29.0 — 2026-06-24
- **inbox 드레인 4건 (Vue 세션 3 + repostitch IPC 1) — MINOR, 거버넌스 무영향.**
  - **#1 (HIGH) tester-frontend UI 렌더버그 false PASS**: 대시보드 "차트 안 나옴" 수정에서 첫 tester-frontend가 vue-tsc exit0 + vitest 12 PASS로 **PASS** 줬으나 차트 실제 미렌더(canvas client=300x150·style NONE = `new Chart()` 미실행) → 사용자 재보고 + 수동 브라우저 조사 1라운드 낭비. 검증 oracle이 화면결과 아닌 코드구조였음. `tester-frontend.md` 핵심규칙에 **렌더 영향 변경은 실브라우저 렌더 실측 없이 PASS 금지**(요소 painted/canvas 비-0 크기) + **렌더 미검증을 PASS로 위장 금지**(인증·환경 제약 시 ESCALATION으로 실측 위임, "부분확인" 약표기 PASS 금지). `orchestrator.md` 라우팅에 렌더버그 정적 PASS 종결 금지 룰.
  - **#2 wiki gotcha `vite-stale-served-source-windows`**: Windows Vite dev server 워처가 편집 miss → stale transform 서빙. 디스크≠서빙. `curl localhost:PORT/src/...`로 서빙 소스 확인 후 재시작.
  - **#3 wiki gotcha `vue-immediate-watch-template-ref`**: `watch(...,{immediate:true})`가 mount 전 동기 실행 → template ref null → 차트 조용히 미렌더. flush:'post'로도 안 고쳐짐. 첫 렌더는 `onMounted(renderChart)`. (#1 버그의 근인, #2와 한 묶음.)
  - **#4 (누적) IPC 경계 반환 shape 계약 — 7c.3 신설**: repostitch PR-S1에서 핸들러가 `{ok,branches}` wrapper 반환, 소비부는 raw array 기대. 단위테스트가 api를 string[]로 직접 mock해 shape 불일치 **우회** → GREEN 거짓통과 → /review 적발. 7c.2(stale 기존테스트·mock 팩토리 함수목록)와 **다른 축**(신규 계약 producer↔consumer shape 일치). `playbook-tdd.md` 7c.3 신설 — **양끝 동일 단언 또는 실 핸들러 반환 계약테스트 1건** 강제. planner-{frontend,backend}에 IPC 반환 shape 양끝 명시 룰. 근거: PR-S1 + PR-D2/D4 payload 필드누락 + 실버그 bc303a7.

## 3.28.0 — 2026-06-22
- **repostitch PR-S1 자가점검 2건 (inbox 드레인) — MINOR, 거버넌스 무영향.**
  - **#1 (중·누적) 7c.2 stale 인벤토리에 "신규 의존 edge" 부류 추가**: 변경 모듈이 새 외부함수(`api.searchBranches` 등)를 호출하면 그 모듈을 mock한 기존 테스트 팩토리가 신규함수 미정의로 무더기 FAIL(PR-S1 9건 — undefined 호출 TypeError). 반환shape도 값도 안 바뀌고 호출 edge만 추가돼 기존 2부류(가산/동작계약) grep엔 안 걸리는 별개 축. `playbook-tdd.md` 7c.2를 "두 부류 → 세 부류"로 확장(신규 의존 시 mock 팩토리 grep→stub 일괄 마이그레이션). 테스트 인벤토리 불완전 테마 4번째.
  - **#2 tester codex 거짓보고 "고쳐도 재발" 근본수정 (관찰 격상)**: v3.17.0(규칙)·v3.19.0(소프트룰 "메모리 비신뢰")이 **둘 다 재발**. 원인 = 소비자 per-agent 메모리 "항상 폴백"이 in-context서 소프트룰 이김 + self-probe 탈출구가 메모리 유입구. **메커니즘 수정 = tester 가용성 판단 surface 제거**: 가용성=orchestrator 단독권한(tester self-probe·판단 0), self-probe 탈출구 제거(미주입 시 NEEDS_CONTEXT), tester "폴백" 출력 금지(raw 결과·실패신호만), orchestrator 주입 의무. `tester-{backend,frontend}.md` + `orchestrator.md ### 가용성 확정` + `wiki/agent-memory-overrides-rule.md`(3차 회피·교훈 격상). 교훈: 소프트룰 반복 패배 재발클래스는 "모델에게 X 믿지마"가 아니라 **판단 surface 제거**.
  - **관찰 reject**: API 529 Overloaded = Anthropic 외부 1회성.

## 3.27.0 — 2026-06-22
- **사용자 의사결정 요청 = 시나리오 기반 형식 강제 — MINOR, 거버넌스 무영향.** 사용자 요청. 추상 옵션표(시맨틱·결과 칼럼)만으론 사용자가 결정 불가 → planner 유저 시나리오 비교 템플릿(기존/신규 시나리오 단계별, 변경부 굵게)을 베이스로 옵션을 각각 완결된 신규 시나리오 흐름으로 제시.
  - `orchestrator.md` 신설 `## 사용자 의사결정 요청 형식`: 기존 시나리오(⚠ 깨지는 단계 명시) + 신규 시나리오 A/B(옵션별 완결 흐름, 변경부 굵게, 권장 표기) + 결정 요청. 옵션은 추상 시맨틱 아닌 **시나리오 결과로** 서술 강제.
  - 적용: 동작/설계 변경 결정 필수(순수 취향은 경량). 적용 지점 = 설계패널 생존/모순 critical 에스컬레이션, 7c 상호배타, FAIL 3분기, 3루프 ESCALATION 등 모든 사용자 판단 위임. 핵심 위임 지점(모순 critical·3루프 위임)에 형식 cross-ref.

## 3.26.0 — 2026-06-22
- **authpatch_draft 자가점검 3건 (inbox 드레인) — MINOR, 거버넌스 무영향.** 삭제 라이프사이클 통합(고복잡도) 소비자 세션 `/harness-check` 자동드롭 처리.
  - **#1 (HIGH) codex probe false-positive**: smoke `ping`은 exit0 빠르게 통과하나 실프롬프트(7b consult·review)는 모델 API stall로 exit124 hang → TDD+리뷰 단일소스 격하 + probe 미탐지로 20분 낭비. `orchestrator.md ### 가용성 확정`의 probe를 초소형 ping → **대표 프롬프트 + `timeout 60` 하드캡**으로 강화, probe 타임아웃(exit124)도 불가로 간주(smoke exit0만으로 가용 단정 금지). `wiki/codex-model-stall-windows.md` 신설(--json shim broken pipe와 별개 = 모델 stall). 학습기반 probe 스킵(①)은 false-skip 위험으로 기각.
  - **#2 (HIGH) greenfield 7.6 RED sanity 갭**: 신설 클래스(prod 미존재)는 RED가 GREEN 전 컴파일 불가 → 7.6 선검증 구조적 불가 → setup 결함이 병합 후 tester-backend서 라운드당 1건씩 노출(6+회전). `playbook-tdd.md` 7.6에 greenfield 2단계 명문화 — **developer가 GREEN 전 최소 prod stub(시그니처만, benign 반환·throw 금지) 생성 → 7.6 → GREEN**(작성자≠구현자 유지, 7c freeze 시그니처 사용).
  - **#3 (MED) config/배선 major RED 갭**: 7c.1 일률 'major→RED 1개'가 단위검증 불가 major(allowedDeployRoot 전사·bean wiring 등)엔 부적합 → developer가 주석만 달고 미구현해도 RED PASS → GREEN 후 /review P1 적발. `playbook-tdd.md` 7c.1에 **major 유형 분기**(단위가능=RED락 / config·배선·통합=구현위치 명시+/review 체크리스트, 7.7 critical 취급 제외).
  - **관찰 reject**: 토큰 한도 서브에이전트 mid-run 사망 = 외부요인(레버리지 작음).

## 3.25.0 — 2026-06-22
- **백그라운드 패널 세션끊김 복구 절차 추가 (inbox 드레인 1건) — MINOR, 거버넌스 무영향.** repostitch 소비자 세션 inbox(`/harness-check` 자동 드롭) 처리. 설계패널을 백그라운드 Workflow로 띄운 직후 세션이 끊기면 재개 세션에서 산출 수령/완주판정 절차가 부재했음(`resumeFromRunId`는 same-session 캐시라 세션 죽으면 무의미).
  - `orchestrator.md` §설계 패널 게이트에 `### 세션 끊김 후 복구 (백그라운드 패널)` 신설: journal `completed` 확인 → 부분완주는 재실행(기존 0번 완전성 검사 정신) → 필수 페르소나(eng·cso) 누락 시 StructuredOutput 추출 우회 금지 → codex 형제도 동일 끊김 폴백.
  - **관찰 2건 reject**: 패널 LOOP 2/3은 정당한 안전검증(하네스 결함 아님), 세션 끊김은 외부요인(토큰 한도) — 규칙화 안 함.

## 3.24.0 — 2026-06-21
- **tester maven 호출에 폭주 테스트 fail-fast 타임아웃 강제 — MINOR, 거버넌스 무영향.** JDK 메모리 미반환 진단 세션 발. 무한루프 테스트(제품 버그)가 surefire 포크 JVM을 수 GB·GC 죽음나선으로 무한 점유 → 머신 메모리 90% 도달. 타임아웃 없으면 fail-fast 안 됨. tester 스코프가드("수백 클래스면 중단")는 단일 테스트 무한루프를 못 잡음(폭주 1개 ≠ 수백).
  - `tester-backend.md` (단위/변경검증): mvn에 `-Dsurefire.timeout=600`(per-fork 백스톱) + `-Djunit.jupiter.execution.timeout.default=120s`(Jupiter per-test, JUnit4면 무시) 추가 + ## 핵심 규칙 설명.
  - `tester-runtime.md` (전체회귀): `-Dsurefire.timeout=1800`(per-fork 30분)만. 정당한 느린 통합테스트 오탐 막으려 Jupiter per-test 미사용. 정상 스위트 30분 초과 시 상향.
  - 힙 캡(-Xmx)은 강제 안 함(프로젝트 argLine 덮을 위험; 폭주 힙은 루프 증상이라 타임아웃 종료 시 회수).
  - surefire가 포크 종료 → 부모 maven BUILD FAILURE 정상 종료 → trap이 pom 원복(고아·잔재 없음).
  - `wiki/surefire-runaway-test-timeout.md` 신설(증상·원인·회피·jps/jstack 응급대응) + index 등록. 제품 버그(MetaCommitRangeSelector.handleBranchSwitch 무한루프)는 제품 담당 세션 위임(하네스는 머신 보호만 책임).

## 3.23.0 — 2026-06-21
- **설계패널 게이트에 codex 형제(cross-model 플랜비평) 추가 — MINOR, 가산·폴백안전.** 구현은 `/review ∥ /codex review`로 교차검증하면서 설계는 claude 단일모델이던 비대칭을 메움(CONTEXT.md "반복≠신뢰": claude→codex=종류 다름=정보 증가). 코드단계 union 패턴의 설계단계 대칭 복제.
  - `orchestrator.md ### codex 형제` 신설: 패널 Workflow와 **병렬**로 `/codex` consult 모드 1회 호출(review 아님=diff 없음, challenge 아님=코드 대상). 프롬프트=패널 reviewPrompt 동형(rulePaths Read+준수, planText, severity+location+quote+recommendation, quote 못 달면 confidence 강등). 보안렌즈는 cso 페르소나가 SSOT라 codex엔 아키텍처·정합·엣지케이스 렌즈 명시.
  - **페르소나 아님 (인원규칙 불변)**: codex는 floor=3 인원·passEvidence≥2(claude lazy-PASS 가드)에 미포함. 패널 구성(최소3/최대4 연관기반) 그대로. codex=패널 옆 독립 cross-source.
  - **게이트 합류=합집합**: codex findings는 패널 findings와 같은 dedup+코드대조 게이트로. codex critical도 dedup→인용라인 코드대조→생존 시 차단, **단독 생존도 차단**(코드단계 "blocking 1건이라도 처리, 취사선택 금지" 동형). major/minor도 합쳐 동일 처리.
  - **폴백**(§codex 호출 가드 신호): codex 죽으면 패널(claude)만 게이트 진행 + `⚠ 교차검증 없음(codex 미사용, 단일소스)` 태그, 재시도 1회. 패널 정상이므로 비차단(코드단계 /codex review 폴백 동형). 기계강제는 /codex 스킬 담당(orchestrator 재지시 안 함).
  - **design-panel.js 미변경** — sibling이라 워크플로 안 안 건드림. `## codex 호출 가드` 진입점 5곳→6곳, 폴백 라우팅·라우팅표·routing-map.md·playbook-design-mode.md(설계모드 상속)·3트랙 one-liner 동기.

## 3.22.0 — 2026-06-21
- **DESIGN_MISMATCH 예외 재분류 (드리프트 환원) — MINOR, 거버넌스 무영향.** repostitch 로컬에만 있던 휴대용 개선을 SSOT로 환원(소비자서 push하면 프로젝트 전용 보안룰이 딸려가므로 dev clone서 정식 반영).
  - `orchestrator.md` FAIL 분기 + FAIL 3분기 처리표: 기존 테스트 깨짐의 원인이 '설계 SSOT가 이미 승인한 **스키마·동작계약 변경**'(7c.2 인벤토리 대상)이면 DESIGN_MISMATCH 아님 → stale-test 마이그레이션(tester-design 위임, planner 재게이트·재승인 불요). 설계 미승인 구조 충돌만 정상 DESIGN_MISMATCH. v3.21.0 7c.2 인벤토리와 짝(stale 발견 시 잘못된 planner 재게이트 루프 차단).

## 3.21.0 — 2026-06-21
- **repostitch 고복잡도 풀사이클 회고 4건 — #1·2a·2b·3 적용 / #4 무변경. MINOR, 거버넌스 무영향.** inbox 드레인(소비자 v3.15.0 구버전).
  - ⚠ **드리프트 환원**: 소비자엔 `7c.1 스키마/계약 인벤토리`가 있으나 SSOT엔 부재였음(로컬 드리프트) → 포팅 + 확장.
  - **#1 (포팅+확장)** `playbook-tdd.md` 신규 **7c.2** — stale-test 영향 인벤토리. 가산 변경(필드추가)뿐 아니라 **동작계약 변경**(severity 규칙·타임아웃 등 상수·early-return)도 그 값/규칙 단언 기존테스트 전수 grep + tester-design 일괄 마이그레이션. 근거: E7-04 severity 격상·git-runner 600s 상수가 변경검증/리뷰서야 발견.
  - **#2a** `tester-quality.md` 기준9 ④ — 신규 describe 격리(beforeEach clearAllMocks·DOM reset) 정합 점검 추가(격리 PASS·전체파일 FAIL 순서의존 결함 차단).
  - **#2b** `tester-frontend.md`+`playbook-tdd.md` 7.6 — 프론트 변경검증/RED sanity는 파일 전체를 describe 순서대로 실행(격리 단독 PASS 금지 = backend @Nested 무음스킵과 동일 클래스).
  - **#3** `tester-quality.md` 기준5 — 횡단 불변식(분모 step===total·보안경계 순서)은 happy-path뿐 아니라 모든 early-return/skip/error 경로 커버 점검.
  - **#4 (무변경)** tester 거짓 codex 미설치 재발 = v3.19.0 메모리 override 가드가 이미 처리 + repostitch stale 메모리 삭제 완료 → 소비자 `git pull`로 해소. 보조절 제거 제안은 기각(YAGNI).

## 3.20.0 — 2026-06-20
- **bugfix-2-autopatch 회고 2건 — #1 적용 / #2 기각. MINOR, 거버넌스 무영향.**
  - **#1 적용 (위치보정)** — codex 7.7 소규모 critical 수정 시 "전체 파일 재출력" 요청 → codex가 직전 합의 설계를 자기 기억으로 재생성하며 회귀(findAllByAccountId→단건, 빈값/모호성 가드·R1·바이트동일 메시지 소실). `playbook-tdd.md` 7.7 게이트 처리에 "전체 재출력 금지 → 지목 라인 받아쓰기(tester-design) 또는 unified patch-diff만 + orchestrator 대조" 추가 + `orchestrator.md ## codex 호출 가드`에 cross-ref 1줄. 소비자는 orchestrator.md 7.7로 지목했으나 SSOT선 7.7=playbook-tdd.md(v3.2.0 분리) → 라우팅 보정.
  - **#2 기각 (stale — 적용 시 회귀)** — "/review 범용 reviewer 서브에이전트 부재" 제안은 SSOT v3.4.0(code-reviewer 서브에이전트, orchestrator:690)을 부정 → 자기검토=가짜2소스로 회귀. 소비자 에러(general-purpose not found)의 원인 = vendored 하네스가 v3.4.0 이전 → git pull로 해소. SSOT 수정 불요.

## 3.19.0 — 2026-06-20
- **PR-D4 회고 inbox 2건 — 전부 MINOR, 거버넌스 무영향.** repostitch PR-D4 세션 inbox 드레인.
  - **A. tester codex 거짓 미가용 재발 차단** (`tester-frontend.md`·`tester-backend.md` + wiki 신설): v3.17.0(232b168)이 "probe 없이 미설치 단정 금지"를 코드로 적용했으나 PR-D4서 tester-frontend 3/3 또 거짓보고. 진짜 원인 = 소비자 프로젝트 per-agent 메모리(`agent-memory/tester-frontend/feedback_codex_stdin.md`)의 "항상 폴백" 잘못된 일반화가 agent md 규칙을 덮어씀(agent md는 휴대, per-agent 메모리는 프로젝트 로컬 → 안 따라옴 → 규칙이 메모리 못 이기면 재발). 수정: 실행조건에 "agent-memory/feedback의 codex 미가용 단정 비신뢰, SSOT=orchestrator probe, 메모리 근거로 probe 스킵 금지" 1줄 + `wiki/agent-memory-overrides-rule.md` 신설(재발 클래스 영속화) + 소비자 stale 메모리 삭제(하네스 밖).
  - **B. 승인 패널 major → RED 필수잠금** (`orchestrator.md` Severity표 + `playbook-tdd.md` 7c.1 신설): 승인된 비차단 major refinement가 7a∥7b 흐름 diff 산출에서 누락 → GREEN 후 /review가 blocking 적발 → 재작업 라운드. 각 승인 major → 최소 1 RED 케이스 매핑 강제, 7.7이 커버리지 확인.
  - **교훈**: 규칙을 agent md에 넣어도 모순 per-agent 메모리가 같은 컨텍스트에 로드되면 메모리가 이긴다 → 규칙은 "메모리 단정 비신뢰, SSOT=Y" 명시 무력화 필요.

## 3.18.0 — 2026-06-20
- **inbox 안내문 보정 — dev clone `/harness-retro` 슬래시 미등록 명시.** 넛지·문서가 "dev clone에서 `/harness-retro` 호출"이라 안내했으나, 클코는 슬래시 스킬을 `.claude/skills/`에서만 등록 → harness가 repo 루트(`skills/...`)인 dev clone엔 미등록(소비자 세션의 vendored `.claude/skills/`에선 정상). dangling 슬래시 안내가 혼란 유발. 안내문만 보정(슬래시 억지 등록 안 함 — YAGNI). bump MINOR(넛지 훅·스킬 문구).
  - `hooks/harness-inbox-nudge.sh`·`skills/harness-check/SKILL.md` Step3·`README.md` §inbox: dev clone은 "'하네스 inbox 처리해줘' 요청 = `skills/harness-retro/SKILL.md` 절차 실행"으로 보정. 소비자 세션은 슬래시 등록됨을 명시.

## 3.17.0 — 2026-06-20
- **회고 반영 3건 (다른 세션 post_commit 탐지 + inbox 드레인) — 전부 MINOR, 거버넌스 무영향.** autoPatch 세션 + PR-D2 inbox 후보. C2(stdin)와 inbox 후보1(가용성)이 같은 결함의 두 면이라 **통합**.
  - **A. tester codex 교차검증 신뢰성** (`tester-backend.md`·`tester-frontend.md`·`orchestrator.md`): tester codex 호출이 `codex "..."`(stdin 미리다이렉트)라 "stdin is not a terminal"로 즉시 실패 → tester가 '미설치'로 오인 폴백 → 독립 2번째 소스 조용한 상실. ① 호출형을 `codex exec "..." -s read-only < /dev/null`로 수정. ② 실행조건에 "가용성 = orchestrator SSOT, tester 자기판단 금지, probe 없이 '미설치' 단정 금지" 명문화. ③ orchestrator `## codex 호출 가드`에 「가용성 확정 — orchestrator SSOT」 절 신설(세션 1회 probe → 컨텍스트 주입, 비대화형 표준 호출형 박음). 스코프 축소: session-check.sh probe 주입은 제외(규칙으로 충분, YAGNI).
  - **B. design-panel 필수 페르소나 부분실패 자동 재런치** (`orchestrator.md` 패널 실행): transient API 오류로 eng·cso가 죽어도 빈 criticals로 통과되던 문제. "orchestrator가 한다(반환 후)" 블록 맨 앞에 0번(완전성 검사) 삽입 — failures[] 非空/필수 페르소나 passEvidence<2면 그 페르소나만 1회 자동 재런치, 재런치도 실패면 에스컬레이션. 폴백 줄을 "전부 실패 시만 수동합성, 부분실패는 재런치 우선"으로 보정.
  - **C. developer narrowing 금지** (`developer-backend.md`·`developer-frontend.md`): 설계 SSOT 무조건 동작을 기존(stale) 테스트 통과 목적으로 조건부로 좁히는 narrowing 금지 — 충돌 시 좁히지 말고 DESIGN_MISMATCH/stale 반환. test-edit 훅이 못 막는 구현 narrowing을 규칙으로 보강.
  - inbox `DEVUNIT-repostitch.md` → `applied/` 이동. 관찰만(전체회귀 부채 N=6=D4 비차단 불변식 working-as-designed)은 reject.

## 3.16.0 — 2026-06-20
- **harness-check Stop 훅 백스톱 — post_commit 자가점검 enforcement 보강.** orchestrator post_commit 자가회고가 소프트(모델이 끝에서 기억해야 발동)라 자주 새서 `/harness-check`가 수동 호출로 전락. 결정적 enforcement 추가 → bump MINOR(비게이트·detection-only, 권한·게이트구조·불변식 무변).
  - **`hooks/harness-check-backstop.sh`** 신규: Stop 훅. 결정적 신호(`failure_*.md`·체크포인트 `[LOOP 2|3/3]`) 탐지 → 세션시작 baseline 이후 **신규** 고통이면 `decision:block`으로 turn 종료 1회 막아 `/harness-check` 호출 강제. 지문 스탬프로 신호당 1회(스탬프 먼저 갱신 후 block → 미준수해도 다음 Stop 허용, 루프 방지). `--seed` 모드는 SessionStart에서 baseline만 기록(차단 X) → 기존 고통엔 안 터짐.
  - **`settings.json`**: SessionStart에 `harness-check-backstop.sh --seed` 추가, Stop 훅 신설. 소비자 세션용(거기서 워크플로 돌고 vendoring된 .claude/settings.json 적용). dev clone은 repo훅 미발동.
  - **`agents/orchestrator.md`** 자가회고 절에 백스톱 enforcement 1줄(SSOT는 훅·harness-check). 훅은 탐지·강제까지만 — 적용은 `/harness-retro` 승인 게이트 불변.

## 3.15.0 — 2026-06-20
- **소비자 세션 wiki gotcha 운반 — capture의 push 비대칭 해소.** wiki capture(post_commit 자가점검)가 dev clone을 조용히 가정했음: gotcha는 보통 **소비자 세션**(worktree=제품 repo, origin≠harness-setup)에서 발견되는데 거기서 직접 커밋하면 제품 repo에 갇혀 harness-setup SSOT가 못 받고 유실. 개선후보(check→retro)가 이미 푼 비대칭과 동일 → **기존 회고 inbox 운반 재사용**(새 운반로 0, retro 변경 0). agent md 규칙 + 룰 doc → bump MINOR.
  - **`wiki/_schema.md`** capture 절차에 "어디로 가나" 분기 추가: dev clone은 직접 wiki 커밋, 소비자 세션은 직접커밋 금지·회고 inbox 드롭(`~/.claude/harness-retro-inbox/`, 형식 = `/harness-check` Step2.5 SSOT; content = gotcha 스텁 + sources 후보). dev clone에서 `/harness-retro`가 드레인 → Step2 "운영 gotcha→wiki" 라우팅으로 페이지 생성(inbox 경로가 `sources`로).
  - **`agents/orchestrator.md`** capture 절에 세션종류 분기 1줄(경로·드레인은 _schema SSOT 참조).
  - retro 드레인(inbox 모드 = 전부 읽어 분류 + Step2 gotcha→wiki 행)·check Step2.5(inbox 형식)는 이미 처리분 — 수정 없음. v3.14.0 읽기 트리거(B1/B2)가 환원된 페이지를 집어주는 짝.

## 3.14.0 — 2026-06-20
- **source-aware LLM wiki + 읽기 트리거 도입 (capture의 짝).** 기존 wiki는 capture(쓰기)만 트리거되고 ① 페이지에 근거(provenance)가 안 박히고 ② 세션이 쌓인 지식을 보러 가는 읽기 트리거가 약해 죽은 지식고 위험. agent md 규칙 추가 + 비차단 훅 + 스킬 갱신 → bump MINOR. (카파시 LLM wiki 패턴·라우팅·lint 개념은 이미 구현돼 있어 재작성 안 함 — sources 연결 + 읽기 인지만 보강.)
  - **A. sources 연결**: `wiki/_schema.md` frontmatter에 `sources` 필드 추가(gotcha는 가능한 한 필수, 근거 없으면 invent 금지·"근거 부족" 표시), capture 절차·lint 항목에 sources 규칙 1줄씩. `harness-retro` Step5가 Step1 추출 근거(회고·failure·CHANGELOG·docs·inbox `source_session`)를 페이지 `sources`로 보존 + 같은 결함클래스는 기존 페이지 갱신·sources 병합. `harness-check` Step2.5 inbox 파일이 retro의 sources 소스가 됨을 명시.
  - **B. 읽기 트리거**: `orchestrator.md`에 "wiki 운영지식 참조(읽기)" 절 신설 — 작업 착수 시 `index.md` 카탈로그 인지, **디버깅·환경 함정 진입 시 재디버깅 전 `wiki/` Grep**(같은 함정 두 번 안 밟기). `session-check.sh` block7 신설 — 세션 시작에 wiki 페이지 수 + 카탈로그 경로 1줄 넛지(소비자 세션 `.claude/wiki` 기준, 항상 노출).
  - 기존 wiki 페이지 소급 sources는 안 함(근거 invent 위험) — 신규·갱신분부터 적용. 새 스킬·README 보강 없음(YAGNI / 이미 설명됨).

## 3.13.0 — 2026-06-20
- **live-UI QA를 tester-frontend로 귀속 — gstack qa 택소노미를 SSOT Read로 (손복제 drift 제거).** 최초 설계(별도 orchestrator `/qa-only` 단계)가 **tester-frontend와 중복**임이 드러남: tester-frontend가 이미 `$B`(browse) + "gstack QA issue-taxonomy"로 실기동 UI를 report-only 검증 중이고, 그 택소노미를 **손으로 베껴** 둠. → 별도 단계는 잉여라 폐기하고, tester-frontend가 정본 택소노미 파일을 Read하게 정합. 자체 검증 흐름 변경 없음(귀속·SSOT화) → bump MINOR.
  - **`tester-frontend.md`**: 검증 착수 전 `~/.claude/skills/gstack/qa/references/issue-taxonomy.md`를 Read해 카테고리·페이지별 탐색 체크리스트의 SSOT로 사용(인라인 목록 = CWE/KISA/WCAG·심각도·YAGNI 보강 스냅샷, 파일 최신이면 파일 우선). 부재 시 인라인 폴백. 점수/PASS·FAIL/변경-스코프 한정은 하네스 규칙 유지.
  - **tester-backend 무관**: 브라우저/UI 없음(JUnit·API). qa-only는 프론트 전용. `/qa`(자동수정) 변형은 거버넌스 충돌이라 미사용 — report-only만.
  - **정합**: `CONTEXT.md`(회귀 oracle 이원화 — tester-frontend가 택소노미 SSOT로 변경-스코프 UI 부분 자동화), `finalizer.md`(사람E2E 자동커버 = tester-frontend UI 스모크 포함).
  - 참고: 별도 `/qa-only` 단계는 직전 커밋(38511d0, 동일 v3.13.0 라벨)에서 추가됐다가 본 커밋에서 **revert**(orchestrator 흐름·라우팅표·검증단계 짝, routing-map 노드 원복). VERSION은 3.13.0 유지(같은 날 교정 — 별도 bump 안 함).

## 3.12.0 — 2026-06-20
- **사람 E2E 점검표 비밀 누출 가드 — gstack-redact 비차단 도구화 (P1①).** finalizer 사람E2E 점검표의 "민감값 평문 금지"가 LLM 기억 의존 규칙이었음 → `gstack-redact`로 출력 직전 자동 스캔. agent md 규칙 추가 → bump MINOR.
  - **`finalizer.md` ## 사람 E2E 점검 안내**: 절차에 단계 5(비밀 스캔) 신설. 렌더된 점검표를 `gstack-redact --json --repo-visibility private` 통과 → exit 2(MEDIUM/PII)는 `--auto-redact`로 치환본 출력, exit 3(HIGH/라이브 비밀)은 수동 `<...>` 치환 + WARN 보고(소스 하드코딩 의심). **커밋 비차단 유지**(채워진 점검표는 리포트 텍스트라 git 미포함). redact 실패는 가드만 생략.
  - 불변식: 민감값 평문 금지 규칙을 도구 강제로 승격(기억 의존 제거).
  - **`review/human-script.template.md`**: 보안요건 c에 redact enforcement 명시(가드 — airtight 아님, 실수 차단용).
  - 검증: 스모크로 라이브 AWS/OpenAI키=HIGH 포착, 이메일=MEDIUM 자동치환, doc예시/플레이스홀더(`<테스트PW>`)=무시(false positive 없음) 확인. gstack-redact는 PII+라이브 자격증명 탐지(doc-example heuristic으로 예시는 강등).

## 3.11.0 — 2026-06-20
- **스킬 sync 메커니즘 현실 정합 — sync 대상을 외부 제3자 스킬만으로 trim + gstack staleness 넛지 신설 (사용자 진단 세션).** sync-skills.sh SOURCES 4개가 전부 이 PC에서 phantom(글로벌 원본 부재)임이 드러남: co-plan·pair-impl·learning-gate는 **자체 authored = repo가 origin(SSOT)** 이라 받아올 상류가 없고, grill-with-docs(Matt Pocock 외부)만 실제 sync 대상. 거버넌스 불변식 불변(스크립트/넛지 정합) → bump MINOR.
  - **`sync-skills.sh`**: SOURCES에서 자작 3개(co-plan·pair-impl·learning-gate) 제거, 외부 grill-with-docs 1개만 유지. CRITICAL_SKILLS도 grill만. versions.md 날짜 stamp **sed 버그 수정**(이전 패턴 `**마지막 전체 동기화**:`가 versions.md에 없어 sync 성공해도 날짜 갱신 0 → staleness 신호 영구 고장이었음 → 실제 스탬프 줄 `**마지막 동기화**:`로 정합).
  - **`session-check.sh §3`**: versions.md 날짜 기반 스킬 sync 넛지(노이즈·고장) 제거 → **gstack staleness 넛지**로 교체. gstack VERSION mtime 7일 초과 시 `/gstack-upgrade` 권장(네트워크 0). 자체 스킬은 SSOT라 sync 넛지 불요, 외부 grill은 수동 게이트라 시간 넛지 안 함.
  - **연쇄 정합**: `orchestrator.md`(경고 처리 표 스킬sync→gstack), `finalizer.md`(버전bump 의식 critical diff 대상 learning-gate 제거→grill만), `versions.md`(3출처 재구조: 자체 SSOT / 외부 sync / gstack), `README.md`.

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
