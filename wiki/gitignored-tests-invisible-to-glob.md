---
title: 테스트가 gitignore인 프로젝트 — Glob·디렉터리 Grep이 0건을 준다(부재 아님)
type: gotcha
links: [[grep-binary-misdetect-touch-surface]], [[claude-rules-gitignore-local-only]], [[gates-verify-present-code-only]]
sources:
  - sources/20260911T041336Z__khnp-cme-9.3.1.md
updated: 2026-09-14
---

**증상:** `@Test`를 Glob 패턴(`**/{MailLogManagerTest,…}.java`)이나 디렉터리 Grep으로 찾으면 **0건**이 나온다. 같은 파일을 Bash `grep -c '@Test'`로 세면 **13 / 3 / 11건**이 디스크에 있다. 계획서·설계 근거가 그 0건을 "이미 삭제됨 / 테스트 없음"으로 인용한다.

**진짜 원인:** Glob·Grep 도구는 ripgrep 기반이라 **`.gitignore`를 존중한다.** 이 프로젝트는 `*/src/test/`가 gitignore(테스트 로컬 전용)다. **파일 경로를 path로 직접 주면** 같은 도구도 정상 검색한다 — 도구가 못 읽는 게 아니라 **열거에서 빠지는** 것이다.

**회피:**
- `git check-ignore -q <모듈>/src/test`가 참인 프로젝트에서는 **Glob·디렉터리 Grep의 0건을 부재 근거로 인용하지 않는다.**
- 확인 수단: Read / **파일 경로를 직접 준 Grep** / Bash `grep`·`find`.
- 위임 프롬프트에 이 경고를 넣는다 — 규약은 `../docs/playbook-delegation.md ### ③`. 기계 강제가 없으므로 프롬프트에 남은 주입 흔적으로만 확인된다.

**같은 뿌리의 두 번째 증상 — gitignore와 git 추적은 배타가 아니다:**
- 옛 브랜치 커밋에 **추적돼 있던** 테스트 4개가 base에는 없어, rebase 체크아웃이 그것들을 **디스크에서 지웠다**. "테스트는 gitignore니 git과 무관"이라는 전제가 깨지는 자리다.
- 회피: 이력 재작성(rebase·reset) 뒤 변경검증 위임 **전에** `git diff --name-status --diff-filter=D <이전 HEAD> HEAD` 1회 → 회귀 스코프 재산정(`orchestrator.md ## 핵심 규칙`).
- 안 잡으면 tester가 **없는 클래스를 지시받아 무음 부분실행**한다.

**교훈:** 도구의 "0건"은 **"열거 대상에 없었다"**이지 **"디스크에 없다"**가 아니다. 부재를 근거로 쓸 때는 열거 축과 존재 축이 같은지 한 번 더 본다 — [[gates-verify-present-code-only]]의 "부재를 보는 그물은 따로"와 같은 계열이다.
