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
- [[agent-memory-overrides-rule]] — tester가 agent md 규칙 있는데도 codex 거짓 미가용 보고 → stale per-agent 메모리(`agent-memory/tester-*/feedback_codex_stdin.md`)가 규칙 덮어씀. 규칙은 "메모리 단정 비신뢰" 명시해야 휴대 효력
- [[spring-profile-bean-eval-timing]] — @Profile은 빈 등록 시점 평가 → ApplicationContextRunner는 withInitializer 말고 withPropertyValues로 active profile 줘야 등록됨
- [[vue-immediate-watch-template-ref]] — Vue `watch(...,{immediate:true})`가 mount 전 동기 실행→template ref null→차트 조용히 미렌더. flush:'post'로도 안 고쳐짐. 첫 렌더는 `onMounted(renderChart)`로
- [[vite-stale-served-source-windows]] — Windows에서 Vite dev server 워처가 편집 miss→stale transform 서빙. 디스크≠서빙. `curl localhost:PORT/src/...`로 서빙 소스 확인 후 재시작

## 관련 (repo 내 다른 지식 — 중복 금지, 링크만)
- 설계·ADR: `../docs/` (예: `../docs/harness-versioning.md` — 하네스 버전관리 설계 전문)
- 도메인·운영 용어 정의: `../CONTEXT.md`
- 로컬/머신 한정 메모: auto-memory `~/.claude/projects/.../memory/` (휴대 안 됨)
