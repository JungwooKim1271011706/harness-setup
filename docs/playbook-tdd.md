# Playbook — TDD 합의 구간 (신규기능·고복잡도 트랙 전용)

> **분리 문서** — `orchestrator.md`에서 추출(v3.2.0). 신규기능·고복잡도 트랙에서 사용자 승인 후, developer 호출 전 구간 상세. 해당 트랙 진입 후 orchestrator가 이 파일을 Read한다.
> **버전 동기 대상**: 7a~7.7 시퀀스·게이트·codex 폴백 연동 변경 시 이 파일도 갱신한다. finalizer bump 의식의 "분리 문서 정합성 점검"이 강제. (codex 실패 신호·타임아웃·백스톱은 orchestrator.md `## codex 호출 가드`가 SSOT — 여기서 재서술 안 함.)

---

사용자 승인 후, developer 호출 전에 아래 순서로 TDD 합의를 진행한다.

## 7a∥7b — 테스트 케이스 병렬 산출
- **7a**: tester-design → 케이스A 산출
- **7b**: codex → 케이스B 산출 (rule 경로 주입 필수)
  - codex 실패 시 claude(tester-design) 폴백 (실패 신호 정의·재시도 상한·무한대기 백스톱은 orchestrator.md `## codex 호출 가드`)
- 7a와 7b는 병렬 호출한다.

> codex 미가용 폴백 시 7a∥7b 교차검증은 불성립한다. 산출물에 `⚠ 교차검증 없음 (codex 미사용, 단일 소스)`를 명시하고, 7.7 tester-quality 호출 시 '단일 소스' 컨텍스트를 전달해 더 엄격히 판정하도록 한다.

## 7c — diff 합의
| 구분 | 처리 |
|------|------|
| A∩B (양쪽 동일) | 자동 채택 |
| 차집합 (한쪽에만 존재) | 합집합 기본 채택. 상충하지 않으면 토론 없이 통과. |
| 상호배타 (논리적 충돌) | 사용자에게 판단 위임 |

차집합 토론 상한: 최대 2왕복. 초과 시 합집합 채택.

## 7c.1 — 승인된 패널 major 잠금 (RED 케이스 필수 매핑)

사용자 승인 화면에 노출돼 **승인된** 설계패널 major 항목(비차단이나 완료정의의 일부)을 7c 합의 케이스에 **필수 잠금**한다.
- orchestrator가 승인 major 목록을 추출해 7c 케이스 체크리스트에 주입 — **각 major → 최소 1 RED 케이스** 매핑 강제.
- 7a∥7b 산출이 흐름 diff만 보고 major refinement를 놓치는 누락 방지(major가 RED로 안 실리면 GREEN 통과 후 /review가 blocking 적발 → 재작업).
- 7.7 품질게이트가 이 매핑 커버리지 확인(승인 major 중 대응 RED 없는 항목 = critical 취급, 작성자 반환).

## 7.5 — RED 테스트 작성 (codex, public 행위 기준)

codex가 7c 합의 케이스를 기반으로 RED 테스트를 작성한다.
- 테스트는 **public 행위 기준** (내부 구현 검증 금지)
- **작성자(codex/tester) ≠ 구현자(developer)** 원칙 엄수
- codex 실패 시 tester-design 폴백 (실패 신호 정의·무한대기 백스톱은 orchestrator.md `## codex 호출 가드`)
- codex 호출 시 rule 경로 주입 필수
- **RED 보안/negative 규칙(R1~R8) + 외부 API DTO JSON round-trip 규칙 주입 필수** — codex가 작성자일 때도 `tester-design.md`의 `## RED 보안/negative 테스트 규칙`을 컨텍스트로 전달한다(공허 단언 방어).

## 7.6 — RED sanity (컴파일 + RED 실행 검증)

7.5 완료 후, 7.7 품질게이트 전에 반드시 실행한다. **tester-design은 Bash가 없어 "구성상 RED"만 만들 수 있으므로**, 실제 컴파일·실행을 한 단계 앞에서 확인해 컴파일 깨진 스위트가 7.7을 통과해 8/tester-backend에서야 터지는 것을 막는다.

- 실행 주체: **tester-backend**(Bash 보유 + 테스트 파일 미편집 — 작성자≠검증자 유지). `mvn test-compile` + RED 1회 실행.
- 통과 기준: **① 컴파일 OK** + **② RED가 "올바른 이유로" FAIL**(미구현 도메인 동작에 의한 단언 실패/도메인 예외). 컴파일 에러, 매처 오용(primitive에 `any()`), `@BeforeEach` 팩토리 seam 미사용, `UnsupportedOperationException` 같은 "잘못된 이유"의 FAIL은 **불통과**.
- 처리:
  - 통과 → 7.7 진행.
  - 불통과 → **작성자(codex/tester-design)에게 반환해 재작성** [LOOP n/3, 7.7과 루프 카운트 공유]. 컴파일/셋업 결함 종류를 명시해 반환.
- codex 미가용 폴백(claude 단일 소스)이어도 7.6은 동일 수행(오히려 단일 소스라 더 필요).

## 7.7 — 테스트 품질 게이트 (tester-quality)

7.6 통과 후, developer GREEN 구현 전에 반드시 실행한다.

| 작성자 | 검증자 | 교차 원칙 |
|--------|--------|---------|
| codex (7.5 정상) | tester-quality(claude) 호출 | 작성자≠검증자 |
| claude (codex 폴백) | 오케스트레이터가 `codex` 스킬로 교차 판정 | 작성자≠검증자 |

**rule 경로 주입 필수** (📋 0단계 확정 경로). tester-quality 호출 시 아래 컨텍스트를 전달한다:
- 7c 합의 테스트 케이스 목록
- 7.5 RED 테스트 코드 파일 경로
- 승인된 설계 문서 경로
- rule 경로

**게이트 처리**:
- critical 0건 + 근거 명시 → 통과 → 8 진행
- critical 1건 이상 → **작성자(codex 또는 tester-design)에게 반환해 재작성** [LOOP n/3]
  - 루프 상한: 최대 3회. 초과 시 사용자에게 에스컬레이션.
  - **반환 시 동일 결함 클래스 전수 sweep 지시(첫 루프부터)**: 인용된 케이스만 고치지 말고 **모든 테스트 파일에서 같은 결함 클래스**(예: 공허 예외단언·strict stub 겹침·primitive 매처)를 한 번에 sweep하게 한다. 케이스별로 고치면 검증자가 un-scrutinized 케이스에서 같은 패턴을 재발견해 루프가 낭비된다.
  - **codex 작성분의 소규모 critical 수정(소수 라인)은 codex 재호출로 "전체 파일 재출력"을 요청하지 않는다**: codex가 직전 합의 설계를 자기 기억으로 재생성하며 회귀시킨 사례 관측(2026-06-20: `findAllByAccountId`(목록)→`findByAccountId`(단건), 빈값/모호성 가드·R1(`.isNotInstanceOf`)·바이트동일 메시지 단언 전부 소실). 대신 ① 직전 통과분(또는 첫 산출)을 베이스로 작성자측(tester-design)이 **검증자 지목 라인만 받아쓰기로 직접 적용**(작성자≠검증자 유지 — 검증자는 tester-quality), 또는 ② 재작성 불가피 시 **전체파일 아닌 unified patch-diff만** 요청하고 orchestrator가 직전 합의본과 대조해 회귀 차단. (cross-ref: orchestrator `## codex 호출 가드`.)
- 사용자는 테스트를 승인하지 않는다 — 테스트 품질은 이 게이트가 책임진다(6단계 사용자 승인은 설계 한정).

## 8 — developer GREEN 구현

- developer가 7.5 RED 테스트를 통과시키는 구현 작성
- **테스트 파일 편집 금지 (기계강제)**: developer는 `<module>/src/test/**`를 수정·삭제할 수 없다. PreToolUse 훅 `block-developer-test-edit.sh`가 agent_type=developer-* + 테스트경로 Edit/Write/MultiEdit를 차단(exit 2). 테스트 약화=reward-hacking 방어(백로그 #8, 근거 ImpossibleBench GPT-5 76%). 테스트가 틀렸다고 판단되면 구현 멈추고 **설계결함(DESIGN_MISMATCH)으로 보고** → FAIL 3분기의 설계결함 경로. (알려진 구멍: Bash sed -i 우회는 v1 미차단 — 백로그 #13)
- **public 계약 준수** (co-plan/7c에서 freeze된 시그니처 변경 불가)
- **public 계약 소변경** (파라미터명·반환타입 등 마이너 조정): planner 경량 갱신 후 설계패널 스킵하고 진행
- **구조 변경** (역할·책임 재분배): planner 단계 풀 회귀 (설계패널 재실행 포함)
