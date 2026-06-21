---
title: 폭주(무한루프) 테스트가 surefire 포크 JVM을 무한 점유 → 머신 메모리 고갈
type: gotcha
links: [[surefire-nested-skip]] [[surefire-it-naming-skip]]
updated: 2026-06-21
---

## 증상
`mvn test`가 끝나지 않고 포크된 surefire 테스트 JVM이 수 GB(실측 5GB)를 점유한 채 4+코어를 풀가동한다. 머신 메모리가 90%까지 차고, 세션이 끝나거나 잊혀도 그 JVM이 계속 살아 메모리가 "안 빠진다". 여러 번 쌓이면 머신이 마비.

실측(2026-06-21): `feature-1-autopatch-cli-export`의 `MetaCommitRangeSelectorTest.branchSwitch_branchesFails_*`가 13분+ 안 끝남. jstack 결과 `main` 스레드가 RUNNABLE로 `MetaCommitRangeSelector.handleBranchSwitch:284 → GitLabApiClient(Mock).branches()`를 무한 반복, G1 Conc GC 스레드 3개가 각 13.5분 CPU 풀가동(= 무한 할당 → GC 죽음나선).

## 진짜 원인
제품 코드의 무한루프(목킹된 의존성이 실패를 반환할 때 종료조건 없는 재시도/폴링)가 객체를 끝없이 할당 → 힙이 차 G1이 쉬지 않고 돌며(높은 CPU) JVM이 종료도 OOM도 못 하고 영원히 churn. **surefire에 per-fork 타임아웃이 없으면** 이 폭주 포크를 아무도 안 죽인다. tester의 스코프가드("수십 분/수백 클래스면 중단")는 **단일 테스트 무한루프를 못 잡는다** — 폭주는 클래스 1개라 "수백 클래스" 신호가 안 뜬다.

## 회피 (하네스 = fail-fast 강제)
mvn 호출에 타임아웃을 항상 붙여 폭주를 유한 시간에 끊는다. surefire가 포크를 죽이면 부모 maven은 BUILD FAILURE로 정상 종료 → tester의 trap이 pom을 원복(고아·잔재 없음).

- **단위/변경검증 (tester-backend)**: `-Dsurefire.timeout=600`(per-fork 백스톱, 모든 JUnit 버전에 작동) + `-Djunit.jupiter.execution.timeout.default=120s`(Jupiter per-test, 단일 테스트 무한루프를 120s에 끊음; JUnit4면 무시). 단위테스트는 빠르므로 둘 다 안전.
- **전체회귀 (tester-runtime)**: `-Dsurefire.timeout=1800`(per-fork 30분)만. 전체회귀는 정당한 통합테스트가 느릴 수 있어 Jupiter per-test 타임아웃은 **오탐 위험**이라 안 씀. 정상 전체스위트가 30분 초과면 값 상향.
- **힙 캡(-Xmx) 강제 안 함**: `-DargLine`은 프로젝트 argLine(javaagent·기존 -Xmx 등)을 덮을 위험. 폭주 힙은 루프의 *증상*이라 타임아웃 종료 시 회수된다 → 타임아웃만으로 충분.

값 매핑: `-Dsurefire.timeout` = surefire `forkedProcessTimeoutInSeconds`(포크 전체 수명). `-Djunit.jupiter.execution.timeout.default` = JUnit Platform config(시스템 프로퍼티로 포크에 전달, 테스트 메서드별).

## 응급 대응 (이미 폭주 중일 때)
JDK `jps -lvm`로 폭주 JVM 식별(surefirebooter.jar) → `jstack <pid>`로 어느 테스트인지 핀포인트(main 스레드 스택) → 부모 maven + 포크 JVM kill로 메모리 회수. CIM(`Get-CimInstance Win32_Process`)은 이 PC에서 느려 행 → `jps`/`jstack`이 빠름.

## 하네스 적용
- `agents/tester/tester-backend.md` ## 핵심 규칙 + ## 단위테스트 실행 — per-fork 600s + Jupiter per-test 120s.
- `agents/tester/tester-runtime.md` ## JUnit 통합/전체회귀 실행 — per-fork 1800s.
- 근원: JDK 메모리 미반환 진단 세션(2026-06-21). 제품 버그(handleBranchSwitch 무한루프)는 제품 담당 세션에 별도 위임. 하네스는 "폭주 테스트 fail-fast"만 책임(제품 버그 유무와 무관하게 머신 보호).
