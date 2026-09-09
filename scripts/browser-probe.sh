#!/bin/bash
# 브라우저 자동화 가용성 탐지 — 렌더 실측용.
# 사용법: bash .claude/scripts/browser-probe.sh
#   가용: `TOOL=<orca|browse> BIN=<절대경로>` 1줄 출력 + exit 0
#   불가: 아무것도 출력하지 않고 exit 1  → 호출측은 사람 E2E로 폴백한다.
#
# ⚠ 왜 래퍼인가: 하네스는 여러 머신·여러 사람이 공유한다. 규칙이나 agent md에
#   `C:\Users\<이름>\AppData\Local\Programs\orca\...` 같은 절대경로를 박으면
#   그 경로가 없는 세션이 전부 깨진다. 탐지를 한 곳에 모으고, 못 찾으면
#   **조용히 폴백**한다(차단 아님). `## codex 호출 가드`가 codex 가용성을
#   다루는 방식과 동형 — 가용/불가를 orchestrator가 확정해 하위에 주입한다.

emit() { printf 'TOOL=%s BIN=%s\n' "$1" "$2"; exit 0; }

# ── 1) Orca ADE 내장 브라우저 (JSP·jQuery 등 러너 없는 스택) ──
#    로그인 세션을 사용자와 공유하는 것이 최대 이점 (wiki: orca-browser-e2e)
LA="${LOCALAPPDATA:-$HOME/AppData/Local}"
for c in \
  "$LA/Programs/orca/resources/bin/orca.exe" \
  "$HOME/AppData/Local/Programs/orca/resources/bin/orca.exe" \
  "/Applications/Orca.app/Contents/Resources/bin/orca" \
  "$HOME/.local/share/orca/bin/orca"
do
  [ -x "$c" ] && emit orca "$c"
done
if command -v orca >/dev/null 2>&1; then emit orca "$(command -v orca)"; fi

# ── 2) gstack browse (SPA·정적 서버 — 기존 경로) ──
for c in \
  "$HOME/.claude/skills/gstack/browse/dist/browse.exe" \
  "$HOME/.claude/skills/gstack/browse/dist/browse"
do
  [ -x "$c" ] && emit browse "$c"
done

exit 1
