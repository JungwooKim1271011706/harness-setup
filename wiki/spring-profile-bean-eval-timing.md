---
title: @Profile은 빈 정의 등록 시점에 평가 — ApplicationContextRunner withInitializer는 너무 늦다
type: gotcha
links: [[surefire-it-naming-skip]]
updated: 2026-06-19
---

## 증상
`@Profile("web")` 빈을 `ApplicationContextRunner` 테스트로 검증할 때, `withInitializer(ctx -> ctx.getEnvironment().setActiveProfiles("web"))`로 프로파일을 줬는데도 그 빈이 등록되지 않는다 → 테스트가 빈 부재로 false-fail 하거나, 단언이 아무것도 안 걸려 vacuous PASS.

## 진짜 원인
`@Profile`은 **빈 정의 등록(registration) 시점**에 평가된다. `withInitializer`로 active profile을 세팅하면 빈 정의 스캔/등록이 이미 끝난 **뒤**라 너무 늦어 @Profile 조건이 반영되지 않는다.

## 회피
- `withPropertyValues("spring.profiles.active=web")`로 준다 → 등록 평가 시점에 프로파일이 반영돼 @Profile 빈이 정상 등록된다.

```java
new ApplicationContextRunner()
    .withPropertyValues("spring.profiles.active=web")   // 등록 시점 반영 (O)
    // .withInitializer(ctx -> ...setActiveProfiles("web"))  // 너무 늦음 (X)
    .withUserConfiguration(WebConfig.class)
    .run(ctx -> assertThat(ctx).hasBean("webOnlyBean"));
```

## 하네스 적용
- 백엔드 Spring 컨텍스트 테스트 작성 시(tester-design/developer-backend). `*IT` 명명으로 통합테스트화하면 기본 스캔 누락 함정([[surefire-it-naming-skip]]) — *Test 명명 유지.
- 근원: feature-12 회고(2026-06-19). withInitializer로 false-fail/vacuous 발생.
