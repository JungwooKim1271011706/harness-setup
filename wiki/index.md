# wiki 인덱스

> 하네스 운영 지식 카탈로그. 새 페이지 추가 시 여기 한 줄 등록. 작성 규칙은 [[_schema]].

## 운영 (operational)
- [[slack-notify-hook]] — CC 응답 완료 시 Slack 알림(글로벌 Stop 훅)의 구조·배포·비밀 관리

## Gotcha (함정·교훈)
- [[jq-korean-encoding]] — Slack 알림 한글이 깨지는 진짜 원인과 회피(파일 경유 vs curl 인자)
- [[windows-path-jq]] — Windows에서 CC가 stale PATH를 상속 → 훅에서 jq 못 찾는 문제와 자가탐색 해법
- [[gstack-install-windows]] — gstack/setup이 브라우저 추출에서 hang → 스킬 미등록. 등록만 수동 재현 + bun stale PATH
- [[surefire-nested-skip]] — Surefire 2.22.2 `-Dtest=클래스` 격리 실행이 JUnit5 @Nested를 무음 스킵 → 거짓 GREEN. 전체실행/`$Nested` 명시로 회피
- [[surefire-it-naming-skip]] — `*IT` 명명 테스트가 surefire 기본 스캔에서 무음 누락(failsafe 미바인딩 pom) → `-Dtest=`만 PASS는 거짓 GREEN. *Test 명명/기본 include 매칭으로 회피
- [[device-guard-blocks-jdk-javac]] — Windows Device Guard(WDAC)가 서명 안 된 OpenJDK javac.exe 실행 차단 → maven fork 컴파일이 `.java` 에러 0줄로 무음 실패. cmd서 `javac -version` 직접 실행해 진단, 통과 JDK로 `-Djdk-1.8-home` 오버라이드
- [[surefire-runaway-test-timeout]] — 폭주(무한루프) 테스트가 surefire 포크 JVM을 무한 점유(수 GB·GC 죽음나선) → 머신 메모리 고갈. mvn에 per-fork(`-Dsurefire.timeout`)+Jupiter per-test 타임아웃 강제로 fail-fast. jps/jstack 응급대응
- [[codex-tmp-windows-path]] — codex 호출 시 gstack-paths TMP_ROOT가 `C:Users`(슬래시 누락) → mktemp 실패 → /tmp 폴백 1회 재시도 지연
- [[codex-python-shim-windows]] — codex --json 파서가 Windows Store python shim을 골라 broken pipe(exit 101) → PYTHON_CMD로 실제 인터프리터 명시. 차단훅 mvn 오탐 회피 노트 포함
- [[codex-model-stall-windows]] — codex smoke ping은 exit0 통과하나 실프롬프트가 모델 stall로 exit124 hang → probe false-positive로 20분 낭비. probe를 대표프롬프트+60s 타임아웃으로 강화, 타임아웃=불가
- [[codex-bash-direct-timeout]] — codex를 Bash 도구로 직접 호출 시 Bash 기본 timeout 2분이 codex 실호출(2~9분)보다 짧아 exit143 SIGTERM. 내부 GNU timeout과 별개 레이어(짧은 쪽 승). Bash timeout param ≥585000ms 명시. /codex 스킬 경유는 무관
- [[codex-bash-heredoc-metachar]] — codex Bash직접호출 프롬프트에 셸 메타문자(백틱·`$`·`[]{}`) 있으면 double-quote 조기종료/명령치환 → EOF exit2(codex 호출조차 안 됨). single-quote heredoc 파일에 써서 `codex exec "$(cat "$PF")"`로 전달(리터럴 보존). /codex 스킬 경유는 무관
- [[codex-review-mojibake-line-merge]] — codex review(PowerShell Get-Content)가 한글/혼합인코딩 파일서 인접 라인 병합 렌더 → 정상 코드를 "주석처리"로 오독, 거짓 P1 blocking. 출력 mojibake(`3?몄옄??`)가 신호. codex P1은 항상 디스크 직접 Read 인용라인 대조(receiving-code-review). python-shim·tmp-path와 별개 렌더축
- [[claude-rules-gitignore-local-only]] — .claude/rules/ 는 양쪽 git서 gitignore(제품 repo .claude/ + harness-setup rules/) → rule 편집이 커밋 안 됨(로컬 전용). 편집=커밋 착각 금지, git check-ignore -v가 SSOT. 공유할 규칙은 CONTEXT/docs로
- [[agent-memory-overrides-rule]] — tester가 agent md 규칙 있는데도 codex 거짓 미가용 보고 → stale per-agent 메모리(`agent-memory/tester-*/feedback_codex_stdin.md`)가 규칙 덮어씀. 규칙은 "메모리 단정 비신뢰" 명시해야 휴대 효력
- [[spring-profile-bean-eval-timing]] — @Profile은 빈 등록 시점 평가 → ApplicationContextRunner는 withInitializer 말고 withPropertyValues로 active profile 줘야 등록됨
- [[springshell-noninteractive-runner-order]] — spring-shell 비대화형 배치(TTY 없음)서 셸 러너가 leftover 인자를 명령으로 해석→CommandNotFound. 커스텀 ApplicationRunner에 @Order(HIGHEST_PRECEDENCE) 줘야 먼저 실행. CLI 플래그로는 못 고침
- [[spring-componentscan-basepackages-root-omission]] — 명시 @ComponentScan(basePackages)는 기본 스캔을 **대체**(보강 아님) → 루트 패키지 빠지면 @Component 빈 조용히 미등록·run() 미호출(예외도 없음). 리플렉션 단위테스트는 등록 검증 못함→ApplicationContext 통합테스트로
- [[powershell-set-content-utf8-bom]] — PowerShell 5.1 Set-Content -Encoding UTF8이 BOM(EF BB BF) 붙임 → SnakeYAML 등 첫 키 깨짐→바인딩 null→엉뚱 분기. WriteAllText(UTF8Encoding($false)) 또는 -Encoding ascii. Format-Hex로 앞 3바이트 확인
- [[hibernate-naming-strategy-explicit-name]] — Spring 기본 naming strategy는 **명시 `@Column/@Table(name=...)` 이름도** camelCase→snake 변환(Hibernate 순정과 다름). 수동 DDL이 camelCase면 신규설치 1364. DDL을 snake 출력과 글자단위 일치
- [[information-schema-table-name-ci-collation]] — `information_schema.*.TABLE_NAME`은 ci collation → `'Users'`가 snake `users`에 매칭(LCTN=0이어도). "메타조회 통과=스키마 사실" 추론 금지, 리터럴도 snake 일치 + 속성(NON_UNIQUE)까지 단언
- [[vue-immediate-watch-template-ref]] — Vue `watch(...,{immediate:true})`가 mount 전 동기 실행→template ref null→차트 조용히 미렌더. flush:'post'로도 안 고쳐짐. 첫 렌더는 `onMounted(renderChart)`로
- [[vite-stale-served-source-windows]] — Windows에서 Vite dev server 워처가 편집 miss→stale transform 서빙. 디스크≠서빙. `curl localhost:PORT/src/...`로 서빙 소스 확인 후 재시작
- [[jsdom-missing-browser-apis]] — renderer가 jsdom 미구현 브라우저 전역(CSS.escape·matchMedia 등) 쓰면 프로덕션 OK·단위테스트 TypeError 전수 폭발. 환경 가드 헬퍼로 회피
- [[electron-before-quit-window-close-order]] — Electron 창 X경로 순서(close→파괴→window-all-closed→before-quit)라 before-quit 단일게이트 종료확인은 창 파괴 후라 취소 불성립. window `close` preventDefault에서 dialog, before-quit는 app/ipc quit 전용
- [[vitest-mockresolvedvalue-microtask-flush]] — `vi.fn().mockResolvedValue()` await는 스파이 래핑 ~3 microtask tick. 고정 `await Promise.resolve()`×2 flush는 mocked 게이트 재개 못 기다려 GREEN서 undefined TypeError. flush-until-condition 상한 루프로 틱 비의존화(tester-design R16)

## 관련 (repo 내 다른 지식 — 중복 금지, 링크만)
- 설계·ADR: `../docs/` (예: `../docs/harness-versioning.md` — 하네스 버전관리 설계 전문)
- 도메인·운영 용어 정의: `../CONTEXT.md`
- 로컬/머신 한정 메모: auto-memory `~/.claude/projects/.../memory/` (휴대 안 됨)
