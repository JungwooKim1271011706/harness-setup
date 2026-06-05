# ADR-0002: 변경검증/전체회귀 분리 + 전체회귀 부채 기반 주기화

## 상태

Accepted (2026-06-05)

---

## 맥락

하네스는 모든 구현 뒤 tester-runtime을 무조건 통과시켰다(orchestrator.md:28). tester-runtime은 매번 전체회귀(`mvn test -DskipTests=false`, 전체 스위트)를 1회 수행한다(tester-runtime.md:22-29).

제품 코드베이스 실측:

| 항목 | 규모 |
|------|------|
| main java 파일 | tocFramework 920 / tocProcess 625 / tocServer 167 (계 1712) |
| 테스트 파일 | 27개 (framework 2 / process 14 / server 11) |
| Spring context 로드 테스트 | 13개 |
| DB 연결 테스트 | 14개 |
| 모듈 의존 | tocServer → tocFramework + tocProcess (빌드 시 전체 컴파일 체인 강제) |

문제: 1~2줄 수정에도 1712파일 컴파일 체인 + Spring context 13개 로드 + DB 14연결 통합테스트가 매번 풀로 돈다. 테스트 개수(27)는 적지만 성격이 통합(Spring+DB)이라 단위테스트 대비 비용이 크다. "통합테스트가 너무 자주 잡힌다"는 체감의 근원.

원인 3중첩:
1. orchestrator.md:28이 모든 구현 뒤 tester-runtime을 조건 없이 강제
2. 3개 도메인 루트(:245-247)가 전부 tester-runtime을 통과
3. tester-runtime이 잡히면 항상 변경 스코프 무시하고 전체 실행

추가로 단순수정 트랙 정의("tester-* 경량 종료")와 :28(tester-runtime 강제)이 모순.

---

## 결정

"변경검증"(매 변경)과 "전체회귀"(주기)를 분리하고, 전체회귀를 부채 기반 트리거로 옮긴다.

### D1. 변경검증 / 전체회귀 분리
- 변경검증 = 매 변경마다 tester-backend/frontend가 변경 스코프(직접 호출자 1홉 + planner 회귀범위)만 검증. **이미 구현돼 있음**(tester-backend.md:30, :121-134) — 신규 구축이 아니라 tester-runtime을 떼어내는 재배선.
- 전체회귀 = tester-runtime이 전담. 매 구현 강제 체인에서 **완전히 제거**.

### D2. 사이드이펙트 산정 = 1홉 + planner 수동, 자동화 안 함
직접 호출자 1홉 + planner가 feature 문서에 적는 회귀범위. 공유테이블 자동매핑·자동 N홉 호출그래프는 만들지 않는다(LLM grep 추적 = 부정확+거짓확신=과설계). 못 잡는 간접·DB 결합은 주기 전체회귀가 포획.

### D3. 전체회귀 트리거 = 소프트 부채 안내 (하드 게이트 아님)
대안 A(하드 게이트: 부채 임계 시 커밋 차단) vs B(소프트 안내). **B 채택**. 로컬 1인 하네스라 강제 게이트는 자기 조언을 자기가 무시하는 구조 = 마찰만 증가. push가 수동+사용자 승인이라 회귀가 명시 push 없이 origin 못 감(흐름 밖 안전망 존재).

### D4. 부채 안내 = 비차단 단방향 통지
finalizer가 커밋 직전 완료 리포트에 텍스트 1블록 출력 후 그냥 진행. AskUserQuestion·멈춤·답 대기 금지. 커밋은 부채 무관 무조건 완료. 이 불변식이 깨지면 소프트 안내가 하드 게이트로 변질.

### D5. 2트리거 (느슨)
- 커밋 ≥ 5 (N=5) — 누적량. 전체회귀가 무거워 자주 안 돌리려는 의도.
- tocFramework 변경 = 즉시 격상, 리셋 전까지 유지.
누적 도메인 카운트 트리거는 모듈이 3개뿐이라 framework 룰과 중복 → 폐기.

### D6. 기동 2층 (L1/L2)
- L1 컨텍스트 기동(Spring context 로드) = tester-backend가 변경 스코프에 context 테스트 있으면 보고, 없으면 컴파일까지(공백 인정).
- L2 풀 런타임 기동(Tomcat WAR + HTTP) = 무겁고 환경의존 → 전체회귀 부채 트리거 또는 사람 검증(옆집아저씨 템플릿 재사용, oracle=요구사항)으로 미룸.

### D7. state 파일
`~/.gstack/projects/{slug}/regression-debt.json` (기존 체크포인트 패턴, repo 밖 비공유). finalizer가 커밋 시 갱신, tester-runtime이 전체회귀 PASS 시 리셋. **{slug} 산정은 `eval "$(~/.claude/skills/gstack/bin/gstack-slug 2>/dev/null)"`으로 도출한 `$SLUG`(리뷰모드 체크포인트와 동일 메커니즘)**. finalizer·tester-runtime 양쪽이 같은 명령을 쓰므로 slug가 일치한다(다르면 부채 리셋 실패).

---

## 결과

### 긍정
- 1~2줄 수정이 전체 컴파일 체인 + Spring/DB 통합테스트를 안 탐 → 체감 부하 대폭 감소.
- 단순수정 트랙 :28 모순 자동 소멸.
- 변경별 검증은 유지(tester-backend/frontend가 기동 L1·UI 스모크 이미 담당).
- 전체회귀는 안전망으로 부채 임계·framework 변경·수동 시에만.

### 부정 / 수용한 위험
- **회귀 탈출 가능**: 소프트 안내라 사용자가 무시하면 미검 회귀가 커밋에 들어갈 수 있음. push 수동 승인이 마지막 방어선. 수용.
- **단순수정 oracle 구멍**: feature 문서 없어 사람 L2 oracle 빈약. 단순수정은 부채가 거의 안 쌓여 L2가 안 떠 위험 작음. 수용.
- **L1 기동 공백**: 변경 클래스에 context 테스트 없으면 bean wiring 미검. 컴파일만 통과. 수용(L2/부채가 보완).
- **DB 의존**: context/통합 테스트가 라이브 MariaDB 필요 — 환경 없으면 검증 자체가 환경FAIL. 이번 재설계와 독립한 기존 이슈로 분리.

---

## 대안

- **A. 하드 게이트** (부채 임계 시 커밋 차단): 안전 최대지만 1인 로컬에 마찰 과다. 기각.
- **시간 기반 주기**(nightly): 로컬 대화형 하네스에 cron 개념 없음. 부채(변경량) 기반이 자연스러움. 기각.
- **자동 영향분석**(N홉 그래프/테이블 매핑): 과설계, 거짓확신. 기각.
