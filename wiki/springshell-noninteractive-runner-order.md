---
title: spring-shell 비대화형 모드 — 커스텀 ApplicationRunner는 @Order(HIGHEST_PRECEDENCE) 필요
type: gotcha
links: [[spring-profile-bean-eval-timing]]
sources:
  - 커밋 b3626f8 (autopatch_draft, AutoPatcherRunner @Order fix)
  - 발생 세션 2026-06-29 autopatch-dashboard-export-1 (비대화형 배치 export 복구)
updated: 2026-06-29
---

## 증상
Spring Boot CLI 앱을 비대화형 배치로 실행(`java -jar ... --patchMode=[export]`, TTY 없음, CI/cron)하면 커스텀 ApplicationRunner 분기에 도달 못한다. `[MODE]` 로그 안 찍힘. `--spring.shell.interactive.enabled=false` / `--spring.shell.script.enabled=false`로 우회 시도 시 `CommandNotFound: No command found for '--spring.shell...'`.

## 진짜 원인
- spring-shell 2.1.14 `DefaultShellApplicationRunner`는 `@Order(LOWEST_PRECEDENCE - 10)`로 비교적 높은 우선순위. 커스텀 러너에 `@Order`가 없으면 `LOWEST_PRECEDENCE`(최하) → 셸 러너가 **먼저** 실행된다.
- TTY 없으면 셸 러너가 leftover 인자(`--patchMode=[export]`)를 셸 명령으로 해석 → CommandNotFound, 커스텀 러너의 patchMode 분기 미도달.
- CLI 플래그 우회가 안 먹히는 이유: `NonInteractiveShellRunner`가 그 플래그 자체를 명령으로 보고 CommandNotFound. 즉 설정/인자 레이어로는 못 고친다.

## 회피 (코드 픽스가 정답)
커스텀 ApplicationRunner에 `@Order(Ordered.HIGHEST_PRECEDENCE)` 부여 → 셸 러너보다 먼저 실행 보장.
- 인터랙티브 보존: 인자 없으면(`patchMode == null`) early `return`으로 셸에 양보.
- 배치: 분기 처리 후 `System.exit(0)`.
- 약점: HIGHEST_PRECEDENCE는 다른 모든 ApplicationRunner(초기화 러너 등)보다도 앞선다. 배치 경로가 System.exit하면 뒤 러너들은 실행 안 됨 — export 전 선행 초기화가 필요해지면 @Order 값 재조정 필요.

## 하네스 적용 (테스트: GitLab/PAT 없이 결정적)
- tester-design/developer-backend: `OrderUtils.getOrder(runnerClass)`가 non-null이고 `DefaultShellApplicationRunner` order(`Integer.MAX_VALUE - 10`)보다 작은지 단언. 라이브 export E2E(PAT 필요)와 분리.
- 같은 Spring 함정이지만 [[spring-profile-bean-eval-timing]]과 결함 클래스 다름(저쪽=빈 등록 시점, 이쪽=러너 시작 순서).
- 근원: autopatch_draft 회고(2026-06-29).
