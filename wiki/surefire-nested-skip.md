---
title: Surefire 2.22.2가 -Dtest 격리 실행에서 JUnit5 @Nested를 조용히 스킵
type: gotcha
links: [[windows-path-jq]]
updated: 2026-06-18
---

## 증상
`mvn test -Dtest=ClassName` 으로 특정 테스트 클래스만 격리 실행하면 PASS가 뜨는데, 정작 그 클래스의 `@Nested` 내부 클래스 케이스들은 **실행되지 않는다**. Surefire는 "Tests run: N"에서 그 케이스들을 빼고 집계하면서 **에러 없이 통과**시킨다.
→ developer가 격리 PASS만 보고 **거짓 GREEN**을 보고 → GREEN 한 사이클 낭비, `/review`에서야 미실행 발각.

## 진짜 원인
maven-surefire-plugin **2.22.2**의 `-Dtest=클래스명` 단일 클래스 필터는 JUnit5(Jupiter) `@Nested` 내부 클래스를 매칭 대상에서 누락한다(실패가 아니라 **무음 스킵**). 필터 없는 전체 실행(`mvn test`)에서는 정상 수집된다. 즉 "격리 실행 PASS"와 "전체 실행 PASS"가 같다는 암묵 가정이 깨진다.

## 회피 (둘 중 하나)
1. **전체 실행**: `mvn -o test` (오프라인, 필터 없음) → Tests run/Failures/Errors 수치로 GREEN 판정.
2. **@Nested 명시 포함**: `-Dtest='클래스명$Nested클래스명'` (또는 `-Dtest='클래스명*'`)으로 중첩 클래스를 매칭에 넣는다. 쉘에서 `$`는 작은따옴표로 감싸 리터럴 처리.

**격리(`-Dtest=클래스명`) PASS 단독으로 GREEN/완료 판정 금지.** 신규·수정 테스트의 GREEN 근거는 전체 실행 수치 또는 `$Nested` 포함 실행으로 제시한다. 근본 해결은 surefire 버전 상향(2.22.2 → 3.x)이지만, 프로덕트 pom 변경은 별도 결정 — tester/developer는 실행 형태로 회피한다.

## 하네스 적용
- `agents/developer/developer-backend.md` — TDD RED/GREEN 판정 시 위 규칙.
- `agents/tester/tester-backend.md` — `-Dtest=` 변경스코프 실행 시 @Nested 포함 강제.
- 근원: task3-picker 회고(2026-06-17). 격리/필터가 조용히 일부를 건너뛰는 함정 계열로 [[windows-path-jq]](stale PATH로 도구를 조용히 못 찾음)와 같은 "무음 누락" 패턴.
