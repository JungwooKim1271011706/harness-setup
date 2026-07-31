---
source_session: DEVUNIT-authpatch_draft / worktree feature-dashboard-commitlog-2 (작업 repo는 main clone C:\crinity\workspace\sideproject\authpatch_draft)
project: DEVUNIT-authpatch_draft
date: 2026-07-28 (UTC 20260727T152651Z)
trigger: orchestrator post_commit 자가점검 (Stop 훅 backstop이 LOOP≥2 신호로 강제)
context: 커밋그래프 무한스크롤 설계 트랙 — 설계패널 1차/2차 게이트 실행 중 발생
---

# 하네스 회고 — 설계패널 워크플로 2건

## 후보 1 — 설계패널 페르소나가 잘못된 repo의 소스를 읽어 critical 오진 (priority: 높음)

### 증상 (무엇이 얼마나)
1차 설계패널(`design-panel.js`, runId `wf_2c8c4053-697`, 4페르소나, 642k 토큰) 실행 결과 **eng가 confidence 10의 critical 1건**을 냈다: "계획 baseline이 대상 브랜치 실제 코드와 불일치 — `WebExportService.java:237`은 `commits(..., 1, 50, ...)`인데 계획서는 `1, 100`을 전제한다".

orchestrator가 main clone에서 직접 실측해 **4축 전부 반증**했다:

| eng 주장 (worktree 기준) | main clone 실측 (정답) |
|---|---|
| `WebExportService:237` = `1, 50` | `:239` = `1, 100` |
| `WebExportServiceCommitDetailTest` 스텁 `eq(50)` | `:370`/`:387` = `eq(1), eq(100)` |
| `CommitGraph.spec.ts` 769줄, RC-01~05 없음 | 1070줄, RC 7건 매치 |
| stub 화살촉 UI 미존재 | `stubMarkerPath`/`STUB_MARKER_*` 실존 |
| `commitGraphLayout.ts:49` drift docblock 없음 | L49~51 실재 |

즉 페르소나가 **세션 cwd(2커밋 뒤진 워크트리)** 에서 소스를 읽었다. 오진 파급:
- critical 1건 전면 기각 + cso minor 1건·eng minor 1건(라인 앵커 어긋남) 동반 기각 = **findings 3건이 노이즈**
- orchestrator가 반증하려고 코드대조 Bash/Grep 5회 추가 소모
- 반증 실패 시 계획서를 `50` 기준으로 되돌리는 **재작업 1라운드 낭비**로 직결됐을 사안

### 추정 원인
`design-panel.js`의 args 계약이 `planPath`/`planText`/`rulePaths`/`complexity`/`personas`/`topModel` **6개뿐이고 `repoRoot`가 없다.** orchestrator가 planPath·rulePaths를 절대경로로 줘도 페르소나가 **소스**를 읽을 때는 기준점이 없어 각자 cwd(워크플로 서브에이전트 = 세션 cwd)로 떨어진다. 세션 cwd ≠ 작업 repo인 구성(병렬 워크트리 개발)에서 이게 항상 오독이 된다.

부수: orchestrator.md는 "모든 위임에 절대경로 명시"를 요구하지만, Workflow 경유 위임에는 **명시할 필드 자체가 없다** — 규칙은 있는데 배선이 없는 상태.

### 제안 개선 방향
1. `design-panel.js` args에 `repoRoot`(선택) 추가. `reviewPrompt()`에 아래 블록을 조건부 삽입:
   - "이 계획의 모든 파일 경로는 `<repoRoot>` 기준이다. 소스를 읽을 때 반드시 이 절대경로를 prefix하라. cwd 기준 상대경로로 읽지 마라 — cwd가 stale 워크트리일 수 있다."
   - `repoRoot` 미전달 시 기존 동작 유지(하위호환).
2. `orchestrator.md ### 패널 실행` "orchestrator가 한다 (워크플로 호출 전)" 3번 args 구성에 `repoRoot: <작업 repo 절대경로>` 추가 + "세션 cwd ≠ 작업 repo면 필수" 단서.
3. 같은 문제가 `harness-feature-scan.js` 등 다른 워크플로에도 있는지 점검(공통 패턴이면 워크플로 args 규약으로 승격 검토).

### 이번 실행에서 쓴 우회책 (임시)
계획서(`docs/features/...`) 상단에 `## 🔴 리뷰어 필독 — repo 절대경로` 절을 orchestrator가 직접 삽입 — main clone 실측 앵커 표 포함. **작동 확인됨**: 2차 라운드에서 codex가 정확한 라인(`CommitGraph.vue:639~644` 등)을 인용했다. 단 이건 feature 문서마다 수동 삽입이라 재사용성이 없다(근본 해법 = 위 1·2번).

### 근거
- 1차 패널 산출: `subagents/workflows/wf_2c8c4053-697/journal.jsonl` (eng critical confidence 10)
- 반증 실측: main clone `WebExportService.java:239`, `WebExportServiceCommitDetailTest.java:370`/`:387`, `CommitGraph.spec.ts`(1070줄), `commitGraphLayout.ts:49~51`
- 스크립트 args 계약: `.claude/workflows/design-panel.js` L11~16, L25~30, `reviewPrompt()` L74~88

### 관련 파일
- `.claude/workflows/design-panel.js`
- `.claude/agents/orchestrator.md` (`### 패널 실행`)
- 파생: `.claude/docs/playbook-*.md` 중 패널 절차 언급분 (drift 점검)

---

## 후보 2 — 부분실패 자동재런치가 "세션 한도"를 transient 오류와 구분하지 못해 한도를 추가 소모 (priority: 중)

### 증상
2차 패널(runId `wf_c2e1bead-5cb`) 실행 중 eng·cso·devex가 `You've hit your session limit · resets 1:30am (Asia/Seoul)`로 사망. 워크플로가 각 페르소나를 **재시도해 총 5 failure**를 누적했다(`agent_count 6 / agents_done 1 / agents_error 5`). 재시도분은 100% 실패가 예정된 호출이었고, 그만큼 한도를 더 태웠다.

design 1명만 완주 → 필수 페르소나(eng 항상 · cso 보안태그) 누락으로 **게이트 미종결**. 사용자에게 계정 전환을 요청하고 3렌즈 부분집합 재런치를 대기하는 상태로 세션이 끊겼다.

### 추정 원인
두 층 모두 "실패 = 재시도"로 단일 처리한다:
1. **스크립트 층** — `design-panel.js`가 top 슬롯 사망 시 `opts(isTop ? 'opus' : 'sonnet')`로 폴백 재호출(L124~128). fable 사망 대비 설계인데, 사망 원인이 **계정 한도**면 모델을 바꿔도 같은 계정이라 반드시 재실패한다.
2. **orchestrator 층** — `### 패널 실행` 0번 "완전성 검사"가 `failures[]` 非空이면 부분집합 자동 재런치 1회를 지시한다. 이 지시도 원인을 안 본다.

`session limit`은 transient(네트워크·API 5xx)가 아니라 **시간 기반 자원 고갈**이라 즉시 재시도 가치가 0이다. 반면 계정 전환 또는 리셋 대기는 사람 개입이 필요하다.

### 제안 개선 방향
1. `design-panel.js`: agent 실패 사유에 `session limit` / `hit your.*limit` / `resets` 패턴이 있으면 **폴백 재호출을 건너뛰고** 그 페르소나를 `failures[]`에 `reason: 'quota'`로 기록. 다른 페르소나 실행은 계속(design이 완주한 것처럼 부분 산출은 살린다).
2. `orchestrator.md ### 패널 실행` 0번 완전성 검사에 분기 추가:
   - `reason: 'quota'`(또는 failures 문자열에 한도 패턴) → **자동 재런치 금지**. 사용자에게 계정 전환/리셋 대기 선택지를 올리고, 완주 페르소나 산출은 보존해 재런치 시 **미완 페르소나만** 부분집합으로 돌린다.
   - 그 외(transient) → 기존 1회 자동 재런치 유지.
3. 같은 판정을 `## codex 호출 가드`의 실패 신호 목록과 대칭으로 문서화(거기엔 이미 `AUTH_FAILED`/`NOT_FOUND` 등 비-재시도 신호 구분이 있다 — claude 서브에이전트 쪽에만 그 구분이 없는 비대칭).

### 이번 실행에서 확인된 것 (설계 근거)
부분 산출 보존은 실제로 가치가 있었다 — design 완주분(major 1 + minor 2 + passEvidence 5건)이 살아남아 "M1/M3/M4 실제 해소를 diff로 추적 확인"이라는 재게이트 초점 검증을 확보했다. 즉 quota 사망 시 **전체 재실행이 아니라 미완분만 재런치**가 맞다는 게 실측으로 뒷받침된다.

### 근거
- 2차 패널 failures: `[review:cso] failed: You've hit your session limit · resets 1:30am (Asia/Seoul)` ×2, `[review:eng]` ×2, `[review:devex]` ×1
- usage: `agent_count 6 / agents_done 1 / agents_error 5 / subagent_tokens 611226`
- 스크립트 폴백 경로: `.claude/workflows/design-panel.js` L122~128
- orchestrator 재런치 규칙: `.claude/agents/orchestrator.md` `### 패널 실행` "orchestrator가 한다 (워크플로 반환 후)" 0번

### 관련 파일
- `.claude/workflows/design-panel.js`
- `.claude/agents/orchestrator.md` (`### 패널 실행` 0번 / `## 병렬 위임 폴백` 인접)

---

## 관찰만 (규칙화 후보 아님)

- **planner 재작업 LOOP 1회** — 설계패널 major 6건을 사용자 승인(A안) 후 반영한 정상 게이트 동작이다. 과다루프(LOOP≥2)가 아니라 게이트가 제 일을 한 사례라 개선 후보에서 제외.
- **`gstack-decision-log`의 `scope`가 `repo|branch|issue`만 허용** — 자유 slug(`commitgraph-infinite-scroll`)를 넣어 1회 거부됐다. 벤더 스킬(`~/.claude/skills/gstack/`)이라 수정 금지 대상. orchestrator.md의 decision-log 호출 예시에 허용값을 1줄 병기하면 재발이 없어지는 정도의 사소한 건 — priority 낮음, 다음 회고에 묶어도 무방.
