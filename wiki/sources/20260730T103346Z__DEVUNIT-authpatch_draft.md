---
source_session: 서브모듈 커밋 드릴다운 (신규기능 트랙, TDD 7.5 RED → 8 GREEN 풀사이클)
project: DEVUNIT-authpatch_draft
worktree: C:\Users\crinity\.local\share\worktrees\DEVUNIT\authpatch_draft\feature-dashboard-commitlog-3
date: 2026-07-30
commits: a1b1b233 (feat, 41파일 +10353/-218) → 90b2c6dd (docs 완료섹션)
signals: 7.7 품질게이트 LOOP 2/3 · orchestrator 지시결함 2건(각 1라운드 소모) · 서브에이전트 사망 3회 · 도구/환경 함정 4종
scale: 백엔드 368케이스 + 프론트 171케이스, 테스트 19파일 8340줄
---

# 하네스 자가 회고 — 서브모듈 커밋 드릴다운 풀사이클 (2026-07-30)

배경: GitLab 메타레포 커밋 상세에서 서브모듈 gitlink 변경 → 서브모듈 저장소 커밋목록 → 개별 커밋 diff를 온디맨드 조회하는 신규기능. 설계패널 승인본(LOOP4) 계획서 1495줄을 오라클로 TDD 7.5(RED 작성) → 7.6(RED sanity) → 7.7(품질게이트) → 8(GREEN) 전 구간 수행. 최종 전 게이트 GREEN, blocking 0으로 커밋 완료.

**중요**: 아래 후보 1·2는 **orchestrator 자신의 지시 결함**이다. 게이트가 잡아냈지만 각각 1라운드(구현+검증)를 태웠다. 하네스 룰 결손이 원인이라 규칙화 레버리지가 크다.

---

## 후보 1 [P1] stub 규칙에 "객체 반환 null 허용"이 남아 있어 RED가 단언 미실행으로 죽는다

**증상**: TDD 7.6 RED sanity 1차에서 366케이스 중 **wrong-reason FAIL 100건**. 전부 stub이 `null`/`Optional.empty()`를 반환 → 테스트가 즉시 `.getX()`/`.get()` 역참조 → NPE. 실패가 `AssertionError`가 아니라 NPE라 **단언이 실행조차 안 됐고**, "이 단언이 잘못된 구현을 잡아낼 수 있나"가 검증되지 않았다. stub 모양만 교정(중립 인스턴스 반환)하는 배치 S4 1라운드 + 7.6 재실행 1회를 추가로 소모.

**추정 원인**: `orchestrator.md`/`playbook-tdd.md`의 stub 규칙이 "**benign 기본값 반환**(null/빈 컬렉션/false)"으로만 적혀 있다. `null`이 명시적으로 허용된 탓에 developer가 객체 반환 메서드에도 null을 넣었다. 규칙의 의도(=RED가 올바른 이유로 실패)와 문자(=null 허용)가 어긋난다.

**제안**: stub 규칙을 반환 타입별로 분기해 명문화.
- 객체/DTO 반환: **`null` 금지, 중립 최소 인스턴스**(문자열 빈문자, 숫자 0, boolean false, 컬렉션 빈 리스트)
- enum 포함 결과 객체: **"실패/미구현"을 뜻하는 값**을 고른다(성공값 금지 — 성공경로 케이스가 거짓 통과)
- `Optional`: 테스트가 `.get()`/`.orElseThrow()`로 값 구조를 검사하는 경로면 `Optional.of(중립)`, "부재"가 정상 시맨틱이면 `empty()` 유지
- 불변: `throw`/`UnsupportedOperationException` 금지(현행 유지)
- 트레이드오프 명시: 중립값과 우연히 일치해 거짓 PASS하는 케이스가 생긴다 → 7.7 "RED인데 PASS" 목록으로 추적(이번에 실제로 그렇게 처리했고 잘 작동함)

**근거**: 7.6 1차 366/106F/**100E**(NPE) → S4 교정 후 2차 367/163F/**41E** → 최종 3차 368/192F/**13E**. 잔존 13은 `UnnecessaryStubbing`(production 조기분기 산물)으로 waive.

**대상 파일**: `.claude/docs/playbook-tdd.md`(8단계 stub 규칙) 또는 `.claude/agents/orchestrator.md`

---

## 후보 2 [P1] 공용 테스트 헬퍼의 시맨틱을 바꾸라고 지시하기 전에 호출부 용례 분기를 확인하지 않았다

**증상**: 7.7 품질게이트가 "`call()` 헬퍼가 예외 미발생 시 null을 반환해 호출부에서 NPE로 죽는다 → 진단성 부족(major)"을 지적. orchestrator가 "**`call()` 헬퍼 안에** `assertThat(ex).isNotNull()` 가드를 추가하라"고 지시. 그런데 같은 헬퍼를 **예외를 기대하지 않는 케이스도 재사용**하고 있어(`ex==null`을 명시적으로 기대하는 경계 케이스 포함) 4건이 파손. 다시 `call()`(가드 없음) / `callExpectingError()`(가드 있음)로 분리하는 라운드를 태웠다.

**추정 원인**: 리뷰 findings를 작성자에게 반환할 때 orchestrator의 `receiving-code-review` 타당성 게이트가 **"이 수정이 다른 호출부를 깨나"** 축을 안 본다. 현행 게이트 4항목은 ① 전제 실재 ② 이미 차단됨 ③ YAGNI ④ 승인계약 충돌뿐이다.

**제안**: `receiving-code-review` 게이트에 5번째 축 추가 — **"공용 헬퍼/시그니처의 시맨틱을 바꾸는 수정이면, 위임 전에 호출부 용례가 단일한지 grep으로 확인한다. 분기가 있으면 '전 호출부 일괄 변경'이 아니라 '분기별 분리'를 지시한다."** 비용은 grep 1회, 손실은 라운드 1회.

**근거**: 7.6 3차에서 `aud01[1]`(Kind.OK)·`aud03[1]`(audit=OK)·`wesDD07b` 254/255(테스트 자신이 `ex==null` 기대) 4건 FAIL. 최종 분리 후 예외기대 16건 / 플레인 11건으로 갈렸다 — **애초에 27개 호출부가 2종류**였다.

**대상 파일**: `.claude/agents/orchestrator.md`(`## 라우팅 규칙`의 findings 타당성 게이트 절)

---

## 후보 3 [P1] `@SpringBootTest` JLine Terminal 무한대기 — 우회 플래그가 tester md에 없어 매번 재발견

**증상**: tester-backend가 `mvn test` 실행 시 `@SpringBootTest` 계열에서 **Terminal 빈 생성 중 무한 대기**. 1·2차 시도가 각 10분 타임아웃으로 죽어 **20분 낭비**. 3차에 `-DargLine="-Dorg.jline.terminal.provider=dumb -Dorg.jline.terminal.dumb=true"` 우회를 찾아 붙이자 **42.6초에 12클래스 완주**.

**추정 원인**: 이 프로젝트는 Spring Shell 앱이라 컨텍스트 로드 시 JLine Terminal 빈이 생성된다. 비대화형(surefire fork) 환경에서 tty가 없으면 블로킹. 우회법이 **어디에도 기록돼 있지 않아** tester가 매 세션 재발견해야 한다(이후 라운드마다 orchestrator가 프롬프트에 수동 주입해야 했다).

**제안**: `tester-backend.md`(+`tester-runtime.md`)의 실행 명령 표준에 **argLine 우회를 상수로 박는다**. "`@SpringBootTest`가 포함된 스코프면 이 플래그 필수, 없으면 무한대기"를 근거와 함께. 추가로 wiki gotcha 페이지 1장.

**근거**: 실측 — 우회 없이 600s 타임아웃 ×2(`SubmoduleDrilldownWiringIntegrationTest` 342.9s 소모 후 강제종료, `WebExportServiceCommitDetailTest` 컨텍스트 부팅 중 349초 대기), 우회 후 42.6s.

**대상 파일**: `.claude/agents/tester/tester-backend.md`, `.claude/agents/tester/tester-runtime.md`, `wiki/`(신규 gotcha)

---

## 후보 4 [P1] Write 도구 대용량 쓰기 시 raw NUL 주입 — 3건 관측, `file`이 `data` 판정 → ripgrep 무음 제외

**증상**: 7.5 RED 작성 중 대용량 Write 산출물에 **NUL 바이트가 들어가 `file -b`가 `data`로 판정**. 이 상태면 **ripgrep이 파일 전체를 무음으로 검색 대상에서 제외**한다 → developer·tester·reviewer·codex 전부 그 파일을 grep으로 못 찾는다. 관측 3건(`WebExportServiceCommitDrilldownTest` 802줄, `useSubmoduleCommitDiff.spec.ts` 644줄, `CommitDetailPanel.spec.ts`). 추가로 **계획서 md에도 raw NUL 1바이트**가 있어 GNU grep이 `Binary file matches`로 처리 — GREEN 단계 developer가 오라클(계획서)을 grep으로 못 읽을 뻔했다(orchestrator가 발견해 escape 표기로 치환).

**추정 원인**: 두 갈래로 갈리는데 **구별 불가**. ① 작성자가 테스트 픽스처에 제어문자를 raw로 박음 ② Write 도구의 대용량 쓰기 자체가 주입. 3건 관측이라 도구측 원인이 유력하나 확증 못 함.

**제안**:
- **표준 절차 승격**: 대용량 Write 산출 후 **매번** `tr -dc` 제어문자 카운트(0이어야) + `file -b FILE` 검사. `iconv`는 통과하므로 무용(NUL은 유효 UTF-8).
- 작성 에이전트(tester-design/developer-*) md에 **"raw 제어문자 금지, escape만"** 선제 규칙 + 반환 계약에 NUL 자가검사 항목 추가.
- CLAUDE.md의 기존 "원인 불명 개별 바이트로 ripgrep binary 오탐" 항목이 **이것으로 규명됨** — 그 항목에 상호참조 추가.

**근거**: `file -b` 실측 `data` → 재Write로 해소. 계획서 md는 NUL 제거 후 `Unicode text, UTF-8 text`로 복구 + Grep 정상화 확인.

**대상 파일**: `.claude/agents/tester/tester-design.md`, `.claude/agents/developer/*.md`, `CLAUDE.md`(기존 항목 보강), `wiki/`(신규 gotcha)

---

## 후보 5 [P2] javadoc 본문의 glob 나열이 블록주석 종료 토큰을 형성해 전체 test-compile 차단

**증상**: 픽스처 수정 라운드에서 추가한 javadoc 한 줄이 케이스 이름을 glob으로 나열한 형태였는데, `*` 바로 뒤의 `/`가 **블록주석 종료 토큰을 형성**. 주석이 문장 중간에서 끝나고 뒤 텍스트 6줄이 Java 코드로 파싱되어 **36개 구문에러** → `test-compile` BUILD FAILURE → **지시된 18개 클래스 전부 실행 불가**. tester-backend가 정확히 진단(`javac -encoding UTF-8` 단독 재현으로 인코딩 문제가 아님을 확정)해 1라운드로 복구.

**추정 원인**: 테스트 케이스 이름을 glob 패턴으로 나열하는 게 자연스러운 표기인데, Java 주석 안에서는 금지 패턴이다. 아무 룰에도 없다.

**제안**: 작성 에이전트 md + backend rules에 **"주석 안에서 `*` 바로 뒤 `/` 금지(글롭 나열은 쉼표 구분)"** 1줄. 자가검사 정규식 제공(`[^ *]` 뒤 주석종료 패턴 탐색).

**근거**: `SubmoduleDrilldownResolverTest.java:148`, `[ERROR] ...:[148,31] <identifier> expected` 외 35건.

**대상 파일**: `.claude/agents/tester/tester-design.md`, `.claude/rules/package/autopatch/backend.md`

---

## 후보 6 [P2] 서브에이전트 사망 시 "산출 0"이라 단정하면 완료된 작업을 재실행한다

**증상**: 이 세션에서 서브에이전트가 **3회 사망**(G4 프론트 GREEN=세션 토큰 한도, G3 백엔드 GREEN=`Connection closed mid-response`, tester-design 픽스처=API 끊김). 셋 다 **보고 없이 죽었지만 디스크에는 작업이 사실상 완료**돼 있었다(G4: 컴포저블 56→161줄 + 3파일 실구현 완료 / G3: Admission·엔드포인트·감사 2메서드·정규식 제거 전부 완료). orchestrator가 매번 grep·wc로 실측해 완주를 판정했고, 그 덕에 **재실행 3회를 아꼈다**.

**추정 원인**: 하네스에 "사망 산출 판정 절차"가 명문화돼 있지 않다. 설계패널 세션 끊김 복구 절차(`journal.jsonl` 확인)는 있는데 **일반 서브에이전트용은 없다**. 이번엔 orchestrator가 즉흥적으로 처리했다.

**제안**: `orchestrator.md`에 짧은 절 추가 — **"서브에이전트가 보고 없이 죽으면 재발사 전에 디스크로 완주를 판정한다: ① 산출 파일 존재·줄수 ② 핵심 심볼 grep ③ 컴파일/타입체크 1회. 완료면 검증 단계로, 부분이면 남은 부분만 재위임."** 세션 한도 자체는 외부요인이라 규칙화 대상 아님(관찰).

**근거**: 3회 전부 "죽었지만 완료" — 순진하게 재발사했으면 대규모 중복 작업 + 파일 충돌.

**대상 파일**: `.claude/agents/orchestrator.md`

---

## 후보 7 [P2] 경계값 픽스처를 하드코딩 리터럴로 쓰면 오프바이원이 게이트 통과 전까지 안 보인다

**증상**: 7.7 1차 QUALITY_FAIL critical 3건이 전부 **hex40 픽스처가 1자씩 밀린 것**(라벨 "40자"인데 실제 39, "41자"인데 실제 40). 위험이 컸다 — 39자에 참을 기대하는 케이스는 frozen 계약(hex 40자 정규식)을 지킨 구현에서 **영구 FAIL**이라, GREEN으로 만드는 유일한 길이 **보안 형식게이트를 39자 허용으로 약화**하는 것이었다. 즉 테스트가 developer를 보안 훼손으로 유도하는 구조. 게다가 대소문자 축 케이스는 "길이가 짧아서" 통과하고 있어 **검증력이 0**이었다.

**추정 원인**: 40자 hex를 손으로 타이핑/복사. 눈으로 세는 검증은 실패한다.

**제안**: `tester-design.md`에 **"길이·경계 픽스처는 정본 1개를 정하고 경계값은 파생식으로 만든다"**(substring / 문자 1개 추가 / toUpperCase / repeat / padStart). `@ValueSource`처럼 컴파일타임 상수만 되는 자리는 **앵커 정규식 grep으로 길이를 기계 검증**하고 그 결과를 보고에 넣는다.

**근거**: orchestrator가 `grep -onE` + `awk '{print length}'`로 바이트 실측해 확정. 재작업 후 정본 파생식 전환 + 실측 재확인으로 해소. 참고로 이 결함을 **7.7 품질게이트(opus)가 잡았다** — 게이트 자체는 정상 작동했고, 없었으면 GREEN 라운드에서 보안 약화로 이어졌을 사안.

**대상 파일**: `.claude/agents/tester/tester-design.md`

---

## 관찰만 (규칙화 안 함)

- **세션 토큰 한도·API 끊김 3회** — 외부요인. 하네스 레버리지 없음. 단 후보 6(사망 후 판정 절차)은 하네스 몫이라 분리해 올림.
- **codex CJK mojibake** — 이번에도 codex를 파일쓰기에서 배제(7.5 단일 소스)했고, 리뷰 단계에서는 "원본 UTF-8로 읽어라 + 주석 독해 의존 금지" 주입으로 정상 산출을 받았다. 기존 룰이 작동함.
- **7.7 LOOP 2/3** — 게이트가 진짜 결함(보안 약화 유도 픽스처 + NUL 단언 부수손상)을 2라운드에 걸쳐 잡은 것이라 **정상 작동**. 루프 자체를 줄이려 하면 안 됨. 다만 후보 7이 1차 원인을 예방한다.
