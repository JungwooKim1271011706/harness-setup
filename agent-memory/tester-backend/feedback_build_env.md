---
name: Build Environment - Maven/JDK fork 경로
description: tocServer 빌드 시 pom.xml fork javac 경로 불일치로 에러 메시지 없이 BUILD FAILURE 발생하는 문제와 해결법
type: feedback
---

pom.xml의 `<jdk-1.8-home>C:/Program Files/Java/jdk1.8.0_251</jdk-1.8-home>`이 실제 설치 경로와 다르면, fork=true 설정으로 인해 Maven이 컴파일 에러 메시지를 출력하지 않고 `Compilation failure`만 표시한다.

**Why:** maven-compiler-plugin 3.8.0 + fork=true 조합에서 javac 실행 파일을 찾지 못하면 에러 상세가 stdout에 노출되지 않는다.

**How to apply:** 빌드 실패 시 `-Djdk-1.8-home=<실제경로>` 오버라이드로 재실행. 실제 JDK 경로: `C:/Program Files/Java/jdk1.8.0_231`. Maven: `/c/download/maven/apache-maven-3.8.4/bin/mvn`. Java: `/c/download/openjdk/openjdk-1.8.0.312`.

또한 tocFramework(9.1.1-SNAPSHOT)가 먼저 `mvn clean install`되어야 tocServer 빌드 가능. 의존 순서: tocFramework → tocServer.
