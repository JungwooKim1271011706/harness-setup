---
source_session: DEVUNIT-authpatch_draft / worktree feature-dashboard-commitlog-2 (작업 repo는 main clone C:\crinity\workspace\sideproject\authpatch_draft)
project: DEVUNIT-authpatch_draft
date: 2026-07-29 (UTC 20260728T213708Z)
trigger: orchestrator post_commit 자가점검 (커밋 75180e40 / 19a4f108 직후, 사용자 승인 후 드롭)
context: 커밋그래프 lane 수렴 stale 버그 + UI 3건 — TDD 풀사이클(7.5 RED → 7.6 → 7.7 LOOP 1/3 → 8 GREEN → 변경검증 → 2소스 리뷰 → finalizer) 완주 중 발생
---

# 하네스 회고 — TDD 8단계 진입 게이트 2건

## 후보 1 — `red-baseline.sh snapshot`이 8.0 진입 전 필수 스텝이 아니라 워크스루 3.5가 통째로 미검증으로 떨어짐 (priority: 높음)

### 증상 (무엇이 얼마나)

워크스루 3.5(RED 기준선 대조)에서 `bash .claude/scripts/red-baseline.sh diff` 실행 결과:

```
⚠ RED 기준선 스냅샷 없음 — 8.0에서 `snapshot` 미실행.
  → 이 축(단언 약화)은 **미검증**이다. "이상 없음"으로 읽지 말 것.
```

즉 **탐지 스크립트는 정상 작동했는데 입력(스냅샷)이 없어 게이트가 공회전**했다. 이번 라운드는 RED 6건이 GREEN으로 전환되는 정확히 그 시나리오였다 — "구현이 통과시킨 것"인지 "단언이 약화된 것"인지가 이 축의 유일한 관심사인데, 그걸 볼 수 없는 상태로 finalizer까지 갔다.

orchestrator가 즉석 보상 증거를 3개 만들어 메웠다:
1. spec mtime(`22:55~22:56`) < 구현 mtime(`23:19~23:20`) → GREEN 이후 spec 미변경
2. 핵심 단언 원형 grep 확인 (`>=8` / `<= Math.abs(p.x2-p.x1)` / `toHaveLength(0)` / `toBe('src/main/foo/Bar.java')` / `toBe(laneBySha.get(...))`)
3. `block-developer-test-edit.sh`가 developer의 spec 편집을 차단

결과적으로 약화 정황은 0이었으나, **이 보상은 재현 가능한 절차가 아니라 그때그때 즉흥**이다. 다음 라운드에 같은 누락이 나면 또 즉흥해야 하고, 즉흥을 안 하면 그냥 미검증으로 통과한다.

### 원인 (구조)

- `orchestrator.md`의 워크스루 3.5는 **소비 지점**(diff 실행)만 명문화하고, **생산 지점**(8.0 진입 전 `snapshot` 실행)은 어디에도 필수 스텝으로 안 적혀 있다. `red-baseline.sh` 자체 경고문만 "8.0에서 snapshot 미실행"이라고 사후 지적한다.
- `playbook-tdd.md` 8단계(GREEN 위임) 절차에도 snapshot 호출이 없다(확인 필요 — 이번 세션에선 orchestrator가 8단계 위임 시 snapshot을 부르지 않았고, 아무 훅도 막지 않았다).
- 구조상 **"게이트는 있는데 그 게이트의 입력을 아무도 안 만든다"** — 탐지기 자체가 no-op로 무음 통과하는 클래스.

### 제안 (초안)

1. `playbook-tdd.md` 8단계 진입 절차에 **"developer 위임 직전 `bash .claude/scripts/red-baseline.sh snapshot` 1회"** 를 필수 스텝으로 박는다. `orchestrator.md` 3.5 항목에도 "이 대조는 8.0 snapshot이 선행돼야 성립"이라는 상호참조를 단다(생산↔소비 양쪽에서 보이게).
2. (더 강함) PreToolUse 훅 또는 8단계 위임 시점 기계강제 검토 — `Agent(subagent_type=developer-*)` 호출 시 스냅샷 파일이 없으면 경고. 다만 developer 위임이 GREEN 전용이 아니라(단순수정 트랙에서도 호출) 오탐 가능 → 우선 문서 강제부터.
3. 스냅샷 부재 시 보상 절차를 3.5에 **명문화**: mtime 대조(spec < 구현) + 핵심 단언 grep. 즉흥을 절차로 승격시켜 다음 사람이 재현할 수 있게.

---

## 후보 2 — developer-* 위임 프롬프트가 "자가검증 실행"을 요구하는데 그 에이전트에 실행 도구가 없다 (priority: 중간)

### 증상 (무엇이 얼마나)

orchestrator가 `developer-frontend`에 8 GREEN을 위임하며 프롬프트에 이렇게 넣었다:

```
## 자가검증 (구현 후 필수 실행)
npx vitest run ...
npx vue-tsc --noEmit ...
**기대**: 전체 vitest 470 passed / 0 failed / 41 files
```

`developer-frontend`의 도구는 `Read, Glob, Grep, Edit, Write` — **Bash가 없다.** 에이전트가 반환문에 이렇게 적었다:

> **자가검증 미실행**: 이 세션 툴셋에 Bash/실행 도구가 없고(developer-frontend 규칙상 "빌드/실행 금지"와도 부합), `npx vitest`/`npx vue-tsc` 직접 실행 불가.
> ❌ planner 명시 변경 사항 전체 반영 "실행 검증" — 코드 트레이스로는 완료했으나 vitest 실행 확인은 미실행(툴 제약)

그리고 그 자리를 **수치적분·수동 트레이스로 대체 검증**하는 데 토큰을 썼다(3차 베지어 t 이분탐색으로 Δ≈11.6px 손계산). 그 계산 자체는 나중에 tester-frontend 실측(11.57px)과 일치해 낭비는 아니었지만, **애초에 요구할 수 없는 걸 요구했고 에이전트가 그 공백을 메우려 우회 노동을 했다.**

피해 규모는 이번엔 작다(수치 손계산 1회). 다만 이 패턴은 ① 에이전트가 "실행했다"고 **거짓 보고**할 유인을 만들고(이번 에이전트는 정직하게 미실행을 보고했지만 그건 운) ② 반환문 체크리스트에 `❌`가 남아 orchestrator가 실패로 오독할 여지가 있다.

### 원인 (구조)

- orchestrator가 위임 프롬프트를 조립할 때 **대상 에이전트의 도구셋을 참조하지 않는다.** "구현했으면 검증해라"는 일반 상식이 프롬프트에 그대로 들어간다.
- `developer-frontend.md`는 "빌드/실행 금지"를 스스로 규정하고 있어 **에이전트 정의와 위임 프롬프트가 정면 모순**이었다. 에이전트가 자기 md를 근거로 거부한 게 정상 동작.
- 검증 주체 분리(developer=구현, tester=검증)는 하네스의 핵심 불변식인데, 위임 프롬프트가 그걸 흐렸다.

### 제안 (초안)

1. `playbook-tdd.md` 8단계 위임 템플릿에서 "자가검증 실행" 문구를 **제거**하고, 대신 **"검증은 tester-*가 한다. 너는 실행하지 마라. 다만 기대 기준선(vitest N/N, vue-tsc M건)을 알고 있어야 구현 판단에 쓸 수 있으니 참고로 적는다"** 로 바꾼다 — 기준선 정보 전달은 유지하되 실행 요구만 뺀다.
2. `developer-*.md` 반환 계약에 **"실행 검증은 네 책임이 아니다. 미실행을 결함으로 보고하지 마라"** 를 1줄 추가 — 이번처럼 `❌`로 자기 감점하는 걸 막는다.
3. (일반화) orchestrator 위임 시 **"이 에이전트 도구셋으로 가능한 일만 요구했나"** 1문 자가체크를 `orchestrator.md` 위임 규칙에 추가 검토. 상호의존 병렬위임 자가체크(`한쪽 산출이 다른쪽 입력 가정을 바꾸나?`)와 같은 자리.

---

## 부수 관찰 (규칙화 판단은 retro에 위임)

- **R19(신설) 실효 확인됨**: `attachTo: document.body` spec의 파일 전역 `afterEach` cleanup 안전망을 이번 라운드에 **수동 주입**해서 돌렸고, 7.7 게이트가 "구조 적정, 누수 경로 1개 잔존(FE-11 직접 mount)"까지 판정해 그 잔존분도 수정됐다. 직전 inbox 항목(`20260728T041316Z`)이 제안한 R19를 `tester-design.md` 정식 편입할 근거가 실측으로 확보된 셈.
- **code-reviewer가 `/code-review` 스킬 대신 인라인 폴백**: 대상이 비-PR 로컬 워크트리라 `gh pr diff` 전제 불충족 → 폴백 규칙대로 인라인 루브릭 리뷰 수행. 이 프로젝트는 풀사이클=개인실험이라 **PR이 존재하지 않는 게 정상**인데, 매번 폴백을 타는 구조라면 `code-reviewer.md`에 "이 프로젝트 기본 경로 = 인라인"을 명시하는 게 나을지 검토.
- **7.7 critical의 실효 사례(긍정)**: 1차 7.7이 "합류 방향(`fromLane>toLane`) 곡선 픽스처 0건"을 잡았고, 정량 역산으로 "`cx1=x1+8` 상수 오프셋 구현이면 분기는 Δ7.18로 잡히지만 합류는 Δ0.16으로 악화되는데 스위트가 못 잡는다"를 보였다. 이 지적이 없었으면 방향 비의존 구현이 통과했을 것. **7.7 게이트를 opus로 유지할 근거 데이터**로 기록.

---

## 🔁 재발 기록 (2026-07-30, 커밋그래프 edge 라운드 — 후보 2 동일 신호)

**같은 실패가 다른 트랙에서 반복됐다.** 이번엔 TDD 8단계가 아니라 **단순수정 트랙**의
developer-frontend 위임이었다 — 즉 이 결함은 `playbook-tdd.md` 8단계 템플릿에 국한되지 않고
**orchestrator의 위임 프롬프트 조립 습관 전반**의 문제다(제안 초안의 적용 범위를 넓혀야 한다).

- 위임 프롬프트에 넣은 요구: "**자가검증**: `cd autopatch-dashboard && npx vue-tsc --noEmit` 1회 통과
  확인. 결과 인용."
- developer-frontend 반환: "`npx vue-tsc --noEmit` **미실행** — 개발자 역할 핵심 규칙 '빌드/실행 금지'가
  태스크 지시보다 상위 제약이라 실행하지 않음. 대신 코드 리뷰로 타입 안전성 확인."
- 결과: 이번에도 에이전트가 정직하게 거부(운) + 그 공백을 "수식 대조"로 메움. 실제 `vue-tsc`는
  다음 단계 tester-frontend가 실행해 baseline diff 0 확인.
- 부수 발견: orchestrator **auto-memory `feedback_developer_agents_have_bash`가 부분 오류**였다 —
  "developer 에이전트에 Bash 있음"으로 적혀 있으나 실제로는 **developer-backend만 Bash 보유,
  developer-frontend는 `Read/Glob/Grep/Edit/Write`뿐**. 이 잘못된 메모리가 위임 프롬프트에 실행
  요구를 넣도록 유도했을 가능성. → 같은 세션에서 메모리 정정함(도메인별 도구셋 구분 명시).

**제안 보강**: 제안 초안 1(8단계 템플릿 문구 제거)에 더해,
- 위임 프롬프트 조립 시 **대상 에이전트 도구셋 1회 확인**을 orchestrator 규칙으로(도구 없는 요구 금지),
- 또는 더 단순하게: **모든 developer-* 위임에서 "실행/검증 요구" 자체를 금지**(검증 주체 분리 불변식과
  동일 방향 — developer는 어느 트랙에서도 실행하지 않는다).
