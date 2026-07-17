---
title: codex workspace-write가 깊은 워크트리서 vitest 자기검증 불가 (샌드박스+실행정책)
type: gotcha
links: [[codex-bash-direct-timeout]], [[codex-tmp-windows-path]], [[vitest-vimock-partial-throws]]
sources:
  - 발생세션: DEVUNIT-repostitch tracker-data-migration codex 태스크 7건 (2026-07-15)
  - inbox: ~/.claude/harness-retro-inbox/20260715T031024Z__DEVUNIT-repostitch.md
updated: 2026-07-15
---

**증상:** codex `-s workspace-write` 태스크 7+회 **전건**에서 테스트 자기검증 실패:
```
npx: blocked by PowerShell execution policy
npx.cmd → esbuild: Cannot read directory "../../../../../..": Access is denied
       → Could not resolve vitest.config.mjs
```
매번 "테스트는 못 돌렸지만 `node --check`는 통과"로 끝남 → **모든 codex 산출이 미검증 상태**로 넘어와 결함이 별도 tester 라운드에서야 드러남.

**진짜 원인:** codex 샌드박스가 워크트리 **상위 디렉터리**를 못 읽는데(`~/.local/share/worktrees/...` 깊은 경로), `vitest.config.mjs` 해석이 상위 경로를 탄다. + PowerShell 실행정책이 `npx` 차단.

**회피:**
- **codex에 테스트 자기검증을 위임하지 마라.** 프롬프트에 "테스트 실행 불가 전제, `node --check`(문법)까지만" 명시하고, 실행검증은 **tester 라운드로 분리**한다(7.6 sanity가 유일한 실행검증 = `playbook-tdd.md` 7.5 참조).
- (조사 미완) 워크트리에서 `vitest --config <절대경로>` 또는 `--root` 지정으로 우회 가능한지는 미확인.

**교훈:** codex workspace-write 산출은 "미검증" 전제로 받는다. 자기검증 실패를 결함 없음으로 오인하지 말 것 — 실행검증은 tester가.
