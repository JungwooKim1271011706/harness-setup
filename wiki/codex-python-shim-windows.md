---
title: codex --json 파서가 Windows Store python shim을 골라 broken pipe (exit 101)
type: gotcha
links: [[codex-tmp-windows-path]]
updated: 2026-06-19
---

## 증상
codex `--json` 출력을 파싱하는 호출에서 `command -v python3`가 실제 인터프리터 대신 **Windows Store python shim**(`C:/Users/.../AppData/Local/Microsoft/WindowsApps/python3`)을 먼저 고른다. 이 shim은 실행 시 스토어 설치 안내만 띄우고 stdin을 안 읽어 **broken pipe → exit 101**로 codex 호출이 죽는다.

## 진짜 원인
Windows는 PATH 앞쪽 `WindowsApps`에 `python3` shim을 깔아둔다(앱 실행 별칭). `command -v python3`/`which python3`는 PATH 순서대로 첫 매치를 반환하므로, 실제 Python이 뒤에 설치돼 있어도 실행 불가한 shim이 선택된다.

## 회피
- 호출측에서 **실제 인터프리터 경로를 `PYTHON_CMD`로 명시**한다(이 PC: `C:/Users/crinity/AppData/Local/Programs/Python/Python313/python`). 머신마다 경로가 다르므로 구체 경로는 auto-memory(머신 한정)에 둔다.
- **벤더 스킬(`~/.claude/skills/gstack`)은 수정 금지** — 글로벌 의존이라 동기화로 덮어써져 "고쳤다 착각" 사일런트 회귀. 우회는 항상 호출측에서.

## 관련 주의 — 차단훅 오탐 회피 (C4 reject 대체)
- orchestrator가 Bash로 codex 프롬프트(heredoc 등)를 작성할 때, **본문에 `mvn`/`gradle`/`git commit` 리터럴을 피한다.** `block-orchestrator-exec.sh`는 워드바운더리 매칭이라 heredoc 본문의 그 단어도 차단 후보로 잡을 수 있다. 본문 안전 제외는 쉘 파싱이 필요해 fragile + 차단훅 우회 위험 → 훅을 고치지 않고 호출측에서 리터럴을 피하는 게 안전.

## 하네스 적용
- 휴대 가능한 패턴(증상→원인→회피)만 여기 기록. 머신 한정 경로는 orchestrator auto-memory. [[codex-tmp-windows-path]](codex 호출 시 Windows TMP 경로 함정)와 같은 codex-on-Windows 함정 계열.
