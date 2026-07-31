---
title: grep/ripgrep binary 오탐 → 생성자 touch-surface 무음 누락
type: gotcha
links: [[java-unicode-escape-compile-trap]]
sources:
  - 발생세션 DEVUNIT/authpatch WI-C artifact-self-verify (2026-07-19)
  - .claude/rules/package/autopatch/backend.md (동일 함정 규칙 기록됨)
  - ~/.claude/harness-retro-inbox/gotcha-grep-binary-misdetect-touch-surface.md (inbox 드레인 2026-07-19)
  - sources/20260730T103346Z__DEVUNIT-authpatch_draft.md (원인 규명 — raw NUL, 2026-07-30)
updated: 2026-07-31
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

## 원인 규명 (2026-07-30 — 종전 "개별 바이트, 정체 불명"이 풀림)
그 "개별 바이트"는 **raw NUL(0x00)** 이고, **대용량 Write 산출물에 주입**된다. 관측 3건: 802줄 테스트, 644줄 spec, 그리고 **계획서 md 1바이트**.

- `file -b <FILE>` → `data` (오염) / `Unicode text, UTF-8 text` (정상). **이게 판별식이다.**
- ⚠ `iconv -f UTF-8 -t UTF-8`은 **통과한다** — NUL은 유효 UTF-8이라 인코딩 검사로는 절대 안 잡힌다.
- 주입 주체는 두 갈래로 갈리고 **구별 불가**: ① 작성자가 픽스처에 제어문자를 raw로 박음 ② Write 도구의 대용량 쓰기 자체. 3건 관측이라 도구측이 유력하나 확증 못 했다. **어느 쪽이든 검사 절차는 동일하게 유효**하다.

**파급이 테스트 파일에 그치지 않는다:** 계획서 md가 오염되면 GNU grep이 `Binary file matches`로 처리해 **GREEN 단계 developer가 오라클(계획서)을 grep으로 못 읽는다.** 위 사례에서 orchestrator가 발견해 escape 표기로 치환, NUL 제거 후 `Unicode text, UTF-8 text`로 복구 + Grep 정상화를 확인했다.

## 회피
- **대용량 Write 직후 매번**: `tr -dc` 제어문자 카운트(0이어야) **+ `file -b <FILE>`**. 대상은 테스트 파일만이 아니라 **계획서 md 포함 모든 대용량 산출물**. 규칙화: `tester-design.md` R10, `developer-*.md` 핵심규칙(v4.9.0).
- 생성자/인터페이스 시그니처 변경 회귀범위는 **grep 카운트만 믿지 말고 `mvn test-compile` 1회로 실제 컴파일 에러 유무를 교차검증**한다(카운트는 하한, 컴파일이 진실).
- 이런 오탐 파일 선별: `grep -IL . <경로>` (비-텍스트로 분류된 파일 나열).
- 7c.2 stale 인벤토리(시그니처/위임 전환 부류)가 grep 의존이므로 특히 이 축에 취약 — 인벤토리 후 test-compile로 봉인.

## 여파
WI-C에서 이 12번째 파일(`GitExportOrchestratorListHeaderTest.java`)이 M3 mock 마이그레이션 11곳에서
누락 → developer stub 단계 `mvn test-compile`에서야 발각 → tester-design M3 12번째 보강 라운드 추가.
