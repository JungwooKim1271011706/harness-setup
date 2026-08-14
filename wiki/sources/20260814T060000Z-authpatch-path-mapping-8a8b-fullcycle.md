---
source_session: 경로매핑 DB화 1차 트랙 — 7.7 잔여 → 8a 스텁 → 7.6 RED sanity → 8b GREEN → 리뷰2소스 → CSO → 워크스루 → 커밋
project: DEVUNIT-authpatch_draft (worktree feature-solution-expr-1)
date: 2026-08-14
branch: feature-solution-expr-1
commits: 1c84a8a8 (코드+설계문서 126파일) / c3cfd4aa (docs 후속)
detected_by: orchestrator post_commit 자가점검
signals: 서브에이전트 세션한도 사망 3건 · @Nested 무음스킵 6클래스 · 프로브 오측정발 회귀 1건 · 정정 라운드 7회
---

# 하네스 자가 회고 — 경로매핑 DB화 1차 (제품코드 0줄 → 커밋 완주)

> 이 트랙은 **계획서만 2400줄, 코드 0줄** 상태로 시작해 8a 스텁으로 컴파일을 처음 열었다.
> 그 순간 **7.5·7.7 게이트를 전부 통과해 살아남아 있던 테스트 결함이 무더기로 드러났다.**
> 아래 후보 중 다수가 "정적 게이트가 구조적으로 못 보는 것"이라는 같은 뿌리를 갖는다.

---

## 후보 S1 — 장시간 서브에이전트가 digest 쓰기 직전에 죽는다 (우선순위: 높음)

**증상**: 이 세션에서 서브에이전트 **3개가 세션 한도로 사망**했고, **전부 작업은 완주했는데 digest를 못 썼다**.
- B3 국소재확인(직전 세션) · B 5건 정정 · 재-7.6 백엔드
- 재-7.6은 `mvn` 완주 + surefire 48클래스 리포트까지 디스크에 남기고 죽었다 → orchestrator가 리포트를 직접 집계해 판정을 **회수**했다(A/B 분류, 실패유형 분포까지 복원 가능했다).

**추정 원인**: 위임 계약이 "반환은 digest"만 요구하고 **중간 산출 영속화를 요구하지 않는다.** 긴 작업(빌드·전량 테스트·대량 편집)은 마지막에 한 번 쓰는 구조라 사망 시 전량 유실처럼 보인다.

**제안 개선**: 위임 프롬프트 표준에 1줄 (또는 각 tester/developer md `## 반환 계약`에):
> **긴 작업은 단계마다 중간 결과를 산출 파일에 먼저 Write하고 진행한다.** 반환 digest는 그 파일의 요약이다.
> 세션 한도·API 오류로 죽어도 orchestrator가 디스크에서 회수할 수 있어야 한다.

⚠ 실측상 **이 지시를 넣은 뒤 발사한 에이전트는 사망 시에도 회수 가능했다.** 넣기 전 2건은 orchestrator가 surefire/mtime을 뒤져 복원했다.

**부가**: 사망 판정 시 **디스크 완주 판정 3단계**(`playbook-delegation.md`)가 실제로 값을 했다. 다만 이번에 **내 실측 판정이 2건 뒤집혔다** — mtime + 부분 grep으로 "완료로 보임"이라 판정한 항목 2건이 실제로는 미해소였고, 재발사한 에이전트가 소스 추적으로 반증했다.
→ **보강**: "mtime·부분 grep은 완주 판정 근거가 아니다. 항목별 *변경된 그것*을 확인하거나, 판정을 재발사 에이전트에 넘겨라."

**관련 파일**: `.claude/agents/tester/*.md`, `.claude/agents/developer/*.md`, `.claude/docs/playbook-delegation.md`

---

## 후보 S2 — `-Dtest` 클래스 지정이 `@Nested` 전용 클래스를 무음 0건 실행한다 (우선순위: 높음)

**증상**: 이 세션에서만 **6클래스**가 무음 스킵됐다.
- 1회차: `ZipPatchHelperTest`·`SvnConnectorCountRegressionTest`·`SvnConnectorPathAccumulationTest` **완전 0건**(outer에 `@Test` 0개, 전부 `@Nested` 안) + `GitConnectorTest`(1/11)·`AutoPatchCommandsExportGitBranchTest`(3/7) **부분 실행**
- 2회차: `Cm9FileHandlerDeployPathTest`(전 메서드가 5개 `@Nested` 안) 추가 발견
- 4회차: 65클래스 지정 → **58 실행**(패키지명 오기 6 + 위 1)

**전부 tester가 스스로 잡아 재실행**했지만(surefire 리포트 수 대조), **안 잡았으면 「돌렸다고 믿은」 상태로 게이트를 통과**했다. 이건 무음 부분실행 방어의 정확히 그 구멍이다.

**추정 원인**: `orchestrator.md`가 "회귀 스코프는 명시 클래스 목록으로 위임하고 tester 보고의 실행 클래스 집계와 대조하라"까지는 말하는데, **`@Nested` 때문에 지정해도 0건이 되는 메커니즘**을 모른다. 그래서 orchestrator는 목록을 정확히 줬고 tester도 정확히 받았는데 실행이 비었다.

**제안 개선**: tester-backend md(또는 orchestrator 변경검증 절)에:
> `-Dtest=` 로 클래스를 지정하기 전, 대상에 `@Nested`가 있는지 **전수 grep**하라. outer 클래스에 `@Test`가 0개면
> **outer 이름만으로는 0건 실행된다** — `Outer$Nested` 형태로 명시 포함해야 한다.
> 실행 후 **지정 클래스 수 ↔ surefire 리포트 생성 수를 대조**해 보고한다(불일치는 무음 스킵 신호).

**관련 파일**: `.claude/agents/tester/tester-backend.md`, `.claude/agents/orchestrator.md`

---

## 후보 S3 — orchestrator가 서브에이전트의 "실측했다"는 수치를 교차검증 없이 계약에 반영했다 (우선순위: 높음 · orchestrator 자신의 결함)

**증상**: 1회차 검증 tester가 프로브를 돌려 `replaceAll(n) = n+5`로 **실측 보고**했다. orchestrator가 그걸 사실로 받아 "주석의 `2n+6`은 과대추정"이라 판정하고 **테스트 계약(n=80,000 → 150,000)을 바꾸라고 지시**했다.
2회차 재측정 + codex 독립검증(9.5/10 일치): **`2n+6`이 맞다.** 1회차 프로브가 오측정이었다.
결과: n=150,000이면 `replaceAll` 단독 300,006 > 예산 200,000이라 **독립/공유 무관하게 항상 INVALID** → 그 케이스의 **판별력이 통째로 붕괴**했고 신규 FAIL로 나타났다. 원래 값이 이미 정확했다.

**뼈아픈 점**: orchestrator는 이 세션 내내 서브에이전트에 **"자기보고는 검증 대상"·"분모를 요구하라"**를 강제했다. 그런데 **"실측했다"는 숫자에는 그 잣대를 안 댔다.** 산문 주장과 수치 주장을 다르게 취급했다.

**제안 개선**: `orchestrator.md` 산출 수신 계약 또는 §0④에:
> **서브에이전트의 "실측" 수치도 자기보고다.** 그 수치로 **계약·상수·기대값을 바꾸려면** ① 독립 재측정 1회 또는
> ② 기존 문서값과 불일치 시 **기존값 우위**(문서값은 이미 게이트를 통과한 것이다)를 적용한다.
> 특히 **기존 주석·문서가 명시한 산식을 뒤집을 때**는 교차검증 없이 진행하지 마라.

**근거**: 라운드 1회 낭비 + 회귀 1건. codex 교차검증이 있었기에 2회차에 잡혔다.

**관련 파일**: `.claude/agents/orchestrator.md`

---

## 후보 S4 — `red-baseline.sh`의 skip마커 정규식이 Spring 프로퍼티에 오탐한다 (우선순위: 중)

**증상**: 워크스루 3.5 최종 대조에서 **`skip마커 +1`**이 떴다. 정체는
`WebPathMappingControllerRoutingAuthIntegrationTest:27`의 `"spring.shell.interactive.enabled=false"` —
`@SpringBootTest` 컨텍스트에서 Shell 인터랙티브를 끄는 **프로퍼티**지 테스트 비활성화가 아니다.
스크립트 `SKIP_RE`의 `enabled[[:space:]]*=[[:space:]]*false`가 걸렸다.

**왜 위험한가**: 이 저장소는 **계획서가 `@SpringBootTest` 실DB 규약으로 그 프로퍼티를 못박아 뒀다**(`@DataJpaTest` 금지 → `@SpringBootTest(classes=…, properties="spring.shell.interactive.enabled=false")`). 즉 **규약을 지킬수록 오탐이 늘어난다.** 오탐이 상시화되면 진짜 `@Disabled` 신호가 묻힌다.

**제안 개선**: `.claude/scripts/red-baseline.sh`의 `SKIP_RE`에서 범용 `enabled\s*=\s*false`를 제거하고
**TestNG 형태로 좁힌다**: `@Test\([^)]*enabled[[:space:]]*=[[:space:]]*false`.
Spring/Node 계열 설정 문자열(`*.enabled=false`)은 전 생태계에 흔해 이 패턴은 구조적으로 오탐한다.

**관련 파일**: `.claude/scripts/red-baseline.sh`

---

## 후보 S5 — 실행 중인 에이전트가 있을 때의 워킹트리 스냅샷은 과도상태다 (우선순위: 중)

**증상**: code-reviewer가 `pom.xml.harnessbak` 잔여를 informational로 지적했고, orchestrator가 `ls`로 **실재를 확인**했다(10,957바이트). 그런데 바로 다음 명령에서 **파일이 사라졌다** — 백그라운드에서 돌던 tester의 `trap` 원복이 두 명령 사이에 발화한 것이다.
orchestrator가 그 사이 **"tester 자기보고가 반증됐다"고 판정했다가 철회**했다. tester의 정리는 정상 작동 중이었다.

**제안 개선**: `orchestrator.md` 디스크 검증 절에 1줄:
> **백그라운드 에이전트가 실행 중이면 워킹트리는 과도상태다.** 잔여물·청결 판정은 **모든 에이전트 종료 후**에 하거나,
> 최소 2회 시점을 두고 대조하라. 1회 스냅샷으로 "잔여물 있음/자기보고 반증"을 판정하지 마라.

**근거**: 실측 1건(위). 2회 확인이 오판을 막았다.

**관련 파일**: `.claude/agents/orchestrator.md`

---

## 후보 S6 — wiki: mvn 2프로세스 동시 실행이 `@ResourceLock`을 무효화한다

**증상**(developer 자가발견): 두 mvn 프로세스를 동시에 띄우면 `@ResourceLock`/`SAME_THREAD`가
**프로세스 간에는 무효**라 `DuplicateKeyException`·MockMvc 빈 누락 등 **산발적 DB 오염**이 난다.
테스트 DB는 하나뿐이라 **워크트리를 나눠도 안 풀린다**.

**왜 wiki인가**: orchestrator.md의 자원 경합 축은 `target/`·포트·락파일을 말하는데, **실DB 공유가 더 위험한 축**이고 워크트리 분리로도 해결이 안 된다(그 규칙이 제시한 `isolation:'worktree'`가 여기선 무효).

**제안**: wiki 페이지 + `orchestrator.md` 자원 경합 축에 "**공유 테스트 DB**는 워크트리 분리로 안 풀린다" 1줄.

---

## 후보 S7 — wiki: JLine dumb-terminal 미부착 시 `@SpringBootTest`가 5분 무한대기

**증상**: tester가 `-DargLine="-Dorg.jline.terminal.provider=dumb"` 없이 `@SpringBootTest`를 돌려
`SolutionRuleSnapshotHolderCaseSkewTest`에서 **300s 타임아웃**(무한대기 재현). 부착 후 정상 완주(23.5s).
`trap`이 SIGTERM으로 surefire fork까지 정리해 고아 프로세스는 안 남았다.

**제안**: wiki 페이지(기존에 유사 항목 있으면 통합). tester md 실행 규약에 상시 부착 권고.

---

## 잘 작동한 것 (규칙화 불요 — 축소 금지 근거)

- **8a 스텁 라운드가 결정적이었다.** 컴파일을 열자 26건짜리 헬퍼 버그(`types[i]==long.class ? currentTimeMillis() : 0` → JLS 15.25 이항 승격으로 **항상 long** → `int` 필드에 `Long` 박싱 → `argument type mismatch`)가 드러났다. **7.5·7.7을 전부 통과해 살아남아 있던 것**이고 정적 판정으로는 불가능했다.
- **워크스루 3.5 RED 기준선 대조**가 두 번(중간·최종) 돌아 삭제단언 20건을 전건 판정했다. 「그 축을 지금 누가 보는가」 기준이 **개수 기반 오차단**을 막았다(`CmPathMappingYmlConfOrderTest` 6건 삭제는 축 이관이었고 검증 지점이 1→2로 **증가**했다).
- **교차검증 2소스**: codex critical 1 + major 1 ↔ code-reviewer blocking 0 + major 1. **codex 2건은 코드대조로 기각**(전제 미도달·설계가 이미 방어), **code-reviewer major 1건은 채택**(ReDoS 방어 누수). 한쪽만 돌렸으면 채택분을 놓쳤거나 기각분에 라운드를 태웠다.
- **developer 신고자 우위**가 또 유효했다. 8b 배치1이 FAIL 32건을 "전부 테스트 결함"이라 신고했고, orchestrator가 지배 원인(26건)을 직접 코드대조해 **맞음을 확정**했다.
- **sweep 분모 강제**가 실제로 값을 했다. `(.*)` 무앵커 정규식을 한 파일만 고쳤다가 다음 라운드에 3파일에서 재발 → 분모 요구("13개 대조, 3 수정, 10 무해")로 재발 차단. E-1 협력자 미스텁 sweep에서도 **헬퍼 밖 독자 given 1건**을 추가 포착했다.
- **소비자/dev clone 판별식 3단계**가 오판을 막았다. ①만 봤으면 basename이 `.claude`가 아니라 dev clone으로 오판했을 것 — ②(`$ROOT/.claude/.git` 존재)에서 소비자로 확정됐다.
