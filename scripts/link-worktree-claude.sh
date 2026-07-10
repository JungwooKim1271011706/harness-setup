#!/bin/bash
# 워크트리 .claude 자동 연결 (전역 SessionStart 훅에서 호출).
#
# 문제: 하네스 .claude가 프로젝트 repo에서 gitignore(별도 클론)라 `git worktree add`·vibe-kanban 등이
#       만든 워크트리엔 .claude가 안 딸려온다 → 워크트리 세션이 하네스(agents/hooks/skills/wiki) 접근 불가.
# 해결: 세션 시작 시(누가 워크트리를 만들었든 — vibe-kanban·git·Claude native 무관) 현재 워크트리에
#       .claude가 없으면 main 워크트리의 .claude로 junction(Win)/symlink(Unix)를 건다. 멱등.
# 등록: ~/.claude/settings.json 전역 SessionStart 훅. 프로젝트 .claude가 없어도 전역 훅은 발화하므로
#       부트스트랩 가능(프로젝트 훅으로는 불가 — .claude 자체가 없으니).
set -u

TOP=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0   # git repo 아니면 no-op
[ -e "$TOP/.claude" ] && exit 0                                # 이미 .claude 있음(main이거나 연결됨) → no-op

# main 워크트리 = worktree list 첫 항목
MAIN=$(git worktree list --porcelain 2>/dev/null | awk '/^worktree /{print substr($0,10); exit}')
[ -z "$MAIN" ] && exit 0
[ "$TOP" = "$MAIN" ] && exit 0                                 # 현재가 main이면 연결 안 함(방어)
[ -e "$MAIN/.claude" ] || exit 0                               # main에 .claude 없으면 연결 대상 없음

case "$(uname -s)" in
  MINGW*|MSYS*|CYGWIN*)
    # Windows junction — 관리자 권한 불요, 같은 볼륨 내 디렉터리 링크.
    # cygpath로 Windows 경로 변환, MSYS_NO_PATHCONV=1로 mklink `/J` 플래그가 경로로 오변환되는 것 차단.
    command -v cygpath >/dev/null 2>&1 || exit 0
    WLINK=$(cygpath -w "$TOP/.claude")
    WTARGET=$(cygpath -w "$MAIN/.claude")
    if MSYS_NO_PATHCONV=1 cmd /c mklink /J "$WLINK" "$WTARGET" >/dev/null 2>&1; then
      echo "🔗 워크트리 .claude junction 생성 → $MAIN/.claude"
    fi
    ;;
  *)
    ln -s "$MAIN/.claude" "$TOP/.claude" 2>/dev/null && echo "🔗 워크트리 .claude symlink 생성 → $MAIN/.claude"
    ;;
esac
exit 0
