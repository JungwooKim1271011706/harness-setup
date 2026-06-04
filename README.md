# harness-setup

Claude Code 오케스트레이션 하네스. 설계 중심 워크플로(3트랙 / 설계 패널 게이트 / OOP 정렬 co-plan / TDD 합의 / FAIL 3분기)를 담은 `.claude` 디렉터리 묶음이다.

새 프로젝트에 이 하네스를 **`.claude` 디렉터리로 클론**해서 사용한다.

## 설치 (새 프로젝트에 클론)

프로젝트 루트에서 실행:

```bash
git clone https://github.com/JungwooKim1271011706/harness-setup.git .claude
```

> `git clone <url> <대상디렉터리>` — 마지막 인자를 `.claude`로 주면 그 이름으로 받는다.
> `.claude`가 이미 있으면 비우거나 백업 후 클론한다 (git clone은 빈 디렉터리 필요).

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
