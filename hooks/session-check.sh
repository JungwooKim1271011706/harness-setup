#!/bin/bash
# SessionStart hook: 실패 패턴 / 컨텍스트 / 스킬 동기화 / 기능스캔 / 하네스 버전 drift 점검
# stdin(JSON)에서 session_id·source를 읽어 버전 drift 안내에 사용한다.
INPUT=$(cat 2>/dev/null)
PROJECT_DIR=$(git rev-parse --show-toplevel 2>/dev/null)
if [ -z "$PROJECT_DIR" ]; then
  exit 0
fi

# stdin 파싱 (session_id, source). sed 추출 — python 의존 없음(이 머신 python3는 Windows Store 스텁이라 사용 불가).
SESSION_ID=""
SOURCE=""
if [ -n "$INPUT" ]; then
  SESSION_ID=$(printf '%s' "$INPUT" | sed -n 's/.*"session_id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
  SOURCE=$(printf '%s' "$INPUT" | sed -n 's/.*"source"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
fi
[ -z "$SESSION_ID" ] && SESSION_ID="ppid-$PPID"

MESSAGES=()

# 1) failure 패턴 미처리 건수 체크
FAIL_COUNT=$(find "$PROJECT_DIR/.claude/agent-memory" -name "failure_*.md" 2>/dev/null | wc -l | tr -d ' ')
if [ "$FAIL_COUNT" -gt 0 ]; then
  MESSAGES+=("⚠ 미처리 실패 패턴 ${FAIL_COUNT}건 — 하네스 자가 점검 권장 (/harness-check)")
fi

# 2) 최근 24시간 내 저장된 컨텍스트 안내 (자동 로드 X, 안내만 — R1 정책)
GSTACK_SLUG=""
GSTACK_SLUG_BIN="${HOME}/.claude/skills/gstack/bin/gstack-slug"
if [ -x "$GSTACK_SLUG_BIN" ]; then
  # gstack-slug는 'SLUG=...' 형태로 export 명령을 출력
  eval "$("$GSTACK_SLUG_BIN" 2>/dev/null)" 2>/dev/null || true
  GSTACK_SLUG="${SLUG:-}"
fi
if [ -z "$GSTACK_SLUG" ]; then
  GSTACK_SLUG=$(basename "$PROJECT_DIR")
fi
CHECKPOINT_DIR="${HOME}/.gstack/projects/${GSTACK_SLUG}/checkpoints"
if [ -d "$CHECKPOINT_DIR" ]; then
  # -mtime -1 = 24시간 이내 (GNU find, BSD find 모두 지원)
  RECENT=$(find "$CHECKPOINT_DIR" -maxdepth 1 -name "*.md" -mtime -1 -type f 2>/dev/null | sort -r | head -1)
  if [ -n "$RECENT" ]; then
    # 파일명에서 제목 추출 (형식: YYYYMMDD-HHMMSS-제목.md)
    TITLE=$(basename "$RECENT" .md | sed 's/^[0-9]\{8\}-[0-9]\{6\}-//')
    MESSAGES+=("📌 최근 저장 컨텍스트 있음: ${TITLE} — 이어가시려면 /context-restore")
  fi
fi

# 3) 스킬 동기화 날짜 체크 (versions.md 기준 7일 초과 시 경고)
VERSIONS="$PROJECT_DIR/.claude/skills/versions.md"
if [ -f "$VERSIONS" ]; then
  LAST_SYNC=$(grep -o '[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}' "$VERSIONS" | head -1)
  if [ -n "$LAST_SYNC" ]; then
    TODAY=$(date +%Y-%m-%d)
    # macOS(date -j) / Linux(date -d) 모두 지원
    if date --version 2>/dev/null | grep -q GNU; then
      TODAY_TS=$(date -d "$TODAY" +%s 2>/dev/null)
      SYNC_TS=$(date -d "$LAST_SYNC" +%s 2>/dev/null)
    else
      TODAY_TS=$(date -j -f "%Y-%m-%d" "$TODAY" +%s 2>/dev/null)
      SYNC_TS=$(date -j -f "%Y-%m-%d" "$LAST_SYNC" +%s 2>/dev/null)
    fi
    if [ -n "$TODAY_TS" ] && [ -n "$SYNC_TS" ]; then
      DAYS=$(( (TODAY_TS - SYNC_TS) / 86400 ))
      if [ "$DAYS" -ge 7 ]; then
        MESSAGES+=("⚠ 스킬 동기화 ${DAYS}일 경과 (마지막: ${LAST_SYNC}) — sync-skills.sh 실행 권장")
      fi
    fi
  fi
fi

# 4) 하네스 기능 스캔 staleness (CC 신기능·웹 모범사례 주기 점검, 기본 30일)
#    네트워크 0 — timestamp 파일만 확인. 실제 스캔은 orchestrator가 백그라운드 Workflow로 수행.
SCAN_THRESHOLD_DAYS=30
SCAN_STAMP="$PROJECT_DIR/.claude/state/last-feature-scan"
SCAN_DUE=0
SCAN_LAST="(없음)"
if [ -f "$SCAN_STAMP" ]; then
  SCAN_LAST=$(grep -o '[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}' "$SCAN_STAMP" | head -1)
  if [ -n "$SCAN_LAST" ]; then
    TODAY=$(date +%Y-%m-%d)
    if date --version 2>/dev/null | grep -q GNU; then
      TODAY_TS=$(date -d "$TODAY" +%s 2>/dev/null)
      SCAN_TS=$(date -d "$SCAN_LAST" +%s 2>/dev/null)
    else
      TODAY_TS=$(date -j -f "%Y-%m-%d" "$TODAY" +%s 2>/dev/null)
      SCAN_TS=$(date -j -f "%Y-%m-%d" "$SCAN_LAST" +%s 2>/dev/null)
    fi
    if [ -n "$TODAY_TS" ] && [ -n "$SCAN_TS" ]; then
      SCAN_DAYS=$(( (TODAY_TS - SCAN_TS) / 86400 ))
      [ "$SCAN_DAYS" -ge "$SCAN_THRESHOLD_DAYS" ] && SCAN_DUE=1
    fi
  else
    SCAN_DUE=1
  fi
else
  SCAN_DUE=1  # 한 번도 스캔 안 함 → due
fi
if [ "$SCAN_DUE" -eq 1 ]; then
  MESSAGES+=("🔍 HARNESS_FEATURE_SCAN_DUE (마지막: ${SCAN_LAST}, 임계 ${SCAN_THRESHOLD_DAYS}일) — orchestrator는 백그라운드 기능스캔 Workflow를 1회 throttled 런치할 것 (자동적용 금지, 백로그 매핑만)")
fi

# 5) 하네스 버전 drift 탐지 (세션 시작 시점 VERSION vs 현재 디스크 VERSION)
#    순수 안내 — 자동 sync/pull/재시작 없음. 설계: docs/harness-versioning.md
STATE_DIR="$PROJECT_DIR/.claude/state"
VERSION_FILE="$PROJECT_DIR/.claude/VERSION"
if [ -f "$VERSION_FILE" ]; then
  DISK_VER=$(grep -oE '[0-9]+\.[0-9]+\.[0-9]+' "$VERSION_FILE" | head -1)
  if [ -n "$DISK_VER" ]; then
    mkdir -p "$STATE_DIR" 2>/dev/null || true
    # 오래된 스탬프 청소 (mtime +1일)
    find "$STATE_DIR" -maxdepth 1 -name 'session-*.version' -mtime +1 -type f -delete 2>/dev/null || true
    # 파일명 안전화: session_id의 / 및 공백을 _로 치환
    SAFE_SID=$(printf '%s' "$SESSION_ID" | tr '/ :' '___')
    STAMP_FILE="$STATE_DIR/session-${SAFE_SID}.version"
    if [ "$SOURCE" = "startup" ] || [ ! -f "$STAMP_FILE" ]; then
      # 세션 시작: 현재 버전 기록, 무경고 (이미 최신을 들고 시작)
      printf '%s\n' "$DISK_VER" > "$STAMP_FILE" 2>/dev/null || true
    else
      # 비-startup(resume/compact/clear): 시작 시점 버전과 비교
      STAMP_VER=$(grep -oE '[0-9]+\.[0-9]+\.[0-9]+' "$STAMP_FILE" 2>/dev/null | head -1)
      if [ -n "$STAMP_VER" ] && [ "$STAMP_VER" != "$DISK_VER" ]; then
        DISK_MAJOR=${DISK_VER%%.*}
        STAMP_MAJOR=${STAMP_VER%%.*}
        if [ "$DISK_MAJOR" != "$STAMP_MAJOR" ]; then
          MESSAGES+=("🔁 하네스 버전 변경 v${STAMP_VER}→v${DISK_VER} (MAJOR) — 거버넌스/게이트 구조 변경. 세션 재시작 필수 (현재 세션은 옛 agent 정의를 사용 중). 사용자에게 재시작 안내.")
        else
          MESSAGES+=("🔁 하네스 버전 변경 v${STAMP_VER}→v${DISK_VER} — agent 정의/스킬 갱신됨. 세션 재시작 권장 (현재 세션 미반영). 사용자에게 안내.")
        fi
        # 스탬프 갱신 안 함 → 재시작 전까지 매 compact/resume 재알림
      fi
    fi
  fi
fi

# 메시지 없으면 조용히 종료
if [ ${#MESSAGES[@]} -eq 0 ]; then
  exit 0
fi

# Claude 컨텍스트에 주입 (additionalContext)
CONTEXT=""
for msg in "${MESSAGES[@]}"; do
  CONTEXT="${CONTEXT}${msg}\n"
done
# JSON 특수문자 이스케이프
ESCAPED=$(printf '%s' "$CONTEXT" | sed 's/\\/\\\\/g; s/"/\\"/g')
printf '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"%s"}}' "$ESCAPED"
