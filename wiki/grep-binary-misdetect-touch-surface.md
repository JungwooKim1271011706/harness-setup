---
title: grep/ripgrep binary 오탐 → 생성자 touch-surface 무음 누락
type: gotcha
links: [[java-unicode-escape-compile-trap]]
sources:
  - 발생세션 DEVUNIT/authpatch WI-C artifact-self-verify (2026-07-19)
  - .claude/rules/package/autopatch/backend.md (동일 함정 규칙 기록됨)
  - ~/.claude/harness-retro-inbox/gotcha-grep-binary-misdetect-touch-surface.md (inbox 드레인 2026-07-19)
updated: 2026-07-19
---

## 증상
생성자/인터페이스 시그니처 변경 시 회귀범위를 grep(Grep 도구·ripgrep) 카운트로 "N건/N파일 확인"이라
계획서에 박제했는데, 실제 test-compile에서 **박제 카운트에 없던 파일**이 컴파일 에러. WI-C 실측:
`new GitExportOrchestrator(` 를 "11파일"로 카운트했으나 실제 12파일 — 12번째가 무음 누락.

## 원인
ripgrep은 파일에 유효 UTF-8이 아닌 개별 바이트가 섞이면(진짜 NUL은 아닐 수 있음) 그 파일 전체를
**"binary"로 오탐**하여 검색 대상에서 **무음 제외**한다. `Binary file <path> matches`만 출력하고
매칭 라인은 안 보여줘 카운트에서 빠진다.
- `file <path>` 는 "data"로 분류하는데 `iconv -f UTF-8 -t UTF-8`은 정상 통과 — 파일 자체는 유효 UTF-8 Java 소스이고 javac는 정상 파싱(단순 인자개수 불일치 에러만).

## 회피
- 생성자/인터페이스 시그니처 변경 회귀범위는 **grep 카운트만 믿지 말고 `mvn test-compile` 1회로 실제 컴파일 에러 유무를 교차검증**한다(카운트는 하한, 컴파일이 진실).
- 이런 오탐 파일 선별: `grep -IL . <경로>` (비-텍스트로 분류된 파일 나열).
- 7c.2 stale 인벤토리(시그니처/위임 전환 부류)가 grep 의존이므로 특히 이 축에 취약 — 인벤토리 후 test-compile로 봉인.

## 여파
WI-C에서 이 12번째 파일(`GitExportOrchestratorListHeaderTest.java`)이 M3 mock 마이그레이션 11곳에서
누락 → developer stub 단계 `mvn test-compile`에서야 발각 → tester-design M3 12번째 보강 라운드 추가.
