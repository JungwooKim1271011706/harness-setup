#!/bin/bash
# PreToolUse(Edit|Write|MultiEdit) 훅 — developer-* 서브에이전트의 테스트 파일 편집 차단.
# 목적(백로그 #8): GREEN 단계 reward-hacking/verifier-gaming 방어.
#   '작성자(codex/tester)≠구현자(developer)' 원칙을 글 권고 → 도구레벨 기계강제로 승격.
#   developer는 GREEN 구현만 한다(테스트 작성·수정은 7.5/7.7 작성자 몫). 따라서
#   developer가 테스트 파일을 건드리면 = 통과시키려 테스트 약화하는 reward-hacking 의심.
#   근거: ImpossibleBench(GPT-5가 RED 테스트 76% 익스플로잇), arXiv 2604.15149.
#
# 판별: agent_type으로 developer-backend/developer-frontend만 차단.
#   - tester-design/tester-* (테스트 합법 작성자) → 통과
#   - 메인 orchestrator(agent_type 없음) → 이 훅은 통과(테스트편집 안 하나, 한다면
#     block-orchestrator-edit.sh가 제품모듈로 이미 차단). 여기선 developer 한정.
#   - 그 외 서브에이전트(finalizer 등) → 통과(테스트 편집할 일 정상 없음, 막지 않음)
# 대상 경로: ① <module>/src/test/** (표준 Maven 백엔드 레이아웃)
#            ② 프론트 vitest/jest: *.spec.* / *.test.* (ts/tsx/js/jsx/mts/cts/vue) + __tests__/ 디렉터리.
#   백엔드만 막고 프론트(.spec.ts/.test.ts/__tests__)를 놓치면 developer-frontend가 프론트 테스트를
#   약화해 GREEN 위장(정기점검 2026-07-12 C3). 확장자/디렉터리 경계 앵커라 프로덕션 파일 오탐 없음.
# 차단 시 exit 2 + stderr → developer가 사유 받고 구현으로 복귀(테스트 약화 차단).
#
# 알려진 구멍(v1, #8과 동일 계열): Bash 내부쓰기(sed -i/tee/cp/> 리다이렉트/python·node
#   write)는 Edit/Write/MultiEdit 매처에 안 걸림(백로그 #13=구멍, #14=적극차단 훅 후보).
#   현실 트리거 낮아 v1 제외. 적극차단 시 PreToolUse(Bash) 훅이 명령 문자열을 스캔해
#   보호경로 대상 쓰기 동사를 차단(block-orchestrator-exec.sh 계열 확장). MAJOR(거버넌스).

input=$(cat)

if command -v jq >/dev/null 2>&1; then
  agent_type=$(printf '%s' "$input" | jq -r '.agent_type // empty' 2>/dev/null)
  file_path=$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
else
  agent_type=$(printf '%s' "$input" | sed -n 's/.*"agent_type"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
  file_path=$(printf '%s' "$input" | sed -n 's/.*"file_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
fi

# developer-* 만 대상. 그 외 agent_type(tester-*, finalizer, 빈값=메인)은 통과.
case "$agent_type" in
  developer-backend|developer-frontend) ;;
  *) exit 0 ;;
esac

# 테스트 경로면 차단: 백엔드 src/test/ + 프론트 *.spec.*/*.test.*/__tests__/ (절대·상대, /·\ 구분자)
if printf '%s' "$file_path" | grep -qiE '[/\\]src[/\\]test[/\\]|[/\\]__tests__[/\\]|\.(spec|test)\.(ts|tsx|js|jsx|mts|cts|vue)$'; then
  echo "[hook] developer는 테스트 파일을 편집할 수 없다 — 테스트 작성·수정은 7.5/7.7 작성자(codex/tester) 몫이다. GREEN 단계에서 기존 테스트를 약화하면 reward-hacking이다. 테스트가 틀렸다고 판단되면 구현을 멈추고 설계결함(DESIGN_MISMATCH)으로 orchestrator에 보고하라. (차단 file_path: ${file_path})" >&2
  exit 2
fi

exit 0
