---
title: Device Guard(WDAC)가 서명 안 된 JDK javac.exe 실행 차단 → maven fork 컴파일 무음 실패
type: gotcha
links: [[surefire-runaway-test-timeout]]
sources:
  - 발생세션: authpatch_draft export 선행빌드 디버깅 (2026-06-24, 소비자 세션)
  - 영구 우회 commit 91bacbd0 (autopatch MavenBuilder `-Djdk-1.8-home` 주입)
updated: 2026-06-24
---

## 증상
- maven 빌드(특히 제품 pom의 `<fork>true</fork>` + `<executable>${jdk-1.8-home}/bin/javac</executable>`)가 **"Compilation failure"인데 `.java:` 에러 본문 0줄**.
- `mvn -e`/`-X`로 직접 실행해도 진단출력 없음. "Compiling N source files" 직후 0.x초 만에 BUILD FAILURE.
- 처음엔 fork stderr 삼킴(로깅 갭)으로 오인하기 쉬움. 실제론 **javac 프로세스가 起動 자체를 못 함**.

## 진짜 원인
회사 **Device Guard(WDAC, 기업 보안정책)가 서명 안 된 OpenJDK 바이너리(javac.exe) 실행을 차단**.
- cmd서 해당 javac 직접 실행 시: `'...\bin\javac.exe' 조직의 Device Guard 정책에 의해 차단되었습니다`.
- 같은 머신서도 JDK 빌드마다 허용/차단 갈림(서명·허용목록 차이). 예: OpenJDK8 특정빌드 차단, AdoptOpenJDK 11.0.6 통과.

## 진단법 (핵심)
의심 JDK의 javac를 **cmd서 직접 실행**: `"<jdk>\bin\javac.exe" -version`
- "Device Guard 정책에 의해 차단" → 그 JDK 못 씀.
- 버전 정상 출력 → 통과.
- ⚠ MSYS/bash서 실행하면 "Permission denied"로 보일 수 있음 — **cmd서 확인이 정확**.

## 회피책
- **Device Guard 통과하는 JDK**(예: AdoptOpenJDK)를 fork 컴파일러로 지정.
- maven 즉시 우회: `-Djdk-1.8-home=<통과JDK경로>` (pom의 `${jdk-1.8-home}` 오버라이드). JDK11이 Java8 소스도 대부분 정상 컴파일(제거된 API만 주의).
- 영구: 빌드 코드가 번들 통과-JDK를 fork 컴파일러로 자동 주입(autopatch MavenBuilder `-Djdk-1.8-home` 주입, commit 91bacbd0).

## red herring (헷갈리지 마)
- **"JDK11 하위호환 문제" 아님** — fork executable이 별도라 JAVA_HOME 무관.
- **junction 경로 문제 아님**(`C:\Program Files\Java\jdk-8`) — 타겟 JDK 자체가 차단이면 무의미.
- **소스 컴파일 에러 아님** — javac이 안 돌아서 에러 본문이 없는 것.
