---
source_session: BL-051 clone 순서 재배열 + PAT 스코핑 (TDD 풀사이클, 설계승인~커밋 완주)
project: DEVUNIT-authpatch_draft
date: 2026-08-06
branch: featrue-tocaiserver-export-1
commits: 9478d069 / aadd8d53 / 1cb22775 / 1e1e1cb2
---

# 하네스 자가 회고 — BL-051 TDD 풀사이클

> **표준 신호(Step 1 표)는 0건이다.** 7.7 LOOP 1/3(≥2 미달) · escalation 0 · codex 정상 완주 · 설계 반려 0 · `failure_*.md` 0건.
> 아래 2건은 **그 표에 없는 축**에서 실제로 발생한 운영 고통이다. 표는 예시 목록이지 닫힌 집합이 아니라고 보고 후보화했다.

---

## 후보 1 — grep 매치를 "영향"으로 직행 판정 (우선순위: 중)

### 증상
orchestrator가 서브에이전트 보고의 grep 카운트(`new GitProcessRunner()` 3파일 16건)를 그대로
**"이 2파일은 스텁 없이 실행하면 IllegalStateException으로 **확정 파손**된다"** 로 옮겨 위임 프롬프트에 박았다.
받은 서브에이전트가 소스 추적으로 반박했다 — `GitProcessRunnerSubmodulePatTest`의 3건은 전부
`mayTriggerRemoteFetch`(= `exportConfig` 미참조 **순수 predicate**)만 리플렉션 호출하고
`buildProcess()`를 타지 않아 **fail-closed 게이트에 도달하지 않는다**. 무변경이 정답이었다.

orchestrator가 직접 코드대조로 재확인(`getDeclaredMethod("mayTriggerRemoteFetch", List.class)` 3건,
`buildProcess` 호출 0건)해 서브에이전트가 맞음을 확정했다. 전제를 그대로 삼켰다면 **무해한 파일 3곳을
불필요하게 수정**했을 것이다.

### 왜 잡혔나 (운 좋았던 지점)
서브에이전트가 오케스트레이터 전제를 **반박해 왔다**. 이건 계약에 없는 자발적 행동이고,
순종적인 에이전트였다면 그대로 수정하고 "완료" 보고했을 것이다.

### 추정 원인
현행 규칙이 **누락 방향만** 경고한다:
- `orchestrator.md`: *"grep 카운트는 하한이다"* — ripgrep binary 오탐으로 무음 제외되는 축
- `backend.md`: 생성자 시그니처 touch-surface 함정 — 같은 축(11≠12파일 실측)

**과대추정 방향(매치가 있는데 영향은 없음) 경고가 어디에도 없다.**

같은 세션에서 **양방향을 다 밟았다**:
- 누락 방향: `GitExportOrchestratorListHeaderTest.java`가 ripgrep binary 오탐으로 무음 제외 → `grep -IL .`로 적발 → BL-055 등재
- 과대 방향: 위 `SubmodulePatTest` 오판

### 제안 개선 방향
`orchestrator.md`의 grep 함정 문구를 양방향으로 정정:

> **grep 매치는 후보 목록이다 — 하한도 상한도 아니다.**
> ① 매치가 **빠질 수 있다**(binary 오탐 무음 제외 → `grep -IL .` 병행, 최종 봉인은 컴파일)
> ② 매치가 **영향을 뜻하지 않는다**(호출은 있는데 대상 분기에 도달 안 함)
> → 위임 프롬프트에 "확정 파손"·"전부 깨진다" 류 **단정을 넣기 전에 매치마다 도달성을 소스로 판정**한다.
> 판정 안 했으면 단정 대신 "후보 — 도달성 미확인"으로 전달한다.

### 근거
- 이번 세션 배치3 → 배치3-b 위임 체인. 배치3-b 반환문에 반박 원문 기록:
  *"orchestrator 프롬프트의 전제 중 GitProcessRunnerSubmodulePatTest에 대한 부분은 소스 추적 결과 성립하지 않았다. grep 매치 카운트만으로 영향범위를 판정한 과대추정으로 보인다"*
- 반대 방향 실측: `grep -IL . -r src/test src/main` → `GitExportOrchestratorListHeaderTest.java` 1건 검출(의도적 NUL 테스트 데이터), BL-055로 등재

### 관련 파일
- `.claude/agents/orchestrator.md` (grep 함정 문구)
- `.claude/rules/package/autopatch/backend.md` (touch-surface grep 항목 — 양방향으로 보강 가능)

---

## 후보 2 — tester-design 계약에 "제어문자 리터럴 타이핑 금지"가 없다 (우선순위: 높음)

### 증상
7a(tester-design)가 `docs/features/2026-08-05-clone-order-gitlink-fix.md`에 케이스를 append하면서
**raw 제어바이트를 파일에 실제로 주입**했다. CWE-117(로그 인젝션) 위생처리 케이스(SEC-08)를 쓰다가
이스케이프 표기를 소스에 직접 타이핑한 것이 실제 바이트로 기록됐다.

- 자가신고: *"제어문자 3개, 블록주석으로 봉인 완료"*
- **실측: 4바이트**(NUL 2 + BEL 2), 봉인 불완전(인라인 주석 안에 2바이트가 갇혀 있었다)
- orchestrator가 perl 정규식으로 수동 제거(라인 2018 인라인 주석 + 2029~2033 사고잔해 블록주석 삭제)

이후 **모든 후속 배치(7.5 배치1/2/3/3-b, 7.7 재작성 = 5회)에 방지 지시를 매번 수동 주입**해야 했다:
> "제어문자 리터럴·이스케이프 표기를 코드/주석에 절대 타이핑하지 마라. `String.valueOf((char) 7)` 런타임 조립만.
> 작성 후 `Grep` 패턴 `[\x00-\x08\x0B\x0C\x0E-\x1F]`로 자가검증하고 결과를 반환에 포함하라."

주입 후 **5개 배치 전부 오염 0**으로 수렴했다. 즉 **지시가 있으면 안 밟는다.**

### 왜 위험한가 (단순 오타가 아니다)
오염된 파일은 ripgrep이 **binary로 분류해 검색 대상에서 통째로 제외**한다.
이 세션에서 그 파일은 **계획서(SSOT)** 였다 — 이후 모든 7c.2 영향 인벤토리 grep이 그 문서를
무음으로 건너뛸 뻔했다. `file`은 "UTF-8 text"로 보고하는데 `grep`만 binary로 판정하므로
**자각 없이 지나간다**(orchestrator가 `grep -IL .`로 별도 확인해서 잡았다).

### 추정 원인
이 함정은 **이미 문서화돼 있다** — `.claude/rules/package/autopatch/frontend.md`에
`useSubmoduleCommitDiff.ts` cacheKey 사례로 상세 기재(*"이스케이프 표기를 문자로 옮겨적는 시도 자체가 위험 신호"*).
그런데 **`tester-design.md` 계약에는 없다.** 작성자가 규칙의 존재를 모른 채 같은 함정을 밟았다.
frontend.md는 프론트 구현 규칙이라 tester-design이 읽을 이유가 없다.

### 제안 개선 방향
`.claude/agents/tester/tester-design.md`의 RED 작성 규칙(R1~R21 계열)에 신설:

> **R22 — 제어문자는 리터럴로 타이핑하지 않는다.**
> 제어문자가 필요한 케이스(CWE-117 위생처리 검증 등)는 **char 코드값 런타임 조립**만 쓴다:
> `String.valueOf((char) 7)`. 이스케이프 표기를 소스·주석에 직접 적으면 도구 경유에서 **실제 바이트로
> 기록될 수 있다**(실측). 설명이 필요하면 "제어문자(BEL, 코드 7)"처럼 말로 푼다.
> **작성 후 자가검증 필수**: `Grep` 패턴 `[\x00-\x08\x0B\x0C\x0E-\x1F]`(패턴 자체는 정규식이라 안전)로
> 산출 파일을 확인하고 결과를 반환에 포함한다.
> 오염되면 ripgrep이 그 파일을 binary로 무음 제외해 **이후 모든 인벤토리 grep이 조용히 실패**한다.

부가: **대용량 단일 Write 지양**(오염이 대용량 append에서 발생). 뼈대 Write → 케이스별 Edit append 권장.

### 근거
- 이번 세션 7a 산출물 실측: 계획서 라인 2018(인라인 주석 안 NUL+BEL), 2031~2032(DEAD 잔해 2줄)
- 자가신고("3개")와 실측(4바이트) 불일치 — **자가보고 신뢰 불가 사례 추가**
- 방지 지시 주입 후 5배치(배치1/2/3/3-b/7.7재작성) 전부 `Grep` 자가검증 0건
- 선행 기재: `.claude/rules/package/autopatch/frontend.md` "Write 도구로 제어문자(NUL 등)를 표현하려고…" 항목

### 관련 파일
- `.claude/agents/tester/tester-design.md` (R22 신설 대상)
- `.claude/rules/package/autopatch/frontend.md` (기존 기재 — 교차참조 추가 가능)

---

## 관찰만 (개선 후보 아님)

### 7.7 품질게이트가 "테스트가 프로덕션을 지배하는" 오염을 적발했다
SEC-07의 `thrown.getStackTrace()[0].getMethodName() == "assertSubmoduleOriginsAllowed"` 단언 때문에
**프로덕션 소스에 리팩터 금지 주석이 박혔다**(`BaseCacheWorkspace.java:281~282`
*"⚠ 메서드명을 바꾸지 말 것 — SEC-07이 …단언한다"*).

이 결함 클래스는 **컴파일·실행·커버리지를 전부 통과한다.** 게다가 그 단언은 7.6에서 **도달조차 못 해**
(`thrown`이 null이라 앞 라인에서 먼저 실패) GREEN에서 처음 평가될 예정이었다 — developer가 warn+throw를
헬퍼로 추출했다면 **정상 구현인데 원인 불명 FAIL**을 만났을 것이다.

7.7이 유일한 그물이었고 제대로 작동했다. **성공 사례라 규칙 변경 후보가 아니다** — 기록만.

### 세션 중 발견해 제품 백로그로 넘긴 것 (하네스 무관)
- **BL-055**: 테스트 픽스처의 raw NUL이 ripgrep binary 오탐을 유발해 인벤토리에서 영구 무음 제외
  (`GitExportOrchestratorListHeaderTest.java` — 의도적 공격 페이로드라 **제거 금지**, 런타임 조립으로 전환 권고)
- **BL-056**: `.gitmodules`는 있는데 `.url` 매치 0건이면 origin 게이트가 정상 export를 fail-closed 차단
  (BL-051이 고치려던 증상을 다른 조건에서 재발시키는 아이러니)
