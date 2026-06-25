---
title: information_schema.STATISTICS.TABLE_NAME은 ci collation — 'Users'가 'users'에 매칭된다
type: gotcha
links: [[hibernate-naming-strategy-explicit-name]]
sources:
  - authpatch_draft commit 42d77a7e (fix(schema): DB 네이밍 drift 수정)
  - 발생 세션: authpatch_draft 2026-06-25 DB 네이밍 drift 풀사이클 (GitlabUniqueConstraintValidator)
updated: 2026-06-25
---

## 증상
`GitlabUniqueConstraintValidator`가 `... WHERE TABLE_NAME = 'Users'`(PascalCase 하드코딩)로 인덱스 존재를 조회하는데, 라이브 테이블은 `users`(snake) + `lower_case_table_names=0`(대소문자 구분 환경)인데도 **validator가 기동 시 정상 통과**. "Pascal 리터럴인데 왜 snake 테이블에 매칭되지?" 혼란.

## 진짜 원인
`lower_case_table_names`는 **실제 테이블 식별자**(파일시스템/메타 저장)의 대소문자 처리를 정한다. 그러나 `information_schema.STATISTICS.TABLE_NAME` 같은 **메타 컬럼의 문자열 비교**는 그 컬럼의 **collation**(MariaDB/MySQL 기본 `utf8_general_ci` = case-**in**sensitive)을 따른다. 그래서 `TABLE_NAME = 'Users'`가 저장된 `users`에 ci 비교로 매칭됨 — LCTN=0이어도.

## 함의 (양날)
- 그래서 테이블명 대소문자 오타('Users')가 있어도 validator가 우연히 통과 → 오타가 안 드러남(거짓 안전).
- 역으로 "validator가 'Users'로 통과한다 = 라이브 테이블이 Pascal이다"라고 **추론하면 틀린다**(설계패널이 이걸로 잘못된 critical 제기 → 라이브 직접조회로 기각).

## 회피/대응
- 메타 조회 리터럴도 실제 식별자(snake)와 **일치**시킨다(fragile 제거): `TABLE_NAME = 'users'`.
- 환경독립 강화: `AND LOWER(TABLE_NAME) = 'users'`로 collation 의존 제거 검토.
- 보안 불변식을 메타조회로 강제할 땐 **이름 존재만 보지 말고** 실제 속성까지: 예) UNIQUE 보장이면 `AND NON_UNIQUE = 0 AND COLUMN_NAME = '...'` 추가(이름만 같은 non-unique 인덱스에 속지 않게).
- "validator/메타조회 통과 = 스키마 사실"로 추론 금지. 사실은 `information_schema` 직접 조회로 확정.

## 관련
- [[hibernate-naming-strategy-explicit-name]] — 같은 fix의 짝 gotcha(라이브 snake 확정 경위).
