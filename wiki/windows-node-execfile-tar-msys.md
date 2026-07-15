---
title: Windows Node execFile('tar')가 Git Bash서 MSYS tar를 잡아 -C를 SSH 호스트로 오인
type: gotcha
links: [[windows-path-jq]], [[write-tool-tmp-vs-bash-tmp-windows]], [[codex-tmp-windows-path]]
sources:
  - 발생세션: bundle-mingit slice #R follow-up — tar DX 소수정 (repostitch, 소비자 세션, 2026-07-12)
  - 커밋 d66a97d
  - 두 tar.exe 크기 실측(92KB System32 bsdtar vs 511KB MSYS GNU tar)
  - inbox: ~/.claude/harness-retro-inbox/20260712T041300Z__DEVUNIT-repostitch__tar-msys.md
updated: 2026-07-12
---

**증상:** Node `execFileAsync('tar', ...)`(PATH 검색)를 **Git Bash 셸**에서 실행하면 `tar: Cannot connect to C: resolve failed`. cmd/PowerShell에서는 정상 → **셸 의존 DX 파손**(Git Bash 개발자만 막힘, npm prestart 경유 `npm start`도 동일).

**진짜 원인:** Git Bash의 PATH는 MSYS tar(`C:\Program Files\Git\usr\bin\tar.exe`, GNU tar ~511KB)를 System32 bsdtar(~92KB)보다 **우선 해석**한다. GNU tar는 `-C C:\...`의 `C:`를 **SSH remote host**로 오인한다(`host:path` 문법). cmd/PowerShell/npm.cmd은 System32 우선이라 bsdtar가 잡혀 정상.

**회피:** Windows에서 tar는 PATH 검색 말고 **절대경로**로 호출해 bsdtar를 강제한다(셸 무관):
```js
join(process.env.SystemRoot || 'C:\\Windows', 'System32', 'tar.exe')
```
번들 바이너리(git.exe 등)는 절대경로 spawn이 일반 원칙 — tar도 예외 아님.

**교훈:** Windows에서 PATH로 찾은 도구는 **셸마다 다른 실행파일**일 수 있다. 동명이인(bsdtar↔GNU tar)이 인자 문법까지 다르면 조용히 깨진다. 같은 PATH 해석 함정군: [[windows-path-jq]], [[write-tool-tmp-vs-bash-tmp-windows]].
