#!/bin/bash
# PreToolUse(Edit|Write|MultiEdit) 훅 — orchestrator 메인스레드의 제품소스 직접편집 차단.
# 판별: agent_id 없음 = orchestrator 메인. 있음 = 서브에이전트(developer-*/finalizer) → 허용.
# **허용리스트 방식(fail-closed, v2)**: repo 안에서 하네스·문서 경로만 allow, 나머지 = 제품소스로 보고 deny.
#   v1은 차단리스트(특정 모듈명 하드코딩)라 그 이름을 안 쓰는 프로젝트에선 **아무것도 못 막았다**
#   (2026-07-26 실측: 한 소비자 프로젝트의 제품코드가 `src/**`라 매치 0 → "기계강제"가 통째로 사망).
#   CLAUDE.md `modules`로 유도하는 안은 폐기 — 값이 자유서술이라 파싱 불가
#   (한쪽은 백틱 리스트 `` `autopatch`, `cm/tocServer` ``, 한쪽은 산문 "단일 Electron 앱 — 제품코드 src/**").
#   그래서 "무엇이 제품인가"를 열거하지 않고 **"무엇이 제품이 아닌가"**만 열거한다 — 프로젝트 구조 무관하게 성립.
# 차단 시 exit 2 + stderr → Claude가 사유 받고 developer-* 위임으로 전환.
#
# 알려진 구멍:
#   ① Bash `sed -i`/`tee`로 제품소스 편집은 못 잡는다(Edit/Write/MultiEdit 도구만 대상).
#      orchestrator가 sed로 소스편집할 현실 트리거가 거의 0이라 봉쇄 복잡도 대비 실익 없어 제외.
#      필요 시 block-orchestrator-exec.sh(Bash 훅) 확장.
#   ② 훅 PATH에 `git`이 없으면 repo 루트를 못 구해 통과한다(fail-open). Windows stale PATH 계열
#      함정(`wiki/windows-path-jq.md`)과 같은 축. 다른 훅들도 같은 전제라 여기만 자가탐색하지 않는다.
#   ③ file_path 추출 실패(빈 값) 시 통과. Edit/Write/MultiEdit는 항상 file_path를 주므로 정상 경로엔 없음.

input=$(cat)

# jq 있으면 사용, 없으면 grep 폴백
if command -v jq >/dev/null 2>&1; then
  agent_id=$(printf '%s' "$input" | jq -r '.agent_id // empty' 2>/dev/null)
  file_path=$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
else
  # 폴백(jq 부재): 값만 거칠게 추출. file_path 값만 잡아 오탐 감소.
  agent_id=$(printf '%s' "$input" | sed -n 's/.*"agent_id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
  file_path=$(printf '%s' "$input" | sed -n 's/.*"file_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
fi

# 서브에이전트(agent_id 존재) → 허용 (developer-* 구현, finalizer 정리 등 정상)
[ -n "$agent_id" ] && exit 0

[ -z "$file_path" ] && exit 0

# 경로 정규화: 백슬래시→슬래시, 중복 슬래시 축약, 드라이브문자 → /c 형태, 소문자화.
#   ⚠ 중복 슬래시 축약이 필수다 — jq 부재 폴백은 JSON 이스케이프(`C:\\Users`)를 그대로 뽑아
#   `tr`이 `C://Users`로 만든다 → repo root prefix 매치 실패 → 조용한 fail-open(2026-07-26 실측).
norm() {
  printf '%s' "$1" | tr '\\' '/' | sed -e 's#//*#/#g' -e 's#^\([A-Za-z]\):#/\1#' \
    | tr '[:upper:]' '[:lower:]'
}

ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
[ -z "$ROOT" ] && exit 0          # git repo 밖 → 판정 불가, 통과

NF=$(norm "$file_path")
NR=$(norm "$ROOT")

# repo 밖(스크래치패드, ~/.claude/harness-retro-inbox, 프로젝트 밖 memoryDir 등) → 허용.
# 상대경로면 cwd=repo root 전제로 그대로 rel 취급.
case "$NF" in
  /*|[a-z]:/*) case "$NF" in "$NR"/*) REL="${NF#"$NR"/}" ;; *) exit 0 ;; esac ;;
  *) REL="$NF" ;;
esac

# 허용 경로 — "제품소스가 아닌 것"만 열거(프로젝트 구조 무관):
#   .claude/**  하네스 자가수정 + agent-memory + state (소비자의 memoryDir이 여기인 경우 포함)
#   docs/**     feature 문서 append(orchestrator 워크스루 기록)·설계 문서
#   루트 *.md   CLAUDE.md·CONTEXT.md(contextPath 용어집)·README·TODOS 등
#   .<도구>/**  repo 안에 눌러앉은 **gitignored 툴 아티팩트**(.gstack 리포트·.omc 상태·.vscode/.idea 설정 등).
#               제품소스가 아니고 빌드 산출도 아니라 orchestrator가 직접 쓰는 게 정상이다.
#               ⚠ `git check-ignore` 호출로 일반화하지 않는다 — 훅에 git 의존이 하나 더 늘고
#               (기존 구멍 ②: PATH에 git 없으면 fail-open) target/·node_modules 같은 빌드산출까지
#               열려 오히려 넓어진다. **점으로 시작하는 디렉터리**로 한정하는 게 좁고 안전.
# 그 외 repo 내부 = 제품소스 → 차단.
case "$REL" in
  .claude/*) exit 0 ;;
  docs/*) exit 0 ;;
  .*/*) exit 0 ;;                  # 루트의 dot-디렉터리 하위 (.gstack/ .omc/ .vscode/ .idea/ 등)
  */*) ;;                          # 그 외 하위 경로 → 아래서 차단
  *.md) exit 0 ;;                  # 루트 직속 마크다운만 허용(pom.xml·package.json 등은 차단)
esac

echo "[hook] 오케스트레이터 제품소스 직접편집 금지 — 구현·수정은 developer-backend/developer-frontend에 위임하라. (차단 file_path: ${file_path})
      허용: .claude/** · docs/** · 루트 *.md · 루트 dot-디렉터리(.gstack/ 등) · repo 밖. 이 경로가 제품소스가 아닌데 막혔다면 하네스 개선 후보다(/harness-check)." >&2
exit 2
