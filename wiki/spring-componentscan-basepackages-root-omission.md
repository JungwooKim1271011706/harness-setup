---
title: 명시 @ComponentScan(basePackages)가 루트 패키지를 누락하면 @Component 빈이 조용히 미등록
type: gotcha
links: [[spring-profile-bean-eval-timing]], [[springshell-noninteractive-runner-order]]
sources:
  - 발생 세션 2026-06-29 autopatch-dashboard-export-1 (AutoPatcherRunner 빈 미등록)
  - 코드: AutopatchApplication.java (@ComponentScan basePackages), AutoPatcherRunner
updated: 2026-06-29
---

## 증상
ApplicationRunner / @Component 빈의 로직이 **영영 실행 안 됨**. 트리거 로그(`[MODE]` 등) 안 찍힘. 재빌드해도 동일. 예외도 없음(`CommandNotFound`조차 없이 조용). 빈이 "없어서" 안 도는 건데 등록 실패가 silent라 @Order·실행 조건 같은 엉뚱한 가설에 매몰되기 쉽다.

## 진짜 원인
- `@SpringBootApplication`은 기본적으로 **선언된 클래스의 패키지와 하위**를 컴포넌트 스캔한다.
- 그런데 명시적 `@ComponentScan(basePackages={"a.b.c", ...})`를 추가하면 그 목록이 **기본 스캔을 대체**(보강 아님)한다.
- 대상 @Component(예: 루트 `com.crinity.autopatch`의 ApplicationRunner)가 basePackages 목록에 없으면 스캔에서 빠져 **빈 미등록** → `run()` 미호출.

## 회피
- `basePackages`에 누락된 루트/패키지를 **명시 추가**한다(기본 스캔을 대체했음을 인지하고 전부 나열).
- 일반화: 명시 @ComponentScan을 쓰는 순간 "기본 스캔은 꺼졌다"고 보고 필요한 패키지를 빠짐없이 적는다.

## 하네스 적용 (검증 방법)
- **단위테스트가 빈을 리플렉션으로 직접 인스턴스화하면 빈 '등록'을 검증하지 못한다** — 객체는 만들어지니 PASS인데 컨테이너엔 없다. 등록 여부는 `ApplicationContext` 통합테스트로 `assertThat(ctx).hasBean(...)`처럼 봐야 잡힌다(tester-design/developer-backend).
- 같은 "빈이 조용히 안 뜬다" 계열이지만 결함 위치가 다름: 등록 시점 평가=[[spring-profile-bean-eval-timing]], 러너 실행 순서=[[springshell-noninteractive-runner-order]], **스캔 범위 누락=이 페이지**.
- 근원: autopatch 비대화형 export 복구 회고(2026-06-29).
