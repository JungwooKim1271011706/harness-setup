#!/bin/bash
# .claude/skills/sync-skills.sh
# 하네스 스킬 동기화 스크립트
# 사용법: bash .claude/skills/sync-skills.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TODAY=$(date +%Y-%m-%d)

# 하드코딩 참조 스킬 — 변경 시 사용자 검토 필요
CRITICAL_SKILLS=("learning-gate" "grill-with-docs")

# 소스 경로 매핑 (글로벌 → 로컬)
# gstack 제공 스킬: gstack 글로벌 설치(~/.claude/skills/gstack/<skill>)가 원본. gstack-upgrade로 갱신됨.
declare -A SOURCES
SOURCES["office-hours"]="$HOME/.claude/skills/gstack/office-hours"
SOURCES["investigate"]="$HOME/.claude/skills/gstack/investigate"
SOURCES["review"]="$HOME/.claude/skills/gstack/review"
SOURCES["cso"]="$HOME/.claude/skills/gstack/cso"
SOURCES["benchmark"]="$HOME/.claude/skills/gstack/benchmark"
SOURCES["codex"]="$HOME/.claude/skills/gstack/codex"
SOURCES["browse"]="$HOME/.claude/skills/gstack/browse"
# 자체/비-gstack 스킬: gstack에 없음. 원본 부재 시 sync는 "소스 없음"으로 스킵(미러로 동작은 유지).
#   co-plan·pair-impl·learning-gate: gstack 미제공. grill-with-docs: ~/.agents 소스.
SOURCES["co-plan"]="$HOME/.claude/skills/co-plan"
SOURCES["pair-impl"]="$HOME/.claude/skills/pair-impl"
SOURCES["learning-gate"]="$HOME/.claude/skills/learning-gate"
SOURCES["grill-with-docs"]="$HOME/.agents/skills/grill-with-docs"

echo "=== 하네스 스킬 동기화 ==="
echo ""

AUTO_UPDATED=()
CRITICAL_CHANGED=()
NO_CHANGE=()

for skill in "${!SOURCES[@]}"; do
  src="${SOURCES[$skill]}"
  dst="$SCRIPT_DIR/$skill"

  # 소스 없으면 스킵
  if [ ! -f "$src/SKILL.md" ]; then
    echo "⚠  소스 없음: $skill"
    continue
  fi

  # [BUG FIX 3] 변경 여부 확인: SKILL.md만 비교 → 전체 .md 파일 비교
  no_change=true
  while IFS= read -r f; do
    rel="${f#$src/}"
    if [ ! -f "$dst/$rel" ] || ! diff -q "$f" "$dst/$rel" > /dev/null 2>&1; then
      no_change=false
      break
    fi
  done < <(find "$src" -name "*.md")
  if $no_change; then
    NO_CHANGE+=("$skill")
    continue
  fi

  # 하드코딩 참조 스킬 여부 판단
  is_critical=false
  for critical in "${CRITICAL_SKILLS[@]}"; do
    [[ "$skill" == "$critical" ]] && is_critical=true && break
  done

  if $is_critical; then
    CRITICAL_CHANGED+=("$skill")
  else
    # 일반 스킬: 디렉터리 전체 복사 (.md 외 supporting files 포함)
    mkdir -p "$dst"
    if command -v rsync >/dev/null 2>&1; then
      rsync -a --delete --exclude ".git" "$src/" "$dst/"
    else
      # rsync 없는 환경 (Windows Git Bash 등) fallback
      cp -r "$src/." "$dst/"
    fi
    AUTO_UPDATED+=("$skill")
    echo "✅ [$skill] 자동 업데이트 완료"
  fi
done

# 하드코딩 참조 스킬 알림
if [ ${#CRITICAL_CHANGED[@]} -gt 0 ]; then
  echo ""
  echo "--- ⚠ 하드코딩 참조 스킬 변경 감지 ---"
  for skill in "${CRITICAL_CHANGED[@]}"; do
    echo "⚠  [$skill] 변경됨 — 수동 검토 후 적용 필요"
    case $skill in
      "learning-gate")
        echo "   확인 위치: orchestrator.md → '학습 게이트 완료. 계속 진행해.' 트리거 문구"
        ;;
      "grill-with-docs")
        echo "   확인 위치: orchestrator.md → CONTEXT.md 업데이트 포맷"
        ;;
    esac
    echo "   수동 적용: cp $HOME/.claude/skills/$skill/SKILL.md $SCRIPT_DIR/$skill/SKILL.md"
  done
fi

# 변경 없음
if [ ${#AUTO_UPDATED[@]} -eq 0 ] && [ ${#CRITICAL_CHANGED[@]} -eq 0 ]; then
  echo "✅ 모든 스킬이 최신 상태입니다."
fi

# versions.md 날짜 갱신
if [ ${#AUTO_UPDATED[@]} -gt 0 ] || [ ${#CRITICAL_CHANGED[@]} -eq 0 ]; then
  VERSIONS_FILE="$SCRIPT_DIR/versions.md"
  # [BUG FIX 2] sed -i: macOS는 "" 필요, Linux/Windows는 불필요
  if [[ "$(uname)" == "Darwin" ]]; then
    sed -i "" "s/\*\*마지막 전체 동기화\*\*: [0-9-]*/\*\*마지막 전체 동기화\*\*: $TODAY/" "$VERSIONS_FILE"
  else
    # Linux / Windows Git Bash (GNU sed)
    sed -i "s/\*\*마지막 전체 동기화\*\*: [0-9-]*/\*\*마지막 전체 동기화\*\*: $TODAY/" "$VERSIONS_FILE"
  fi
  echo ""
  echo "versions.md 갱신: $TODAY"
fi

echo ""
echo "=== 완료 ==="
