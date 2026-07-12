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

# 3) gstack staleness 체크 (마지막 갱신 후 7일 초과 시 gstack-upgrade 권장)
#    네트워크 0 — gstack VERSION 파일 mtime 기준(gstack-upgrade=git pull 시 갱신됨).
#    자체 스킬은 repo SSOT라 sync 넛지 불요(v3.11.0). 외부 grill-with-docs는 수동 게이트라 시간 넛지 안 함.
GSTACK_VER_FILE="${HOME}/.claude/skills/gstack/VERSION"
if [ -f "$GSTACK_VER_FILE" ]; then
  GVER=$(grep -oE '[0-9]+(\.[0-9]+)+' "$GSTACK_VER_FILE" | head -1)
  # mtime epoch: GNU(stat -c) / BSD·macOS(stat -f) fallback
  GTS=$(stat -c %Y "$GSTACK_VER_FILE" 2>/dev/null || stat -f %m "$GSTACK_VER_FILE" 2>/dev/null)
  NOW_TS=$(date +%s)
  if [ -n "$GTS" ] && [ -n "$NOW_TS" ]; then
    GDAYS=$(( (NOW_TS - GTS) / 86400 ))
    if [ "$GDAYS" -ge 7 ]; then
      MESSAGES+=("⚠ gstack 마지막 갱신 ${GDAYS}일 경과 (v${GVER:-?}) — /gstack-upgrade 권장")
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

# 6) gstack 글로벌 의존 점검 (미설치/미등록 시 설치 안내 — 순수 안내, 자동 설치 없음)
#    하네스는 gstack 스킬(plan-*-review·office-hours·cso·review·context-save/restore 등)을
#    repo에 vendoring하지 않고 글로벌 gstack에 의존한다. 없으면 슬래시/Read가 빗나간다.
GSTACK_HOME="${HOME}/.claude/skills/gstack"
GSTACK_INSTALL="git clone --single-branch --depth 1 https://github.com/garrytan/gstack.git ~/.claude/skills/gstack && cd ~/.claude/skills/gstack && ./setup --no-prefix"
if [ ! -f "$GSTACK_HOME/SKILL.md" ]; then
  MESSAGES+=("⚠ gstack 미설치 — 설계패널 plan-*-review·계획리뷰·context-save/restore 등 사용 불가. 설치(글로벌): ${GSTACK_INSTALL}")
elif [ ! -f "${HOME}/.claude/skills/context-save/SKILL.md" ]; then
  # gstack 클론은 됐으나 setup --no-prefix 미실행 → top-level 등록 없음 → 슬래시 호출 불가
  MESSAGES+=("⚠ gstack 설치됨·스킬 미등록 — 슬래시 호출(/context-save 등) 불가. 등록: cd ~/.claude/skills/gstack && ./setup --no-prefix")
fi

# 7) wiki 운영지식 카탈로그 인지 (읽기 트리거 — 작업/디버깅 전 관련 gotcha 참조 유도)
WIKI_DIR="$PROJECT_DIR/.claude/wiki"
if [ -d "$WIKI_DIR" ]; then
  WIKI_COUNT=$(find "$WIKI_DIR" -maxdepth 1 -name '*.md' ! -name '_*' ! -name 'index.md' 2>/dev/null | wc -l | tr -d ' ')
  if [ "$WIKI_COUNT" -gt 0 ]; then
    MESSAGES+=("📚 wiki 운영지식 ${WIKI_COUNT}건 (카탈로그: wiki/index.md) — 디버깅·훅·테스트·codex·PATH 작업 전 관련 gotcha 먼저 Grep")
  fi
fi

# 8) 현재 워크트리 활성 기능 surface (병렬 워크트리 관리 — "이 워크트리=이 기능=이 테스트")
#    docs/features/ 의 in-progress 문서(= '## 완료' 없음)만 표출 → 완료본 노이즈 배제, 무해 침묵.
#    데이터는 planner(요구사항)·tester-design(테스트설계)이 이미 쌓음. 세션시작 자동표출만 신설.
FEATURES_DIR="$PROJECT_DIR/docs/features"
if [ -d "$FEATURES_DIR" ]; then
  ACTIVE=""        # 최신 in-progress 문서
  ACTIVE_N=0       # in-progress 총 건수
  # 파일명 YYYYMMDD 프리픽스가 정렬순 → sort -r 로 최신 우선
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    grep -q '^## 완료' "$f" 2>/dev/null && continue   # 완료본 스킵
    ACTIVE_N=$((ACTIVE_N + 1))
    [ -z "$ACTIVE" ] && ACTIVE="$f"
  done <<< "$(find "$FEATURES_DIR" -maxdepth 1 -name '*.md' -type f 2>/dev/null | sort -r)"

  if [ -n "$ACTIVE" ]; then
    FNAME=$(basename "$ACTIVE" .md | sed 's/^[0-9]\{8\}-//; s/^[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}-//')
    # 단계 판정 (섹션 존재 기반)
    if grep -q '^## 테스트 결과' "$ACTIVE" 2>/dev/null; then STAGE="테스트中(변경검증)"
    elif grep -q '^## 테스트 설계' "$ACTIVE" 2>/dev/null; then STAGE="테스트 설계됨"
    else STAGE="설계中(테스트 미설계)"; fi
    # 테스트 케이스 수 best-effort (필수 테스트 케이스 섹션 하위 항목)
    TC=$(awk '/^### 필수 테스트 케이스/{f=1;next} /^#{2,3} /{if(f)exit} f&&/^([0-9]+\.|-|\*)/{c++} END{print c+0}' "$ACTIVE" 2>/dev/null)
    [ -z "$TC" ] && TC=0
    TC_TXT=""; [ "$TC" -gt 0 ] 2>/dev/null && TC_TXT=" / 테스트케이스 ${TC}건"
    # 미커밋 초안 여부 (repo-root 상대 경로로 조회)
    REL="docs/features/$(basename "$ACTIVE")"
    DRAFT=""
    if [ -n "$(git -C "$PROJECT_DIR" status --porcelain -- "$REL" 2>/dev/null)" ]; then DRAFT=" ⚠미커밋 초안"; fi
    BR=$(git -C "$PROJECT_DIR" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "?")
    EXTRA=""; [ "$ACTIVE_N" -gt 1 ] && EXTRA=" (외 진행 ${ACTIVE_N}건 — 전체: worktree-status.sh)"
    MESSAGES+=("🌿 이 워크트리[${BR}] 활성 기능: ${FNAME} — ${STAGE}${TC_TXT}${DRAFT}${EXTRA}")
  fi
fi

# 9) 하네스 재사용 drift 조기경고 (복제 재사용 시 프로젝트별 값 미갱신 — 세션시작 백스톱)
#    setup-time 가드(harness-setup SKILL §310/312)·런타임 가드(orchestrator 보안SSOT)의 세션시작 짝.
#    CLAUDE.md Harness Config 없는 dev clone은 자동 침묵. 경로 파싱 best-effort(못 잡으면 침묵 — false-positive 안 냄).
CLAUDE_MD="$PROJECT_DIR/CLAUDE.md"
if [ -f "$CLAUDE_MD" ]; then
  # 9a) memoryDir 실재 — CLAUDE.md 값이 가리키는 경로가 없으면 실패패턴 저장 불가
  MEMDIR=$(grep -iE 'memoryDir' "$CLAUDE_MD" 2>/dev/null | grep -oE '[A-Za-z]:\\[^ |`]+|/[^ |`]+/memory/?' | head -1)
  if [ -n "$MEMDIR" ]; then
    MEMDIR_UNIX=$(printf '%s' "$MEMDIR" | sed 's#\\#/#g; s#^\([A-Za-z]\):#/\L\1#')
    if [ ! -d "$MEMDIR_UNIX" ]; then
      MESSAGES+=("⚠ 하네스 drift: CLAUDE.md memoryDir 경로 부재(${MEMDIR}) — 복제 재사용 후 미갱신 의심. 실패패턴·학습 저장 불가. /harness-setup 재실행 또는 경로 수정 권장")
    fi
  fi
  # 9b) 보안 SSOT — 실파일은 gitignore(프로젝트별 산출물). template만 커밋되므로 clone 직후엔 실파일 부재.
  #      부재: template 복사·현지화 안내. 존재+프로젝트명 불일치: 타 프로젝트 잔재 경고.
  SEC_MD="$PROJECT_DIR/.claude/claude-security-guidance.md"
  SEC_TMPL="$PROJECT_DIR/.claude/claude-security-guidance.md.template"
  PROJNAME=$(grep -iE 'projectName' "$CLAUDE_MD" 2>/dev/null | grep -oE '`[^`]+`' | tail -1 | tr -d '`')
  if [ ! -f "$SEC_MD" ] && [ -f "$SEC_TMPL" ]; then
    MESSAGES+=("⚠ 보안 SSOT 미생성: claude-security-guidance.md 없음(gitignore·프로젝트별) — template 복사 후 현지화 권장(/harness-setup 또는 수동). 미생성 시 /cso는 제너릭 OWASP 폴백")
  elif [ -f "$SEC_MD" ] && [ -n "$PROJNAME" ]; then
    if ! head -3 "$SEC_MD" 2>/dev/null | grep -q "$PROJNAME"; then
      MESSAGES+=("⚠ 하네스 drift: 보안 SSOT(claude-security-guidance.md)가 현 프로젝트(${PROJNAME}) 명시 안 함 — 타 프로젝트 스택 기준일 수 있음. /cso 심사 전 현지화 확인")
    fi
  fi
  # 9c) 도메인 용어집 오염 감지 — 프로젝트 도메인 용어는 contextPath(product 추적)에 둬야 하고
  #      .claude/CONTEXT.md(공유 하네스)에 두면 타 프로젝트로 오염된다. 실파일은 gitignore(template만 커밋).
  CTX_TMPL="$PROJECT_DIR/.claude/CONTEXT.md.template"
  CTX_IN_CLAUDE="$PROJECT_DIR/.claude/CONTEXT.md"
  CTXPATH=$(grep -iE 'contextPath' "$CLAUDE_MD" 2>/dev/null | grep -oE '`[^`]+`' | tail -1 | tr -d '`')
  if [ -f "$CTX_IN_CLAUDE" ] && grep -q "프로젝트 특화" "$CTX_TMPL" 2>/dev/null; then
    # .claude/CONTEXT.md 실파일이 존재 = 공유 하네스에 용어집이 눌러앉음(오염 경로). template과 구분: 플레이스홀더 남았으면 미현지화, 없으면 도메인용어 유입 의심
    if ! head -5 "$CTX_IN_CLAUDE" 2>/dev/null | grep -q "템플릿"; then
      MESSAGES+=("⚠ 용어집 오염 위험: .claude/CONTEXT.md에 도메인 용어가 있음 — 공유 하네스(.claude/)라 타 프로젝트로 오염된다. contextPath(product 추적 경로)로 옮기고 .claude/ 사본은 제거 권장")
    fi
  elif [ -z "$CTXPATH" ] && [ -f "$CTX_TMPL" ]; then
    MESSAGES+=("ℹ 용어집 미설정: CLAUDE.md에 contextPath 미선언 — CONTEXT.md.template을 product 추적 경로로 복사 후 Harness Configuration에 contextPath 선언 권장(grill/co-plan 용어 쓰기 대상)")
  fi
fi

# 회고 inbox pending 알림은 SessionStart가 아니라 UserPromptSubmit(매 프롬프트)로 처리한다.
#   dev clone은 자체 .claude/가 없어 이 session-check(repo 훅)가 안 걸린다 → 글로벌 등록 필요.
#   → hooks/harness-inbox-nudge.sh + 글로벌 ~/.claude/settings.json UserPromptSubmit (README §inbox 알림).

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
