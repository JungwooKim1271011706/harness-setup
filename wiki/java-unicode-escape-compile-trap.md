---
title: Java \u 유니코드 이스케이프 컴파일 함정 (주석·문자열·전체 소스)
type: gotcha
links: [[grep-binary-misdetect-touch-surface]]
sources:
  - 발생세션 DEVUNIT/authpatch WI-C artifact-self-verify (2026-07-19), 커밋 d7964772
  - JLS 3.3 (Unicode Escapes)
  - ~/.claude/harness-retro-inbox/gotcha-java-unicode-escape-compile-trap.md (inbox 드레인 2026-07-19)
updated: 2026-07-19
---

## 증상
`.java` 파일에 `\uXXXX`(X가 hex 아님) 텍스트가 **주석·@DisplayName 문자열·어디든** 있으면
`illegal unicode escape character` 컴파일 에러. 코드 로직과 무관한 설명 텍스트에서도 발생.

## 원인
javac의 유니코드 이스케이프 치환은 **렉싱보다 먼저 실행되는 전처리 단계**(JLS 3.3).
소스 원문 전체를 스캔하며 `\u`(직전 연속 백슬래시가 짝수일 때) + 4자리 hex를 요구한다.
`//` 주석 안이든 문자열 리터럴 안이든 무관. `\uXXXX`처럼 X가 hex가 아니면 그 자리서 컴파일 실패.
- `\uXXXX` (백슬래시 1개, 짝수=0 선행) → escape 시도 → 비-hex → 에러
- `\\uXXXX` (백슬래시 2개) → escape 미트리거(안전하나 방어적으로 정리 권장)
- `\n`, `\t`, `\NNN`(octal) → `\u` 아니라 무관, 안전

## 회피
- 설명 텍스트에 `\u` + 비-hex 연속을 쓰지 마라. "유니코드 escape", "u+XXXX" 같은 워딩으로 우회.
- **테스트 데이터로 실제 escape 시퀀스를 넣어야 하면** `"\\uAC00"`처럼 백슬래시를 이스케이프(짝수) — 런타임 문자열은 리터럴 `가`이 되어 파서 검증용으로 유효.
- ⚠ **`mvn compile`(main만)은 이 결함을 못 잡는다.** test 파일 텍스트 변경 후에는 **`mvn test-compile`(또는 `mvn test`)로 테스트 소스 컴파일까지 확인**해야 발각된다.

## 이번 발생 (3회 반복 = 기록 트리거)
WI-C에서 AnchorExtractor가 "미지원 escape(`\u`/octal) 리터럴 앵커 제외" 로직을 구현하며,
prod 주석 2회 + test 설명 텍스트 1회 = 총 3회 같은 함정. test 텍스트 건은 tester-backend가
`mvn compile`만 돌린 developer 셀프체크를 통과한 뒤 재검증 test-compile에서야 FAIL로 드러남(LOOP 1 낭비).
