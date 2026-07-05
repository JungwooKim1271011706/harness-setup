#!/bin/bash
# 워크트리 × 기능 대시보드 — 병렬 개발 시 "어느 워크트리가 무슨 기능·테스트를 물고 있나" 한눈 뷰.
# session-check.sh #8이 '현재 워크트리 1개'를 표출한다면, 이건 '전 워크트리 교차 뷰'다.
# 데이터 소스: 각 워크트리의 docs/features/*.md (planner 요구사항 + tester-design 테스트설계).
# 읽기 전용 — git/파일 변형 없음. 사용: bash .claude/scripts/worktree-status.sh  (dev clone: bash scripts/worktree-status.sh)
set -u

# 기능 문서 1개 파싱 → "단계|테스트케이스수" 출력 (in-progress 판정은 호출측)
parse_stage() {
  local f="$1" stage tc
  if grep -q '^## 테스트 결과' "$f" 2>/dev/null; then stage="테스트中"
  elif grep -q '^## 테스트 설계' "$f" 2>/dev/null; then stage="테스트설계"
  else stage="설계中"; fi
  tc=$(awk '/^### 필수 테스트 케이스/{f=1;next} /^#{2,3} /{if(f)exit} f&&/^([0-9]+\.|-|\*)/{c++} END{print c+0}' "$f" 2>/dev/null)
  [ -z "$tc" ] && tc=0
  printf '%s|%s' "$stage" "$tc"
}

feat_name() { basename "$1" .md | sed 's/^[0-9]\{8\}-//; s/^[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}-//'; }

# git worktree list --porcelain 파싱: worktree/branch 쌍 수집
declare -a WT_PATHS WT_BRANCHES
cur_path=""; cur_branch=""
while IFS= read -r line; do
  case "$line" in
    "worktree "*) cur_path="${line#worktree }" ;;
    "branch "*)   cur_branch="${line#branch refs/heads/}" ;;
    "detached")   cur_branch="(detached)" ;;
    "")           # 레코드 끝
      if [ -n "$cur_path" ]; then WT_PATHS+=("$cur_path"); WT_BRANCHES+=("${cur_branch:-?}"); fi
      cur_path=""; cur_branch="" ;;
  esac
done < <(git worktree list --porcelain 2>/dev/null)
# 마지막 레코드 (trailing blank 없을 때)
[ -n "$cur_path" ] && { WT_PATHS+=("$cur_path"); WT_BRANCHES+=("${cur_branch:-?}"); }

if [ "${#WT_PATHS[@]}" -eq 0 ]; then
  echo "워크트리 없음 (git worktree list 비어있음 — git repo 아님?)"
  exit 0
fi

echo "═══════════════════════════════════════════════════════════════"
echo " 워크트리 × 기능 대시보드  ($(date +%Y-%m-%d\ %H:%M))"
echo "═══════════════════════════════════════════════════════════════"

TOTAL_ACTIVE=0
for i in "${!WT_PATHS[@]}"; do
  wt="${WT_PATHS[$i]}"; br="${WT_BRANCHES[$i]}"
  fdir="$wt/docs/features"
  echo ""
  echo "🌿 [$br]  $wt"
  if [ ! -d "$fdir" ]; then
    echo "     (docs/features/ 없음 — 미착수 or 하네스 미적용)"
    continue
  fi
  found=0 done_n=0
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    if grep -q '^## 완료' "$f" 2>/dev/null; then done_n=$((done_n+1)); continue; fi
    IFS='|' read -r stage tc <<< "$(parse_stage "$f")"
    rel="docs/features/$(basename "$f")"
    draft=""; [ -n "$(git -C "$wt" status --porcelain -- "$rel" 2>/dev/null)" ] && draft=" ⚠미커밋"
    tctxt=""; [ "$tc" -gt 0 ] 2>/dev/null && tctxt="  테스트 ${tc}건"
    printf "     ▸ %-40s %s%s%s\n" "$(feat_name "$f")" "$stage" "$tctxt" "$draft"
    found=$((found+1)); TOTAL_ACTIVE=$((TOTAL_ACTIVE+1))
  done < <(find "$fdir" -maxdepth 1 -name '*.md' -type f 2>/dev/null | sort -r)
  [ "$found" -eq 0 ] && echo "     (활성 기능 없음 — 완료 ${done_n}건)"
  [ "$found" -gt 0 ] && [ "$done_n" -gt 0 ] && echo "     · 완료 ${done_n}건"
done

echo ""
echo "───────────────────────────────────────────────────────────────"
echo " 워크트리 ${#WT_PATHS[@]}개 · 활성 기능 ${TOTAL_ACTIVE}건"
echo "═══════════════════════════════════════════════════════════════"
