---
source_session: pom-system-scope-auto-remove 트랙 (TDD 풀사이클 + 실 러너 E2E + 브랜치 머지)
project: DEVUNIT-authpatch_draft
date: 2026-08-04
signals: 5 (후보 4 + 관찰 1)
---

# 하네스 자가 점검 — 2026-08-04 (autoPatch / pom-system-scope-auto-remove)

한 트랙(설계승인 → TDD 7a~8 → 변경검증 → /review ∥ /codex → /cso → 워크스루 → finalizer →
실 러너 E2E → 브랜치 머지)에서 관측된 운영 고통 5건. 후보 4 + 관찰 1.

---

## 후보 1 — RED sanity(7.6)가 "미구현 FAIL"과 "픽스처 깨짐 FAIL"을 구분하지 못한다

**문제(증상)**:
7.6 RED sanity는 "RED가 실제로 FAIL하는가"만 판정한다. 그런데 FAIL에는 두 종류가 있다.
① 구현이 없어서 나는 정상 FAIL(= RED의 목적)
② 픽스처 자체가 깨져서 나는 FAIL(= 결함)
7.6은 **둘 다 "RED 정상"으로 통과시킨다.** 실측: batch C의 2건이 ②였고 GREEN(8단계)에서야 발각됐다.
- `FW1`: 픽스처가 `Files.writeString(tocServerPom, ...)`을 빠뜨려 대상 파일이 존재하지 않았다.
- `T2`: `thenReturn(List.of())`로 스텁해 `createHubSettingsXml()`에 **도달 자체가 불가능**했다.

**비용**: developer는 `src/test/**` 편집이 hook으로 차단돼 있어 스스로 고칠 수 없다 →
tester-design 왕복 **1라운드 추가**. GREEN 구현이 정상이었음에도 "구현 결함"으로 오분류될 뻔했다.

**추정 원인**:
7.6의 판정식이 **exit code(FAIL 여부) 단일 축**이다. FAIL의 *이유*를 보지 않는다.
①과 ②는 실패 메시지가 구조적으로 다르다 — ①은 단언 실패(expected/actual 비교),
②는 NPE·NoSuchFileException·`UnnecessaryStubbing`·"wanted but not invoked" 등 **인프라 계열 예외**다.

**제안 개선 방향**:
7.6에 "FAIL 사유 분류" 축을 추가한다. RED 케이스별 실패 메시지가
**단언 실패(AssertionError/`expected:<X> but was:<Y>`) 계열이면 ① 정상 RED**,
**인프라 예외(NPE / NoSuchFileException / FileNotFound / Mockito stubbing 계열) 계열이면 ② 픽스처 의심**
으로 판정하고, ②가 1건이라도 있으면 7.6 통과 전에 작성자에게 반환한다.
"RED는 *올바른 이유로* 실패해야 한다"를 7.6 계약에 명문화.

**근거**: 이번 트랙 batch C 2건(FW1, T2). 발각 시점 = 8 GREEN. 추가 비용 = tester-design 왕복 1라운드.
**관련 파일**: `.claude/docs/playbook-tdd.md`(7.6 절), `.claude/agents/tester-backend.md`

---

## 후보 2 — 승인 문서의 **내부** 모순을 보는 게이트가 없다

**문제(증상)**:
설계패널(4라운드) + codex 형제 + 사용자 승인을 **전부 통과한** 계획서에 내부 모순 2건이 남아 있었고,
둘 다 **구현 중에** 발견됐다.
- ①「③ ERROR 티어에 systemPath를 렌더하는가」가 계획서 두 절에서 상충 → 사용자 A안 결정으로 해소
- ②「3단 메시지 전부 개행 미포함」의 적용 범위가 **주입 필드값**인지 **렌더러 자신의 구조적 개행**까지인지 상충

**비용**: ①은 사용자 에스컬레이션 1회(결정 대기), ②는 orchestrator 자체 판정 + 계획서 2곳 편집.
구현 도중 SSOT가 흔들려 RED 케이스 재확인이 필요했다.

**추정 원인**:
게이트는 **문서 간 정합**(계획 ↔ 코드, 계획 ↔ 룰)은 본다. 그러나
**한 문서 안의 원칙 ↔ 결정문 ↔ 기각한 대안 ↔ 샘플 출력**이 서로 모순되지 않는지는 **아무도 안 본다.**
설계패널 페르소나는 각자 자기 렌즈(eng/cso/design/devex)로 보므로, 절과 절 사이의 자기모순은
"내 렌즈 밖"으로 빠진다. codex도 계획 전문을 읽지만 지시가 "결함 찾기"라 내부 정합 전수대조는 안 한다.

**제안 개선 방향**:
설계패널 게이트에 **내부 정합 렌즈 1개**를 추가하거나(페르소나 신설 없이 eng 프롬프트에 축 추가),
사용자 승인 화면 직전에 orchestrator가 계획서의
**「결정문 ↔ 샘플/예시 출력 ↔ 금지사항」 3자 대조**를 1회 수행한다.
특히 **렌더 포맷·메시지 문자열처럼 계획서가 샘플을 직접 적어 놓은 항목**은 샘플과 결정문이
어긋나기 쉬우므로 우선 대조 대상.
- 참고: orchestrator.md `## 사용자 의사결정 요청 형식`에 이미
  "승인 문서를 근거로 옵션을 낼 때 그 문서 내부 모순을 먼저 확인한다"가 있으나,
  이는 **의사결정 요청 시점**의 규칙이라 **게이트 시점**에는 발동하지 않는다. 그 규칙의 게이트판이 없다.

**근거**: 이번 트랙 계획서 `docs/features/2026-08-03-pom-system-scope-auto-remove.md` 내부 모순 2건.
4라운드 패널 + codex를 통과한 문서였다.
**관련 파일**: `.claude/agents/orchestrator.md`(설계패널 게이트 절), `.claude/workflows/design-panel.js`

---

## 후보 3 — `docs/backlog.md` BL 번호가 병렬 브랜치에서 필연 충돌한다

**문제(증상)**:
BL-XXX 번호가 병렬 브랜치에서 충돌. 이번에 **2회 실측 + 1회 예고**.
- **실측 1**: `feature-monitor-test-1` 머지 시 BL-040/041 정면 충돌.
  HEAD 측 9건(040~048)을 **042~050으로 수동 리넘버링**해 해소.
  부수 갱신: backlog 내부 상호참조 5곳 + 계획서 인용 1곳.
  유입 측을 못 옮긴 이유 = 그쪽 번호가 **소스 3파일**
  (`MetaGitlinkResolver.java:166`, `RangeDirectionGuard.java:130/169`, `MetaGitlinkResolverTest.java:447`)
  + 문서 ~25곳에 이미 인용돼 있었다.
- **실측 2(예고)**: `.claude/tmp/plan-loop3-full-backup.md:1271`의 solution-config-admin 트랙 계획서가
  BL-040~049를 자기 번호로 이미 예약 → 머지 시 **3번째 충돌 확정**.

**추정 원인**:
planner는 `docs/backlog.md`에 **Edit 권한이 없다**(Write 전용 — 1000줄+ 원장 전체 재전사를 회피하려면
append가 필요한데 그 도구가 없다). 그래서 계획 단계에서 "마지막번호+1"을 **추측으로 예약**하고,
실제 append는 나중에 finalizer가 한다. **예약 시점과 확정 시점 사이에 다른 브랜치가 끼어들면 충돌**한다.
브랜치 병렬 개발이 표준인 이 프로젝트에서는 **구조적으로 불가피**하다.
악화 요인: 번호가 소스 주석·테스트 주석·ADR에까지 인용되면 사후 리넘버링이 사실상 불가능해진다.

**제안 개선 방향**:
1. **계획서는 placeholder만 쓴다** — `BL-NEW-1`, `BL-NEW-2`. 실번호는 finalizer가 append 시점에 배정.
2. finalizer가 append할 때 placeholder → 실번호 치환을 **계획서·ADR·소스 주석까지 일괄** 수행.
3. (보강) 소스 주석에 BL 번호를 박기 전 "이 번호가 이미 backlog에 append됐는가"를 확인하는 가드.
   append 전 번호를 소스에 박으면 리넘버링 자유도가 사라진다 — 이번 유입 측이 그 상태였다.

**근거**: 이번 세션 머지 충돌 해소 실작업(수동 리넘버링 9건 + 상호참조 6곳).
`plan-loop3-full-backup.md:1271`이 3번째 충돌을 예고.
**관련 파일**: `.claude/agents/planner/*.md`, `.claude/agents/finalizer.md`,
`.claude/agent-memory/orchestrator/project_backlog_md_bl_convention.md`

---

## 후보 4 — 병렬 tester 배치가 Maven `target/`을 공유해 경합한다

**문제(증상)**:
tester 배치를 병렬로 위임하면 같은 모듈의 Maven `target/` 디렉터리를 공유해 경합.
결국 순차로 내려야 했다 — 병렬 위임의 이득이 소멸.

**추정 원인**:
orchestrator의 병렬 위임 규칙은 **의미적 의존**(한쪽 산출이 다른쪽 입력 가정을 바꾸나)만 본다.
**물리적 자원 경합**(같은 빌드 산출 디렉터리·포트·DB·락파일)은 판정 축에 없다.
`isolation: 'worktree'` 옵션이 있으나 이 축을 위한 것으로 안내돼 있지 않다.

**제안 개선 방향**:
orchestrator `## 상호의존 작업 병렬위임 금지` 절에 **자원 경합 축**을 추가한다 —
"두 작업이 **같은 빌드 산출 디렉터리(`target/`·`dist/`·`node_modules/.vite`)·포트·DB·락파일**을 쓰나?"
1문 자가체크. 쓰면 순차 또는 `isolation: 'worktree'`.
현재 규칙은 "파일 비충돌 ≠ 의미 독립"까지만 말하고 **"의미 독립 ≠ 자원 독립"**은 빠져 있다.

**근거**: 이번 트랙 tester 배치 병렬 시도 → `target/` 경합 → 순차 전환.
**관련 파일**: `.claude/agents/orchestrator.md`(`## 상호의존 작업 병렬위임 금지` 절)

---

## 관찰(후보 아님) — 세션 한도 사망 3회

TDD 7a/7.5 구간에서 서브에이전트(R2 + stub 작성 에이전트)가 **in-flight 상태**로 세션 한도에 걸려 사망.
체크포인트 재작성 + 부분 산출 조사(disk state 검증)로 복구했고 **작업 손실은 없었다.**

**후보에서 제외하는 이유**: 토큰 한도는 외부요인 — 하네스 레버리지가 작다(harness-check Step 2 규칙).

**다만 기록해 둘 것**: 외부요인인 것은 *한도 자체*이고, *복구 절차*는 하네스 소유다.
orchestrator.md에 `### 세션 끊김 후 복구`가 있으나 **설계패널 백그라운드 워크플로 전용**이다.
일반 서브에이전트(tester-design·developer 등) in-flight 사망에는 대응 절차가 없어 **매번 수동 조사**했다.
3회/1트랙은 1회성으로 보기 어려우므로, 재발이 누적되면 그 절차의 일반화를 후보로 승격할 것.
