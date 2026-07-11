---
title: Write 도구의 /tmp ≠ Git Bash의 /tmp (Windows) — 프롬프트 파일 파이프 깨짐
type: gotcha
links: [[codex-bash-direct-timeout]], [[codex-tmp-windows-path]]
sources:
  - 발생세션: autopatch-dashboard-export-2 러너 비-JAR self-heal 컴파일 풀사이클 (2026-07-11)
  - inbox: ~/.claude/harness-retro-inbox/20260711T115434Z__DEVUNIT-authpatch_draft__wiki-gotcha.md
updated: 2026-07-11
---

**증상:** Claude Write 도구로 `/tmp/codex-75-nonjar-red.txt`에 프롬프트를 저장했는데,
직후 Bash `codex exec "$(cat /tmp/codex-75-nonjar-red.txt)"`가 `cat: /tmp/...: No such file or directory` →
codex가 **빈 프롬프트로 실행**돼 아무 작업도 안 함(exit 0, 무작동). 원인 파악 전엔 codex가 조용히 실패한 걸로 오인.

**진짜 원인:** Windows에서 Claude Code Write 도구의 `/tmp` 해석 ≠ Git Bash(MSYS)의 `/tmp` 마운트.
Write는 `/tmp`를 다른 실경로로 쓰고, bash `/tmp`는 MSYS 마운트(`C:\Users\...\AppData\Local\Temp` 등)라 **서로 다른 위치**. 같은 `/tmp/x` 문자열이 두 세계서 다른 파일.

**회피책:** Write 도구로 만든 파일을 bash에 파이프할 땐 `/tmp` 대신 **`/c/` 실경로**를 쓴다.
예: `C:\Users\crinity\.gstack\codex-prompt.txt`(Write) ↔ `cat /c/Users/crinity/.gstack/codex-prompt.txt`(bash) — 둘이 동일 실파일. 검증: bash `test -f /c/... && echo OK`.
- 반대로 bash heredoc(`cat > /tmp/x <<EOF`)으로 만든 파일은 bash `/tmp`라 bash cat은 됨(단 heredoc 본문에 "mvn" 있으면 `block-orchestrator-exec` 오탐 — 별도 항목, 경계3서 처리).

**교훈:** Write↔Bash 파일 파이프는 `/c/` 절대경로로 통일. `/tmp`는 두 도구가 다른 곳을 가리킨다.
