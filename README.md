# harness-setup

Claude Code 오케스트레이션 하네스. 설계 중심 워크플로(3트랙 / 설계 패널 게이트 / OOP 정렬 co-plan / TDD 합의 / FAIL 3분기)를 담은 `.claude` 디렉터리 묶음이다.

새 프로젝트에 이 하네스를 **`.claude` 디렉터리로 클론**해서 사용한다.

## 워크플로 흐름

0단계 진입분기(복잡도·보안 2차 스캔·모듈→rule 주입) → 3트랙(단순수정/신규기능/고복잡도) → 설계패널 게이트 → 사용자 승인 → TDD 합의 → 변경검증(tester-backend/frontend) → review → finalizer. 전체회귀(tester-runtime)는 매 구현 강제 체인에서 분리돼 부채/수동("회귀 돌려") 트리거로만 실행.

```mermaid
flowchart TD
  REQ["사용자 요청"] --> S0["0단계 진입분기<br/>① 복잡도 ② 보안 2차 스캔 ③ 모듈→rule 주입"]
  S0 --> CPX{복잡도?}

  CPX -->|단순수정| SIMP["developer-* → tester-* 경량<br/>설계게이트·TDD 스킵"]
  SIMP --> POST
  CPX -->|신규기능| NF1["/office-hours"]
  CPX -->|고복잡도| HC1["planner-high-complexity"]

  NF1 --> NF2["/grill-with-docs"] --> NF3["/co-plan OOP5 freeze=public"] --> PL["planner-* +변경영역태그"]
  HC1 --> HCE["/plan-eng-review"] --> PL
  PL --> GATE["설계패널 게이트 신규≥3/고복잡도≥4<br/>PASS 근거 기계심사 C5b<br/>보안 재스캔 태그보정 C2"]
  GATE --> CRIT{critical 0?}
  CRIT -->|NO| PLRE["planner 재작업 루프3"] --> GATE
  CRIT -->|YES| APV{{"사용자 승인 설계만"}}

  APV --> T7A["7a tester-design ∥ 7b codex<br/>폴백시 교차검증없음 C4"]
  T7A --> T7C["7c diff 합의"] --> T75["7.5 codex RED public행위"] --> T77["7.7 tester-quality 품질게이트"]
  T77 --> Q77{critical0+근거?}
  Q77 -->|NO| RET["작성자 반환 루프3"] --> T75
  Q77 -->|YES| T8["8 developer GREEN public계약준수"]
  T8 --> POST

  POST["tester-backend ∥ tester-frontend<br/>변경검증: 단위+변경스코프1홉+회귀범위+L1 context P1<br/>JUnit skipTests 임시오버라이드 C1-temp"]
  POST --> PF{PASS?}
  PF -->|PASS 변경검증 종료| VER["/verify-implementation 등록시"]
  VER --> REV["/review ∥ /codex review<br/>스냅샷=변경검증 PASS시점 합집합 N1"]
  REV --> CSO["/cso 인증·권한·암호화시"] --> FIN["finalizer 승인후 커밋 명시경로<br/>커밋직전 전체회귀 부채 비차단 안내(📊/⚠)+state갱신"]
  FIN --> LG["learning-gate post_commit"] --> DONE["완료 보고 / push=승인시"]

  PF -->|FAIL| FB{FAIL 3분기}
  FB -->|구현결함| DEV["developer 재수정 루프n/3<br/>루프카운트=체크포인트 권위 C6"] --> POST
  FB -->|설계결함| DM["planner 재호출+패널 재게이트<br/>사용자 재승인"] --> PL
  FB -->|환경문제| EN["사용자 가이드"] --> POST
  FB -->|원인불명| INV["/investigate 재판단"] --> FB

  FIN -.부채안내가 권장.-> DEBT["전체회귀 트리거<br/>회귀돌려 인식7종/부채 권장수락"]
  DEBT --> RT["tester-runtime 단독<br/>통합+전체회귀 1회"]
  RT --> RTP{PASS?}
  RTP -->|PASS| RST["regression-debt.json 리셋 부채0"]
  RTP -->|FAIL| RTF["실패도메인→developer 재수정"]
```

> 흐름 변경 시 위 mermaid 블록을 갱신한다 (단일 소스).

## 설치 (새 프로젝트에 클론)

프로젝트 루트에서 실행:

```bash
git clone https://github.com/JungwooKim1271011706/harness-setup.git .claude
```

> `git clone <url> <대상디렉터리>` — 마지막 인자를 `.claude`로 주면 그 이름으로 받는다.
> `.claude`가 이미 있으면 비우거나 백업 후 클론한다 (git clone은 빈 디렉터리 필요).

특정 브랜치를 받고 싶으면 `-b <브랜치명>`:

```bash
git clone -b <브랜치명> https://github.com/JungwooKim1271011706/harness-setup.git .claude
```

미지정 시 기본 브랜치(main, 안정 버전)를 받는다. 개발/실험 브랜치를 쓸 때만 `-b`로 지정.

## 클론 후 셋업 (필수 3단계)

### 1. 프로젝트 루트가 `.claude`를 추적하지 않게
`.claude`는 자체 git 레포다. 상위 프로젝트 레포가 중복 추적하지 않도록 루트 `.gitignore`에 추가:

```bash
echo "/.claude/" >> .gitignore
```

### 2. 프로젝트 코딩 규칙 생성
`rules/`는 프로젝트별 산출물이라 클론 시 비어 있다. 프로젝트 소스를 분석해 생성:

```
/rule-maker
```

### 3. 프로젝트 설정값 교체
`CLAUDE.md`의 `Harness Configuration` 섹션 값(projectName, frontendRoot/backendRoot, modules, examples 등)을 새 프로젝트에 맞게 수정한다. `agents/`는 이 변수만 참조하므로 직접 수정하지 않는다.

## 업데이트 (마스터 → 프로젝트)

하네스 개선은 이 레포 `main`에 누적된다. 프로젝트에서 최신 반영:

```bash
git -C .claude pull origin main
```

스킬 동기화는 `bash .claude/skills/sync-skills.sh`.

## 구조

| 경로 | 내용 | 추적 |
|------|------|------|
| `agents/` | 오케스트레이터·planner·developer·tester·finalizer | track |
| `skills/` | 커스텀 스킬, sync 스크립트 | track |
| `hooks/` | 세션 점검 훅 | track |
| `settings.json` | 공유 설정 | track |
| `rules/` | 프로젝트별 코딩 규칙 (rule-maker 생성) | ignore |
| `agent-memory/` | 프로젝트별 메모리 | ignore |
| `settings.local.json` | 로컬 권한/secret | ignore |
