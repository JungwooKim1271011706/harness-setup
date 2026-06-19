---
title: Surefire 기본 스캔이 *IT 명명 테스트를 조용히 누락 (failsafe 미바인딩 pom)
type: gotcha
links: [[surefire-nested-skip]]
updated: 2026-06-19
---

## 증상
`*IT`/`*ITCase` 명명 테스트 클래스를 `mvn test -Dtest=ProfileIT`로 격리 실행하면 11 GREEN으로 PASS가 뜬다. 그러나 필터 없는 기본 `mvn test`에서는 그 클래스가 **수집조차 안 되고 조용히 누락**된다(에러 없음). → tester가 `-Dtest=`만으로 GREEN 판정하면 거짓 PASS. `/codex review`에서 P1으로 적발됨.

## 진짜 원인
maven-surefire-plugin의 기본 include 패턴은 `**/Test*.java`, `**/*Test.java`, `**/*Tests.java`, `**/*TestCase.java` 뿐이다. `*IT`/`*ITCase`는 **failsafe 플러그인(통합테스트) 영역**으로 설계상 surefire 기본 스캔에서 제외된다. 이 pom은 **failsafe를 바인딩하지 않아** `*IT` 클래스가 어느 단계에서도 자동 실행되지 않는다(`-Dtest=`로 명시할 때만 실행). 즉 "격리 PASS = 기본 실행 PASS"라는 암묵 가정이 깨진다 — [[surefire-nested-skip]]의 @Nested 무음 스킵과 같은 "무음 누락" 패턴.

## 회피
1. **명명을 기본 include에 맞춘다**: 통합테스트 인프라가 없으면 `*IT` → `*Test`로 rename(예: `ProfileIT` → `ProfileTest`)해 기본 `mvn test` 스캔에 포함시킨다. (실제 수정: *Test rename으로 해결)
2. failsafe를 의도적으로 쓸 거면 pom에 failsafe 플러그인 바인딩 추가 — 단 프로덕트 pom 변경은 별도 결정.

**`-Dtest=`로만 PASS 판정 금지.** 신규/변경 테스트 파일명이 기본 include 4패턴에 매칭되는지 확인하고, GREEN 근거는 필터 없는 전체 실행 수치로 제시한다. RED sanity·변경검증 모두 적용.

## 하네스 적용
- `agents/tester/tester-backend.md` ## 핵심 규칙 — 기본 스캔 포함 확인 규칙.
- 근원: feature-12 oauth-guard-shell-context 버그수정 회고(2026-06-19). `ProfileIT`가 `-Dtest`로는 11 GREEN이나 기본 `mvn test`에서 누락 → /codex review P1, *Test rename으로 수정. 격리/필터가 일부를 조용히 건너뛰는 함정 계열로 [[surefire-nested-skip]]과 동족.
