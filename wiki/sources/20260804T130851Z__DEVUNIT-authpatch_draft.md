---
source_session: 단일 커밋 범위(start==end) 패치파일 추출 — TDD 풀사이클 (커밋 0a6e1d88 / 2177a7a0)
project: DEVUNIT-authpatch_draft (worktree feature-monitor-test-1)
date: 2026-08-04
detected_by: /harness-check (post_commit 자가점검)
signals: 과다루프 LOOP2/3 · 출력·런타임 실패 3회 · orchestrator 지시결함 3건
---

# 하네스 자가 회고 — 단일 커밋 범위 TDD 풀사이클

전 게이트 통과·커밋 완료했으나 **LOOP 2/3까지 소비**했다. 루프를 늘린 원인 중 상당수가 orchestrator 자신의 지시·검증 결함이었다.

---

## 후보 1 — 부정 단언만 요구한 지시가 공허 GREEN을 만든다 (우선순위: 높음)

**증상**: 7.7 반환에서 major M1을 "`parentIds=null` → **예외 없음** 1건"으로 지시했다. 작성자는 그대로 `doesNotThrowAnyException()` 단독 케이스를 만들었고, production이 아직 구 `check()`를 호출하는 동안 미스텁 mock이 `null`을 반환해 **우연히 통과**했다. 검증자(tester-backend)가 "hollow GREEN"으로 재지목 → 수정 라운드 1회 추가 소비.

**추정 원인**: orchestrator가 케이스를 지시할 때 부정 단언(예외 없음 / 로그 없음 / 호출 0회)만 명시하고 "그 경로가 실제로 실행됐다"를 증명하는 positive 짝을 요구하지 않았다. 작성자는 지시대로 썼을 뿐이다.

**제안 개선**: `playbook-tdd.md`의 7.7 반환 규칙(또는 7c.1)에 1줄 —
> 부정 단언(예외 없음·로그 없음·호출 0회) 케이스를 지시할 때는 **반드시 positive 상호작용 단언을 함께 요구**한다. 부정 단독은 "아무것도 실행 안 돼도 통과"한다.

**근거**: 이번 실행 7.6 재확인 라운드에서 tester-backend가 "M1 hollow GREEN — `doesNotThrowAnyException()`만 단언이라 '게이트 부재'와 '게이트가 올바르게 일반범위 배제'를 구분 못함"으로 보고. 수정(`verify(checker).checkDetailed(...)` 추가) 후 `WantedButNotInvoked`로 올바른 RED 전환 확인.

**관련 파일**: `.claude/docs/playbook-tdd.md`

---

## 후보 2 — 검증 서브에이전트가 탐색 폭주로 실행 없이 사망 (우선순위: 높음)

**증상**: tester-frontend 1회차가 **탐색에만 177k 토큰**(tool_uses 27)을 쓰고 vitest를 **단 한 번도 실행하지 못한 채** API 오류로 사망. 판정 0. 재발사 때 프롬프트에 "첫 행동은 vitest 실행이다. 소스 통독으로 시작하지 마라"를 명시하니 완주(126k, 실행 O).

**추정 원인**: tester 계열 agent md에 "검증 태스크는 실행 우선"이 없어, 모델이 소스 이해부터 하려 든다. 검증은 실행 결과가 곧 데이터인데 추론을 먼저 한다.

**제안 개선**: `tester-frontend.md` / `tester-backend.md`에 1줄 —
> 검증 태스크의 **첫 행동은 실행**(vitest / mvn)이다. Read는 FAIL 사유를 분류할 때 **그 케이스 주변만**. 전체 통독으로 시작하지 마라.

**근거**: 이번 실행 tester-frontend 1회차 사망(177359 tokens / 실행 0회) ↔ 2회차 완주. 동일 태스크·동일 대상, 차이는 프롬프트의 실행 우선 지시뿐.

**관련 파일**: `.claude/agents/tester/tester-frontend.md`, `.claude/agents/tester/tester-backend.md`

---

## 후보 3 — 디스크 반영 검증이 "제목 grep"에 그쳐 오판 (우선순위: 중)

**증상**: FE-18 케이스를 "미처리"로 판정하고 재작업을 지시했다. 실제로는 **이미 전제 단언이 본문에 적용돼 있었다**. 작성자가 "orchestrator의 '미처리' 판단과 실제 디스크 상태가 어긋나 있었음(이번 세션 추가 조치 없음)"으로 반환.

**추정 원인**: orchestrator.md의 "편집 위임 후 디스크 반영 검증" 규칙을 따라 Grep은 했으나, **케이스 제목만** 매칭했다. 수정은 제목이 아니라 **본문 단언 라인**에 들어갔으므로 제목 grep으로는 안 보인다.

**제안 개선**: `orchestrator.md`의 편집 검증 규칙에 1줄 —
> 케이스 단위 수정(단언 추가·강화)을 검증할 때는 **제목이 아니라 변경된 단언 라인**을 grep한다. 제목 매칭은 "케이스 존재"만 증명할 뿐 "수정 반영"을 증명하지 않는다.

**근거**: 이번 실행 FE 잔여 수정 라운드. 불필요한 위임 1회 발생(비용은 작았으나 판정 신뢰도 문제).

**관련 파일**: `.claude/agents/orchestrator.md`

---

## 후보 4 — 병렬 발사 선언과 실제 도구 호출 불일치 (우선순위: 중)

**증상**: "리뷰 3종 병렬(code-reviewer ∥ codex review ∥ design-reviewer)"이라 선언하고 발사했으나, 실제 한 메시지에 들어간 것은 Bash(보안룰 확인) + code-reviewer + design-reviewer였다. **`/codex review`가 빠졌다.** 다음 턴에 자각해 별도 발사 → 라운드 1회 추가.

**추정 원인**: 한 메시지에 여러 도구를 병렬로 보낼 때, 선언한 목록과 실제 tool_use 블록을 대조하는 장치가 없다. `/review ∥ /codex review`는 **교차검증 2소스 불변식**이라 한쪽 누락이 곧 단일소스 격하인데 자동 탐지가 없다.

**제안 개선**: `orchestrator.md`의 `/review ∥ /codex review` 항목에 1줄 —
> 병렬 발사 직후 **실제 호출한 도구 목록을 선언과 1:1 대조**한다. 특히 `/review ∥ /codex review`는 2소스 불변식이라 한쪽 누락 = 단일소스 격하다.

**근거**: 이번 실행. 결과적으로 codex review는 수행됐고 0건이었으나, 자각이 늦었으면 단일소스로 종결될 수 있었다.

**관련 파일**: `.claude/agents/orchestrator.md`

---

## 후보 5 — SSOT 다지점 값 정정 후 잔존 확인 누락 (우선순위: 중)

**증상**: 7.7에서 `MAX_REF_LENGTH` 255→100 정정(DB 컬럼 실측 근거)을 하며 계획서 **7곳**을 고쳤는데 **8번째(회귀범위 표)를 놓쳤다**. codex 재판정이 major로 잡아줬다.

**추정 원인**: 다지점 갱신 후 **옛 값 전수 grep**을 안 했다. 사람이 기억으로 "다 고쳤다"고 판단.

**제안 개선**: `orchestrator.md`에 1줄 —
> SSOT 문서의 **값**(상수·수치·문구)을 정정하면 정정 직후 **옛 값을 grep해 잔존 0을 확인**한다. 다지점 갱신은 기억으로 완료 판정하지 않는다.

**근거**: 이번 실행 codex 재판정 `[major] docs/features/…:1210 | 상한 정정이 회귀범위 표에 미반영 | **256자 ref → 400**`.

**관련 파일**: `.claude/agents/orchestrator.md`

---

## 후보 6 — harness-check 세션 판별식 서술이 뒤집혀 있다 (우선순위: 중, 거버넌스 영향)

**증상**: `harness-check/SKILL.md` Step 3이 *"**dev clone 세션이면**(판별식 … `basename $(git rev-parse --show-toplevel)` ≠ `.claude`)"* 로 서술한다. 이번 세션 실측: 제품 repo 작업 중 toplevel basename = `feature-monitor-test-1`(≠ `.claude`)이므로 **문자 그대로 따르면 dev clone으로 오판**되어, 소비자 세션에서 하네스를 직접 수정하려 시도하게 된다.

**추정 원인**: 판별 방향이 반대로 서술됨. 실제 의미는 "toplevel basename이 `.claude`면 **dev clone**(하네스 SSOT를 직접 열어 작업), 아니면 소비자". orchestrator 메모리(`wiki/_schema.md` 인용)도 *"=`.claude`면 소비자"* 로 같은 방향으로 뒤집혀 있어 **두 곳이 함께 틀렸다**.

**제안 개선**: `wiki/_schema.md`의 "어디로 가나" 절(SSOT)과 `harness-check/SKILL.md` Step 3의 판별식 방향을 정정. 실측 근거를 함께 기재:
- 제품 repo 작업 세션: `git rev-parse --show-toplevel` → 제품 repo, `git -C .claude rev-parse --show-toplevel` → 별도 `.claude` repo(중첩)
- dev clone 세션: toplevel 자체가 `.claude`

**근거**: 이번 실행 실측. 이번엔 의도(소비자 → inbox 드롭)로 올바르게 귀결시켰으나 서술을 문자 그대로 따랐다면 반대로 갔다.

**관련 파일**: `wiki/_schema.md`, `.claude/skills/harness-check/SKILL.md`

---

## 관찰만 (규칙화 제외 — 외부요인)

- **세션 토큰 한도 사망 2회** (FE 7.6 수정 배치 / tester-frontend 1회차). 하네스 레버리지 없음. 단 tester-frontend 건은 **후보 2로 별도 분리**했다(탐색 폭주는 하네스가 줄일 수 있는 축).
- **API 529 Overloaded 1회** (tester-design 보강 배치). 재발사로 즉시 복구. 서버측 일시 문제.
