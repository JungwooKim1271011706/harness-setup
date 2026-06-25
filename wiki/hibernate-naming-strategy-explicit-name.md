---
title: Spring naming strategy는 명시 @Column/@Table 이름도 snake로 변환한다
type: gotcha
links: [[information-schema-table-name-ci-collation]] [[spring-profile-bean-eval-timing]]
sources:
  - authpatch_draft commit 42d77a7e (fix(schema): DB 네이밍 drift 수정)
  - 발생 세션: authpatch_draft 2026-06-25 DB 네이밍 drift 풀사이클
updated: 2026-06-25
---

## 증상
엔티티가 `@Table(name="Users")`, `@Column(name="checksumFileUid")`처럼 PascalCase/camelCase로 **명시**돼 있는데, 라이브 DB 테이블·컬럼은 전부 snake_case(`users`, `checksum_file_uid`). 수동 작성한 schema/migration SQL(camelCase)과 어긋나 신규설치 시 `SQL 1364 Field 'checksum_file_uid' doesn't have a default value` 발생.

## 진짜 원인
Spring Boot 기본 `SpringPhysicalNamingStrategy`(및 Hibernate `CamelCaseToUnderscoresNamingStrategy`)는 **명시적 `@Column(name=...)`/`@Table(name=...)` 값마저** physical naming strategy에 통과시켜 camelCase→snake로 변환한다. 즉 엔티티 어노테이션이 camelCase여도 Hibernate가 실제로 매핑/생성하는 테이블·컬럼은 snake. → ddl-auto가 snake 컬럼을 만들고 기대하는데, 수동 SQL이 camelCase 테이블/컬럼을 미리 만들어두면 중복·불일치로 1364.

## 흔한 오해 (설계패널도 빠짐)
"명시 name은 strategy가 통과시킨다(변환 안 함)" → 이건 `PhysicalNamingStrategyStandardImpl`(Hibernate 순정 기본)의 동작이지 **Spring 기본 전략이 아니다**. Spring 전략은 명시명도 변환한다.

## 회피/대응
- DDL(수동 schema/migration)을 **strategy 출력(snake)과 글자단위 일치**시킨다. 엔티티 name은 안 바꿔도 됨.
- naming strategy를 yml에 **명시 박제**(`spring.jpa.hibernate.naming.physical-strategy`)해 Spring Boot 업글 시 기본값 변경에 면역. 단 박제는 동작 보장이지 snake 강제가 아님(snake 정합은 DDL↔엔티티 일치로).
- "라이브가 snake냐 Pascal이냐"는 추측 말고 `information_schema`로 직접 조회 확정(`SELECT TABLE_NAME, COLUMN_NAME FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=...`).
- ddl-auto=validate는 이 정합을 기동 시 강제 검증(불일치 시 fail-fast).

## 관련
- [[information-schema-table-name-ci-collation]] — 같은 fix에서 발견된 짝 gotcha(라이브 snake 확정 경위).
- [[spring-profile-bean-eval-timing]] — 같은 프로젝트 Spring/JPA 함정.
