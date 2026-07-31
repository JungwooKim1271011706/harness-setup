---
title: "@SpringBootTest가 무한대기 — JLine Terminal 빈이 tty 없는 surefire fork에서 블로킹"
type: gotcha
links: [[surefire-runaway-test-timeout]], [[springshell-noninteractive-runner-order]]
sources:
  - sources/20260730T103346Z__DEVUNIT-authpatch_draft.md
  - sources/20260728T041316Z__DEVUNIT-authpatch_draft.md
updated: 2026-07-31
---

**증상:** `mvn test`가 `@SpringBootTest` 계열 클래스에서 **진행 없이 멈춘다.** 컨텍스트 부팅 로그가 나오다 끊기고, 타임아웃에 걸려서야 죽는다. 실패 메시지가 원인을 안 가리켜 인코딩·의존성·DB를 의심하며 시간이 샌다.

**실측:** 우회 없이 600s 타임아웃 **×2회 = 20분 소모**(`SubmoduleDrilldownWiringIntegrationTest` 342.9s 소모 후 강제종료, `WebExportServiceCommitDetailTest` 컨텍스트 부팅 중 349s 대기). 플래그 부착 후 **42.6초에 12클래스 완주**.

**원인:** Spring Shell 계열 앱은 애플리케이션 컨텍스트 로드 시 **JLine `Terminal` 빈을 생성**한다. JLine은 tty를 찾아 붙으려 하는데, surefire가 포크한 JVM에는 **tty가 없다**. 이때 예외로 끝나지 않고 **블로킹**한다 — 그래서 "느린 테스트"와 구별되지 않는다.

**회피 — mvn 호출에 dumb terminal 강제:**

```
-DargLine="-Dorg.jline.terminal.provider=dumb -Dorg.jline.terminal.dumb=true"
```

- 실행 스코프에 `@SpringBootTest`가 하나라도 있으면 **항상** 붙인다. Spring Shell을 안 쓰는 프로젝트에서는 무해한 no-op.
- ⚠ `-DargLine`은 프로젝트가 pom에 정의한 `argLine`을 **덮는다.** 프로젝트 argLine에 필수 설정(jacoco agent 등)이 있으면 그것과 합쳐서 넘겨야 한다 — 덮어쓴 뒤 커버리지가 0으로 나오면 이걸 의심한다.

**하네스 함의:** 이 우회가 기록되지 않아 tester가 **매 세션 재발견**해야 했고, 그 사이 orchestrator가 라운드마다 프롬프트에 수동 주입했다. → `tester-backend.md`·`tester-runtime.md` 실행 명령 표준에 상수로 박았다(v4.9.0).

**같은 계열(테스트 실행이 안 끝난다):** [[surefire-runaway-test-timeout]](단일 테스트 무한루프 → per-fork·per-test 타임아웃으로 fail-fast) · [[springshell-noninteractive-runner-order]](비대화형 러너 순서). 공통 교훈 — **JVM 테스트가 "느린 것"과 "막힌 것"은 로그로 구별되지 않는다. 타임아웃을 항상 걸어 막힘을 실패로 드러낸다.**
