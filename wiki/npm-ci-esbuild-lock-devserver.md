---
title: "npm ci가 EPERM unlink로 죽는다 — 실행 중 dev server의 자식 esbuild.exe가 node_modules를 점유"
type: gotcha
links: [[vite-stale-served-source-windows]], [[windows-node-execfile-tar-msys]]
sources:
  - sources/20260730T082523Z__DEVUNIT-authpatch_draft.md
updated: 2026-07-31
---

**증상:** `mvn -P web package`의 `frontend-npm-ci` 단계가 `EPERM: operation not permitted, unlink ... -4048` 로 BUILD FAILURE. 파일 권한을 의심하게 되지만 권한 문제가 아니다.

**원인:** `npm ci`는 `node_modules`를 **선삭제**한다. 그런데 Windows에서는 **실행 중 프로세스가 잡고 있는 파일을 지울 수 없다.** vite dev server가 살아 있으면 그 자식 `esbuild.exe`가 `node_modules/@esbuild/**` 아래 바이너리를 점유하고 있어 unlink가 거부된다.

**진단 — 어느 체크아웃의 dev server인지 특정:**

```powershell
Get-CimInstance Win32_Process -Filter "Name='esbuild.exe'" | Select ProcessId, ParentProcessId, CommandLine
# ParentProcessId 를 다시 조회해 어느 워크트리의 vite인지 확정
Get-CimInstance Win32_Process -Filter "ProcessId=<ppid>" | Select CommandLine
```

병렬 워크트리 환경에서는 **지금 빌드하려는 체크아웃이 아닌 다른 체크아웃의 dev server**가 범인인 경우가 있다 — 그래서 "내 dev server는 껐는데?"로 헤맨다. 부모 PID까지 따라가 경로를 확인할 것.

**회피:** 빌드 전에 dev server를 끈다. 습관에 의존하는 구조라 **재발이 확정적**이므로, 빌드 스크립트가 있는 프로젝트라면 빌드 시작 시 esbuild/vite 프로세스를 확인·경고하는 편이 낫다.

**관련:** [[vite-stale-served-source-windows]](같은 체크아웃의 stale 서빙). dev server의 생존 여부가 **빌드와 검증 양쪽에서** 함정을 만든다 — 빌드는 락, 검증은 stale·오체크아웃 서빙.
