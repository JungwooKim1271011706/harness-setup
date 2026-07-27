---
source_session: DEVUNIT-authpatch_draft / feature-dashboard-commitlog-2
project: autoPatch (제품 repo, 소비자 세션)
date: 2026-07-27
feature: 커밋 상세 패널 — 서브모듈 내부 diff (Approach C)
commits: a766fcf1, 44c31658
---

# 하네스 자가 점검 회고 — 서브모듈 diff 사이클 (2026-07-25 ~ 07-27)

3세션에 걸친 신규기능 트랙 1사이클(설계패널 LOOP2 → TDD 합의 → GREEN → 전 게이트 → 커밋)에서 수집한 운영 고통 4건.

---

## 후보 1 (HIGH) — 승인 항목 위임 누락이 전 기계 게이트를 무사통과했다

### 증상
계획서가 승인한 **FROZEN 예외 2건 중 ①번**(`GitLabRestConfig.restTemplate()` 소켓 타임아웃 프로퍼티화)이 **구현되지 않은 채로** 아래 게이트를 전부 통과했다:

- 7.7 tester-quality 품질게이트 → PASS (critical 0)
- 변경검증 tester-backend → PASS 77/77
- 변경검증 tester-frontend → PASS + 실브라우저 실측
- /review (code-reviewer) → blocking 0
- /codex review → major 2 (해당 항목 무관)
- /cso → findings 0

발각 지점은 **워크스루 3단계(계획 대비 이탈 대조)** 단 하나. 그마저도 finalizer 직전이라, 발각이 한 발 늦었으면 미구현 상태로 커밋될 뻔했다.

### 왜 게이트가 전부 놓쳤나 (근본 구조)
**기계 게이트는 *있는 코드*를 검증하지, *있어야 하는데 없는 코드*를 보지 않는다.**

- 7.7은 작성된 RED 테스트의 품질을 본다 — 그 RED가 커버해야 할 승인 항목이 빠졌는지는 안 본다.
- 변경검증은 실행된 테스트의 통과를 본다 — 실행되지 않은(=구현이 없어 아무도 안 부른) 항목은 시야 밖.
- code-reviewer / codex review는 **diff**를 본다 — diff에 없는 것은 리뷰 대상이 아니다.
- /cso도 동일하게 존재하는 공격표면만 본다.

즉 "계획서 수정대상 목록 ↔ 실제 위임 배치" 대조는 **파이프라인 전체에서 워크스루 3단계에만** 존재한다. 그물이 마지막에 하나뿐.

### 추정 원인
orchestrator가 GREEN 배치를 나눌 때 배치 B를 "흐름 8·11·12"로만 지시하고 **흐름 4를 빠뜨렸다**. 뿌리는 orchestrator의 오기억 — 승인된 예외 2건을 "tree 클램프 + logback"으로 잘못 기억했다(실제는 "① RestTemplate 타임아웃 ② tree 클램프"이고, logback은 흐름 12로 별건).

### 심각도 (놓쳤을 때의 실제 피해)
계획서 자신이 경고한 내용: 타임아웃 없으면 hang 소켓 워커가 공유 스레드풀 슬롯을 **영구 점유**한다. 20초 전체 데드라인은 *요청 스레드만* 풀어주고 워커는 남는다 → pool 8이 차면 이후 전 요청 `BUSY`.

추가로 **연쇄 함의**: codex review Finding 2(`Thread.interrupted()` 지적)를 기각한 근거가 "소켓 타임아웃만이 이 스택의 유일한 실질 상한"이었는데, **그 상한이 미구현이었다**. 기각 판정 자체는 유효(인터럽트는 blocking IO에 무력)하나, 근거로 삼은 안전망이 실재하지 않는 상태로 리뷰 findings를 기각한 셈.

### 제안 개선 방향
**GREEN(8단계) 진입 전에 "계획서 수정대상 목록 ↔ 위임 배치 커버리지" 기계 대조를 1회 강제한다.**

- 위치 후보: `playbook-tdd.md` 7.7 통과 직후 ~ 8단계 developer 위임 직전 (= 배치 분할을 확정하는 자리).
- 형태: orchestrator가 계획서의 `### 수정 대상` / `영향범위` / `승인된 FROZEN 예외` 항목을 열거하고, 각 항목이 어느 위임 배치에 들어갔는지 1:1 매핑표를 만든다. 미매핑 항목이 있으면 위임 발사 금지.
- 이미 있는 유사 장치와의 짝: 설계패널 major → RED 케이스 필수잠금(7c.1)과 동형. 거기서는 "승인 major마다 최소 1 RED"를 강제하는데, **"승인 수정대상마다 최소 1 위임 배치"는 강제가 없다**. 비대칭을 메우는 것.
- 부수효과: 워크스루 3단계는 그대로 두되(최종 그물 유지), 그물이 2겹이 된다.

### 근거
- 실측: `GitLabRestConfig.java:17` = `return new RestTemplate();` (전 게이트 통과 시점) / `GitLabApiClient.java:45`가 그 무타임아웃 빈을 주입받음 / `GitLabApiClient.java:606`의 타임아웃 있는 `ciJobsRestTemplate`은 CI jobs 전용이라 `compare`/`tree`/`getRawFile`은 무방비.
- 계획서 근거: `docs/features/2026-07-25-commit-detail-submodule-diff.md` L212~213(프로퍼티 표) / L317~324(코드 diff) / L1630(영향범위) / L1733("승인된 예외 2건 중 ①").
- 최종 구현 커밋: a766fcf1.

### 관련 파일
- `.claude/agents/orchestrator.md` (`## 워크스루·인출 의식` 3단계 — 현재 유일한 대조 지점)
- `.claude/docs/playbook-tdd.md` (7c.1 major→RED 잠금 / 8단계 GREEN 위임)

---

## 후보 2 (MED) — codex 가용성 주입이 tester 위임 1회에서 샜다

### 증상
orchestrator.md는 codex 가용성을 **orchestrator 단독 권한**으로 두고 "모든 tester·review 호출 컨텍스트에 빠짐없이 주입"을 요구한다(tester self-probe는 오염된 per-agent 메모리 때문에 제거됨). 그런데 이번 사이클에서 tester 위임 1건에 주입을 빠뜨렸고, tester가 "codex 미가용"으로 판정해 폴백 보고를 냈다.

### 추정 원인
주입이 **소프트 규칙**(orchestrator가 기억해야 발동)이다. 위임 프롬프트를 손으로 조립할 때마다 한 줄을 잊을 수 있고, 잊어도 아무 신호가 없다 — tester가 조용히 폴백해서 정상처럼 보인다.

### 제안 개선 방향
- (A) tester-*.md의 `## 반환 계약`에 "codex 가용성 주입을 못 받았으면 `NEEDS_CONTEXT`로 즉시 반환"을 이미 명시했는지 재확인하고, 안 됐으면 명시한다. 이번엔 tester가 폴백해버려 orchestrator 누락이 은폐됐다 — 이 은폐를 끊는 게 핵심.
- (B) 또는 훅으로 기계강제: Agent 위임 프롬프트에 `codex 가용성:` 문자열이 없으면 tester-* 스폰 차단(PreToolUse). 다만 프롬프트 문자열 검사는 취약하니 (A) 우선.

### 근거
- 이번 세션(2026-07-27)에서는 orchestrator가 세션 1회 probe(`codex-cli 0.145.0`, 실프롬프트 smoke exit 0, 한글 정상=mojibake 없음) 후 tester 위임에 명시 주입 → tester가 codex 보조를 정상 실행하고 `PackageRegistryClient` 이중 생성자 갭을 발견(BL-011로 기재). **주입되면 실제로 가치가 나온다**는 대조군.
- 직전 세션에서는 주입 누락 → tester가 미가용 판정 폴백 → 그 라운드는 교차검증 없이 진행.

### 관련 파일
- `.claude/agents/orchestrator.md` (`## codex 호출 가드` → 가용성 확정 절)
- `.claude/agents/tester/tester-backend.md`, `tester-frontend.md` (`## 반환 계약`)

---

## 후보 3 (LOW-MED) — `.gstack/`(repo 내부)가 edit hook 허용리스트 밖

### 증상
`/cso` 리포트를 repo 내부 `.gstack/`에 저장하려다 `block-orchestrator-edit.sh`에 차단됐다. `.gstack/`은 gitignored 로컬 아티팩트지 제품소스가 아니다. 우회로 repo 밖 `~/.gstack/projects/<slug>/security-reports/`에 저장했다.

흥미로운 점: **hook 자신의 차단 메시지가 "제품소스가 아닌데 막혔으면 하네스 개선 후보"라고 안내**한다. 즉 hook이 자기 갭을 자기가 신고한 셈.

### 추정 원인
허용리스트가 `.claude/**` · `docs/**` · 루트 `*.md` · repo 밖으로 되어 있고, repo 내부의 다른 gitignored 툴 디렉터리(`.gstack/`)는 고려 밖.

### 제안 개선 방향
`block-orchestrator-edit.sh` 허용리스트에 `.gstack/**` 추가. 또는 더 일반화해서 "gitignored 경로는 제품소스로 보지 않음"(`git check-ignore` 1회 호출) — 단 후자는 hook에 git 의존이 늘어 기존 알려진 구멍(PATH에 git 없으면 통과)과 상호작용하니, 단순 화이트리스트 추가가 안전.

### 근거
- 이번 사이클 /cso 실행 시 발생. 리포트 최종 위치: `~/.gstack/projects/DEVUNIT-authpatch_draft/security-reports/20260727-submodule-diff.json`.

### 관련 파일
- `.claude/hooks/block-orchestrator-edit.sh`

---

## 후보 4 (LOW, wiki gotcha 성격) — `Agent` 도구 `name` 파라미터가 tmux swarm을 켠다

### 증상
`Agent` 도구 호출에 `name` 파라미터를 주면 tmux swarm 경로가 활성화되어 **"requires WSL"로 즉시 실패**한다. `name` 없이 호출하면 정상 동작.

이 PC는 Windows git-bash + tmux 부재 환경이라 재현 100%.

### 제안 개선 방향
- wiki gotcha 페이지 1장(`wiki/agent-name-param-tmux-swarm.md` 류) — "디버깅 전에 wiki grep" 규칙의 대상이 되게.
- 추가로 orchestrator.md `## 병렬 위임 폴백` 절에 1줄: "Agent 호출에 `name` 파라미터 주지 마라(tmux swarm 활성화 → tmux 부재 환경 즉시 실패)". 기존 "background Agent 미가용 → foreground 고정" 규칙과 같은 자리.

### 근거
- 이번 사이클 실측. 동일 세션에서 `name` 있는 호출은 실패, 뺀 호출은 정상 완주.

### 관련 파일
- `.claude/agents/orchestrator.md` (`## 병렬 위임 폴백`)
- `wiki/index.md` (신규 페이지 등록)

---

## 관찰만 (규칙화 후보 아님)

- **세션 한도 사망 3회** (이 사이클): 외부 토큰 요인이라 하네스 레버리지가 작다. 다만 "큰 위임은 죽을 전제로 분할·정제"는 이미 실무적으로 적용 중이며, 규칙화하면 과잉 제약이 될 수 있어 관찰로 둔다. 실제로 이번 재개는 checkpoint가 정확해 부분산출 0으로 깨끗하게 재시작됐다 — context-save 체계는 제 역할을 했다.
- **설계패널 LOOP 2/3 소진**: critical을 잡아 planner 재작업을 유발한 것이므로 게이트 정상작동. 고통 신호로 집계하되 개선 후보는 아님.
