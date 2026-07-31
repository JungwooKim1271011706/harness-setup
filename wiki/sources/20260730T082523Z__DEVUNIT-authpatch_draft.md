---
source_session: 커밋그래프 edge 렌더 불일치 버그픽스 (단순수정 트랙 2라운드)
project: DEVUNIT-authpatch_draft
worktree: C:\Users\crinity\.local\share\worktrees\DEVUNIT\authpatch_draft\faeture-dashboard-commitlog-bugfix-1
date: 2026-07-30
commits: 61f6fc1e (elbow) → f08e370a (S자 라운딩) → 머지 015255a9 / 852aab3d → 1d9afca3 (E2E record)
signals: 과다루프 LOOP 2/3 (결국 PASS) · 환경 FAIL 1건 · 머지충돌 1건
---

# 하네스 자가 회고 — 커밋그래프 edge 렌더 라운드 (2026-07-30)

배경: "대시보드 커밋 그래프가 실제 `git log --graph`와 다르게 보인다" 신고. 진단 결과 데이터·lane
배정은 정상이었고 `CommitGraph.vue` `edgePath()`의 곡선 렌더 폴리시 문제였다. 단순수정 트랙으로
처리했으나 **LOOP 2/3**을 소모했다(최종 PASS·사람 E2E 4/4 통과).

---

## 후보 1 — orchestrator가 frozen 접점계약을 낼 때 "대칭·경계 축"을 자가검증하지 않는다 (priority: 높음)

### 증상 (무엇이 얼마나)
1차 frozen 계약이 "N≥2행 lane 이동 edge"를 **방향 무관 단일 공식**으로 못 박았다. 합류
(`toLane<fromLane`) 방향에서는 정답이었으나 분기(`toLane>fromLane`) 방향에서는 수직 구간이
mainline lane(매 행 노드 dot이 앉는 레인) 위에 남아, 그 프로젝트 rule이 이미 경고한 `#13`
증상(곡선이 다음 행 dot을 삼킴)을 **되살렸다**. tester-frontend가 실행 산출 `d` 값
(`M 22 17 L 22 85 C 40 102, ...`)을 보고해서야 발각 → 계약 v2 재발행.
비용: developer 위임 1회 + tester 위임 1회 낭비(각 2~6분, 서브에이전트 토큰 ~14만).

### 추정 원인
- orchestrator.md에는 "상호의존 작업 병렬위임 금지"처럼 **위임 구조**에 대한 1문 자가체크는 있으나,
  **계약 내용 자체의 대칭/경계 케이스** 자가체크가 없다.
- 더 결정적: `rules/package/autopatch/frontend.md`에 이미
  "`#13` — 방향 비의존 상수 오프셋은 분기에서만 통하고 합류에서 부호가 안 맞는다. 분기/합류 양방향을
  같은 축에서 `it.each`로 검증할 것"이라는 **선례 경고가 존재**했다. 그런데 rule 경로는
  서브에이전트에게 "Read하고 준수"로 주입될 뿐, **계약을 직접 저술하는 orchestrator는 안 읽는다**.
  즉 함정 지식이 계약 저자에게 도달하지 않는 구조.

### 제안 개선 방향
1. orchestrator.md 계약 freeze 절에 1문 자가체크 추가:
   "이 계약에 **방향·부호·경계 축**(N=1 vs N≥2 / 좌↔우 / 증가↔감소 / 첫↔마지막)이 있나?
   있으면 각 축의 **양끝 값을 손계산해 검산표에 넣는다**. 한 공식이 모든 축을 덮는다고 단정 금지."
2. 렌더·기하·좌표 계약을 저술할 때는 orchestrator도 해당 `rules/*.md`의 **기존 함정 항목을 1회 grep**
   (현재는 서브에이전트 주입 전용 → 저자 본인이 사각).

### 근거
이번 실행. 계약 v1 → tester 실측 `d` → 계약 v2(비대칭 분리, `CommitGraph.vue:454`/`:460`).
최종 규칙: "다중행 lane 이동 edge의 수직 구간은 항상 `max(fromLane,toLane)`(side lane)".

### 관련 파일
`.claude/agents/orchestrator.md`(계약 freeze 자가체크) · `.claude/rules/package/autopatch/frontend.md`(#13 선례)

---

## 후보 2 — 신규 회귀가드의 tautology 검출이 상시 계약이 아니라 프롬프트 재량에 달렸다 (priority: 높음)

### 증상 (무엇이 얼마나)
tester-design이 추가한 회귀가드 `CG-EDGE-05/06`이 **tautology**였다. 1행 픽스처에서 샘플 지점
`targetY = y1 + ROW_HEIGHT`가 곡선의 **종점 y2와 일치** → 3차 베지어는 t=1에서 제어점과 무관하게
항상 `(x2,y2)`이므로 buggy(`cx1=x1`)·fixed(`cx1=x2`) 양쪽이 동일값 `18`을 반환. 영구 GREEN.
이번엔 orchestrator가 tester-frontend 프롬프트에 "buggy 가정에서 RED가 나는지 Node로 증명하라"를
**명시했기 때문에** 잡혔다. 안 넣었으면 "회귀가드 있음"으로 오인한 채 종결됐다. LOOP +1.

### 추정 원인
- tester-design md에 "신규 가드는 판별력을 증명한다"가 **상시 반환 계약이 아니다**.
- TDD 트랙에는 7.7 `tester-quality`(RED 품질 게이트)가 있지만 **단순수정 트랙엔 그 게이트가 없다**
  → 가드 품질을 아무도 구조적으로 안 본다(구조적 공백).

### 제안 개선 방향
1. `tester-design.md` `## 반환 계약`에 필수 항목 추가:
   "**신규 회귀가드마다 반증 1줄**: 어떤 buggy 가정이면 이 단언이 RED가 되나(값 포함). 증명 못 하면
   그 가드는 tautology로 간주하고 제출 금지."
2. `tester-backend.md`/`tester-frontend.md`: "신규 가드 판별력 미증명 시 감점" 명문화(수신측 검증).
3. (선택) 단순수정 트랙에도 **가드 판별력 한정 경량 체크**를 두는 것이 좋은지 판단 — 7.7 전체를
   끌어오는 건 과부하이므로 위 1·2의 계약 강제로 대체 가능한지 먼저 검토.

### 근거
이번 실행 LOOP 2/3. tester-frontend 실측: "buggy/fixed 양쪽 `t≈0.99999999999995, x=40, abs=18`
완전 동일" → tautology 확정. 교체 후 exact-`d` + 첫 제어점 단언으로 discriminating 확인.

### 관련 파일
`.claude/agents/tester/tester-design.md` · `tester-frontend.md` · `tester-backend.md`

---

## 후보 3 — 병렬 워크트리에서 `docs/backlog.md` BL 번호 경합이 매번 머지 충돌을 만든다 (priority: 중간)

### 증상 (무엇이 얼마나)
브랜치 finalizer가 `BL-027`(브라우저 미실측)을 등재했는데, 그 사이 main도 `BL-027`/`BL-028`을
등재해 `git merge`에서 CONFLICT. 사용자가 "에러나는디?"로 보고 → 충돌 해소 + `BL-029` 리넘버링
1라운드 소모. 파일 끝 append 원장 + 병렬 워크트리 구조라 **재발 확정**.

### 추정 원인
원장 관례가 "마지막 번호+1"인데 번호 공간이 브랜치별로 분기된다. 번호를 **브랜치에서 확정**하는 것이
근본 원인.

### 제안 개선 방향 (3택)
1. **최소변경** — finalizer 관례: "브랜치 작업 중에는 `docs/backlog.md`를 수정하지 않는다. 머지 후
   main에서만 등재." (이번 라운드에 orchestrator가 임시 우회책으로 실제 사용 → 2차 머지는 충돌 0)
2. 번호 대신 충돌 없는 ID: `BL-20260730-elbow-e2e`(날짜+슬러그).
3. **근본** — 원장을 `docs/backlog/<id>.md` 항목 1파일로 분해(append 경합 자체가 사라짐).

### 근거
이번 실행: 1차 머지 CONFLICT(`docs/backlog.md` 단독) → 리넘버링 → 2차 머지는 backlog 무변경으로
충돌 0. 우회책 1의 유효성이 같은 세션에서 실증됨.

### 관련 파일
`.claude/agents/finalizer.md` · `docs/backlog.md`(제품 repo 원장)

---

## 후보 4 — 렌더 E2E 점검표가 "어느 체크아웃이 서빙되는지"를 확인시키지 않는다 (priority: 중간)

### 증상 (무엇이 얼마나)
사용자가 **메인 클론**에서 dev server를 띄운 상태로, **워크트리의 미커밋 변경**을 브라우저에서
확인하려 했다. orchestrator가 직전에 상태를 실측(`git status` + 양쪽 `grep`)해 잡아 사고는 없었지만,
잡지 못했다면 "안 고쳐졌네" 오판 → 무의미한 디버깅 라운드로 직결됐다(변경분이 그 체크아웃에 아예
없으므로 하드 리프레시·캐시 의심으로 시간이 샌다).

### 추정 원인
`human-e2e` render 산출의 `[빌드/실행]` 절은 명령만 렌더한다. **다중 체크아웃(병렬 워크트리) +
미커밋 변경** 조합에서 "지금 켜져 있는 dev server가 어느 경로 것인가"를 확인시키는 항목이 없다.
(기존 `[[vite-stale-served-source-windows]]` 가토차는 *같은* 체크아웃의 stale 서빙만 다룬다 —
*다른* 체크아웃 서빙은 별개 실패 모드.)

### 제안 개선 방향
`human-e2e/SKILL.md` render 모드에 선행 확인 강제:
1. 헤더에 1줄: "이 점검표는 **`<워크트리 경로>`의 코드**를 본다."
2. 미커밋 변경이 점검 대상이면 배너: `⚠ 미커밋 — 이 체크아웃에서 띄운 dev server만 반영된다`
3. `[준비]`에 확인 명령 1개:
   `netstat -ano | grep :5173` → PID → `Get-CimInstance Win32_Process -Filter "ProcessId=<pid>"`로
   `CommandLine` 경로 대조(다른 체크아웃이면 끄고 대상 경로에서 재기동).

### 근거
이번 실행. 사용자 발화 "이건 아직 commit 안한 거지??" → orchestrator 실측으로 워크트리(S자 미커밋)
↔ 메인 클론(각진 elbow, `C ${x2}`) 불일치 확인 → 사용자가 "커밋+머지하고 메인 클론에서 확인"으로 전환.

### 관련 파일
`.claude/skills/human-e2e/SKILL.md`

---

## 관찰만 (규칙화 제외)

- **`npm ci` esbuild EPERM 락** — `mvn -P web package`의 `frontend-npm-ci` 단계가 `node_modules`를
  선삭제하는데 dev server(vite)의 자식 `esbuild.exe`가 그 파일을 점유해 `EPERM unlink -4048`로
  BUILD FAILURE. 1회성 아니고 **재발 구조**(빌드 전 dev server를 끄는 습관에 의존)지만 하네스 규칙보다
  **wiki gotcha**가 맞는 자리로 판단 → 규칙화 후보에서 제외, wiki capture로 이관
  (`npm-ci-esbuild-lock-devserver`: 진단은 `esbuild.exe` 부모 PID 추적으로 어느 체크아웃인지 특정).
- **사람 E2E가 시각 폴리시를 2라운드로 잡음** — 1차 elbow 통과 후 "자연스러운 곡선은 아니네" 피드백
  → S자 라운딩. 게이트가 **제 역할을 한 것**이므로 비효율 아님. 자동 테스트로는 대체 불가(시각 판단).
- **`failure_*.md` 0건** — 누적 실패 패턴 신호 없음(이번 LOOP는 전부 최종 PASS로 수렴).

---

## 이번 실행에서 쓴 우회책 (임시 — 규칙 아님)

- 후보 3: 2차 라운드에서 브랜치의 `docs/backlog.md`를 아예 건드리지 않고, 머지 후 main에서만
  BL-029 종결 표시 → 충돌 0. (후보 3 제안 1의 사전 검증)
- 후보 1: 계약 v2/v3 발행 시 orchestrator가 **검산값 4건(양 방향 × 1행/N≥2행)을 손계산해 표에 명시**
  → developer가 수식 대조로 자가확인. v3(S자)에서는 인접 dot 이격(분기 15px·합류 17px)까지 계산해
  주입. 이 두 라운드는 재작업 0.
