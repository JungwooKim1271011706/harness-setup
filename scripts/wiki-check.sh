#!/bin/bash
# wiki 정합성 체크 — `wiki/_schema.md`의 "유지보수(lint)" 절이 요구하는 기계 점검분.
# Obsidian 그래프뷰는 고아·링크만 보여준다. 이 스크립트는 그래프가 못 보는
# index 미등록·frontmatter 결손(sources/updated)까지 잡는다. 모순·stale 판정은 사람 몫.
# 읽기 전용 — 파일/git 변형 없음. 발견 시 exit 1(경고용, 어떤 훅에도 안 물려 있음).
# 사용: bash scripts/wiki-check.sh   (소비자 세션: bash .claude/scripts/wiki-check.sh)
set -u

WIKI="$(cd "$(dirname "$0")/../wiki" 2>/dev/null && pwd)"
[ -z "$WIKI" ] && { echo "wiki/ 없음"; exit 1; }
cd "$WIKI" || exit 1

N=0
report() { N=$((N + 1)); printf '  %s\n' "$1"; }

echo "== wiki 정합성 체크 ($WIKI) =="

# 1) index.md 미등록 — 카탈로그에 안 걸리면 사실상 고아(_schema "새 페이지 = index 한 줄 등록")
echo "[1] index 미등록"
for f in *.md; do
  case "$f" in _schema.md | index.md) continue ;; esac
  grep -q "\[\[${f%.md}\]\]" index.md 2>/dev/null || report "$f — index.md에 [[${f%.md}]] 등록 없음"
done

# 2) 깨진 [[링크]] — _schema.md는 형식 예시([[slug]] 등)라 제외.
#    POSIX 문자클래스([[:space:]] 등)는 링크가 아니므로 걸러낸다(gstack-install-windows.md 오탐).
echo "[2] 깨진 [[링크]]"
BROKEN=$(for f in *.md; do
  [ "$f" = "_schema.md" ] && continue
  grep -oh '\[\[[^]]*\]\]' "$f" 2>/dev/null | tr -d '[]' | sort -u | while read -r s; do
    case "$s" in :*:) continue ;; esac
    [ -f "$s.md" ] || printf '%s → [[%s]] 대상 없음\n' "$f" "$s"
  done
done)
if [ -n "$BROKEN" ]; then
  printf '%s\n' "$BROKEN" | sed 's/^/  /'
  N=$((N + $(printf '%s\n' "$BROKEN" | wc -l | tr -d ' ')))
fi

# 3) frontmatter 결손 — gotcha의 sources는 _schema가 "가능한 한 필수"로 규정.
#    근거 유실이 확정된 옛 페이지는 `sources: (pre-inbox, 근거 유실)`로 명시하면 통과한다.
echo "[3] frontmatter 결손"
for f in *.md; do
  case "$f" in _schema.md | index.md) continue ;; esac
  [ -s "$f" ] || { report "$f — 빈 파일"; continue; }
  grep -q '^title:' "$f" || report "$f — title 없음"
  grep -q '^updated:' "$f" || report "$f — updated 없음"
  if grep -q '^type: *gotcha' "$f" && ! grep -q '^sources:' "$f"; then
    report "$f — gotcha인데 sources 없음"
  fi
done

echo
if [ "$N" -eq 0 ]; then
  echo "정합성 OK (페이지 $(ls -1 *.md | wc -l | tr -d ' ')개)"
  exit 0
fi
echo "발견 ${N}건 — 모순·stale claim은 이 스크립트가 못 잡는다(사람 점검)."
exit 1
