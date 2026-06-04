---
name: harness-setup
description: 새 프로젝트에서 claude harness를 설정하는 스킬. CLAUDE.md의 프로젝트 개요와 Harness Configuration 섹션을 자동으로 생성한다. 프로젝트 구조를 분석해서 기술스택/빌드명령어/DB/아키텍처 개요와 projectName/memoryDir/frontendRoot/backendRoot/modules/backendExamples/frontendExamples 7개 변수를 자동 감지하고, 사용자 확인 후 CLAUDE.md에 기록한다. "harness 설정", "새 프로젝트에 harness 적용", "harness-setup", "claude 에이전트 설정", "Harness Configuration 추가" 등의 요청 시 반드시 이 스킬을 사용한다.
---

# harness-setup

새 프로젝트에 claude harness를 적용할 때 CLAUDE.md 전체를 자동으로 구성하는 스킬이다.  
`/init`이 하는 프로젝트 개요 + Harness Configuration을 한 번에 생성한다.

## 동작 흐름

### Step 1 — 프로젝트 구조 분석

아래 순서로 각 변수를 자동 감지한다.

#### projectName
```bash
# 1순위: pom.xml artifactId
grep -m1 '<artifactId>' pom.xml 2>/dev/null | sed 's/.*<artifactId>\(.*\)<\/artifactId>.*/\1/'
# 2순위: package.json name
node -e "console.log(require('./package.json').name)" 2>/dev/null
# 3순위: 현재 디렉터리명
basename "$PWD"
```

#### memoryDir
Claude Code는 프로젝트 절대 경로를 기반으로 memory 디렉터리를 결정한다.
경로 규칙: `~/.claude/projects/<경로를-하이픈으로-변환>/memory/`

```bash
# 현재 경로를 Claude Code memory 경로로 변환
PROJECT_PATH=$(pwd)
# Windows: C:\path\to\project → C--path-to-project
# Linux/Mac: /path/to/project → -path-to-project
echo "$PROJECT_PATH" | sed 's/[\\/:]/-/g; s/^-//'
```

실제 경로는 OS에 따라 다르므로 사용자에게 확인을 받는다.

#### frontendRoot
```bash
# package.json이 있는 서브 디렉터리 중 vue/react/vite 의존성이 있는 것 탐색
find . -maxdepth 2 -name "package.json" -not -path "*/node_modules/*" | while read f; do
  dir=$(dirname "$f")
  if grep -qE '"vue"|"react"|"vite"|"next"' "$f" 2>/dev/null; then
    echo "$dir/"
  fi
done
```

루트에 `package.json`이 있으면 `src/` 또는 빈 문자열.
없으면 탐색된 서브 디렉터리 경로.

#### backendRoot
```bash
# Maven 표준 구조
[ -d "src/main/java" ] && echo "src/main/java/"
# Gradle 동일
# 없으면 src/
[ -d "src" ] && echo "src/"
```

#### modules
```bash
# pom.xml modules 섹션
grep -A1 '<modules>' pom.xml 2>/dev/null | grep '<module>' | sed 's/.*<module>\(.*\)<\/module>.*/\1/'
# 없으면 루트 디렉터리명들 (src, test, config 제외)
ls -d */ 2>/dev/null | grep -vE 'src/|test/|\.claude/|node_modules/|target/|build/|dist/'
```

#### backendExamples

**목표: 도메인당 3개, 레이어를 골고루 (PageController + REST/Async + Service/Manager)**

**Step 1 — 프로젝트 네이밍 패턴 감지**

먼저 이 프로젝트가 어떤 클래스 네이밍을 쓰는지 파악한다.

```bash
# Spring MVC 패턴 감지
find . -path "*/src/main/java/**/*.java" -not -path "*/target/*" | xargs -I{} basename {} .java | sort | head -30
```

| 패턴 유형 | PageController | REST/Async | Service |
|----------|---------------|-----------|---------|
| 표준형 | `*Controller` | `*RestController` | `*Service` |
| MainFrame형 | `*MainFrame` | `*Async` | `*Manager` |
| 혼합형 | 위 중 감지된 것 | 위 중 감지된 것 | 위 중 감지된 것 |

**Step 2 — 도메인 디렉터리 열거**

```bash
# backendRoot 하위 com.*  패키지에서 도메인 수준 디렉터리 추출
# 예: com/crinity/mb/webapps/{mail,filter,user,dashboard,...}
find {backendRoot} -mindepth 4 -maxdepth 4 -type d -not -path "*/target/*" | sort
```

**Step 3 — 도메인별 3개 추출**

각 도메인 디렉터리에서 아래 우선순위로 최대 3개 선택:
1. PageController 계열 (MainFrame / Controller)
2. REST/Async 계열 (Async / RestController)
3. Service 계열 (Manager / Service)

3개가 안 되는 도메인(e.g., 클래스가 2개뿐)은 있는 것만 포함하고 패딩 없이 넘어간다.

**표준 제외 대상**: `test/`, `target/`, `vo/`, `dto/`, `config/`, 외부 라이브러리 패키지(org.jsoup 등)

#### frontendExamples

**목표: 도메인당 3개 JSP — popup/, include/ 서브디렉터리는 제외**

**Vue/React 프로젝트인 경우**

```bash
# components 디렉터리 하위에서 도메인 폴더 열거
find "${FRONTEND_ROOT}src/components" -mindepth 1 -maxdepth 1 -type d | while read domain; do
  # 각 도메인에서 .vue/.tsx 최대 3개
  find "$domain" -maxdepth 1 -name "*.vue" -o -name "*.tsx" | head -3 | xargs -I{} basename {} | sed 's/\.\(vue\|tsx\)//'
done
```

**JSP 프로젝트인 경우 (WEB-INF/jsp/pages/ 구조)**

```bash
# pages/ 하위 도메인 디렉터리 열거 (popup/, include/ 제외)
find {frontendRoot}pages -mindepth 1 -maxdepth 1 -type d \
  | grep -vE 'popup|include|common|element' | while read domain; do
  # 각 도메인에서 .jsp 최대 3개 (루트 레벨만, popup 서브 제외)
  find "$domain" -maxdepth 1 -name "*.jsp" | head -3 | xargs -I{} basename {} .jsp
done
```

**결과 제시 형식 (도메인 그룹 표)**

```
| 도메인 | 1 | 2 | 3 |
|--------|---|---|---|
| 메일   | MailMainFrame | MailAsync | LoginManager |
| 필터   | FilterMainFrame | FilterAsync | FilterWaitScheduler |
| ...    | ... | ... | ... |
```

사용자에게 도메인 표로 보여준 뒤 확인받고, 최종 flat list로 CLAUDE.md에 기록한다.

---

### Step 2 — 프로젝트 개요 분석 (NEW)

Harness Configuration과 별개로, Claude가 프로젝트를 이해하는 데 필요한 컨텍스트를 추출한다.

#### 탐색 대상 파일 (우선순위 순)

```bash
# 1. 빌드 설정에서 기술 스택/의존성 파악
Read: pom.xml 또는 */pom.xml (상단 100줄) → 언어 버전, 주요 프레임워크, 패키징
Read: package.json (있는 경우) → 프론트엔드 스택

# 2. Spring 컨텍스트에서 DB/인프라 파악
Glob: "**/src/main/resources/**/*.xml" → dao-context.xml, application-context.xml 등
Read: dao-context.xml 또는 datasource 설정 파일 → DB 종류, 접속 설정 파일 위치

# 3. 런타임 설정 파일 위치 파악
Glob: "**/src/main/resources/**" → properties, yml 파일 목록
Glob: "**/WEB-INF/conf/**" → 운영 설정 파일 (있는 경우)

# 4. README 참조
Read: README.md (있는 경우) → 프로젝트 설명

# 5. 테스트 설정
Read: pom.xml → skipTests 여부, 테스트 프레임워크
```

> skipTests가 리터럴 `true`면 `-DskipTests=false` CLI 오버라이드가 안 먹는다. 이 경우 tester가 런타임에 임시 오버라이드(sed로 임시 false → `mvn test` → trap 원복 + git checkout 자가치유)로 JUnit을 실행한다(C1-temp). 셋업에서 프로덕트 pom을 수정할 필요는 없다. 개요 '아키텍처 특이사항'에 "테스트: skipTests=true, tester 임시 오버라이드로 실행" 한 줄 기록을 권장한다.

#### 개요 섹션에서 추출할 항목

| 항목 | 출처 | 중요도 |
|------|------|--------|
| 프로젝트 한 줄 설명 | 디렉터리명/README/도메인 추론 | 필수 |
| 기술 스택 (언어·프레임워크·DB·빌드) | pom.xml, datasource 설정 | 필수 |
| 모듈 구조 표 | Step 1에서 감지한 modules | 필수 |
| 빌드 명령어 | pom.xml 구조 추론 | 필수 |
| 런타임 설정 파일 위치 | WEB-INF/conf, resources | 권장 |
| 주요 소스 경로 | 디렉터리 구조 | 권장 |
| 아키텍처 특이사항 | 코드/설정에서 발견한 것만 | 있으면 추가 |
| 고객사 전용 패키지 | `_xxx` 패키지 존재 시 | 있으면 추가 |

> **주의:** 없는 정보를 만들어내지 않는다. 확인된 것만 기록한다.

---

### Step 3 — 감지 결과 표시 및 사용자 확인

감지된 값을 표로 보여주고, 수정이 필요한 항목을 사용자에게 확인한다.

```
## 감지된 Harness Configuration

| 변수 | 감지된 값 | 신뢰도 |
|------|----------|--------|
| projectName | my-project | 높음 (pom.xml) |
| memoryDir | C:\Users\...\memory\ | 확인 필요 |
| frontendRoot | frontend/ | 높음 |
| backendRoot | src/main/java/ | 높음 |
| modules | api, core, web | 중간 |

backendExamples (도메인당 3개):
| 도메인 | PageController | REST/Async | Service/Manager |
|--------|---------------|-----------|-----------------|
| 메일   | MailMainFrame | MailAsync | ... |
| 필터   | FilterMainFrame | FilterAsync | ... |
| ...    | ... | ... | ... |

frontendExamples (도메인당 3개):
| 도메인 | 1 | 2 | 3 |
|--------|---|---|---|
| 메일   | mail_list | mail_detail | mail_status |
| 필터   | filter_list | filter_detail | ... |
| ...    | ... | ... | ... |

수정할 항목이 있으면 알려주세요. 없으면 CLAUDE.md에 기록합니다.
```

신뢰도 기준:
- **높음**: 파일에서 직접 추출한 값
- **중간**: 디렉터리/파일명에서 추론한 값
- **확인 필요**: OS별 경로 계산이 필요한 값

---

### Step 4 — CLAUDE.md 기록

사용자 확인 후 CLAUDE.md를 생성하거나 업데이트한다.

**CLAUDE.md가 없으면** 아래 전체 구조로 새로 생성한다.  
**이미 있으면** 기존 내용을 Read한 뒤 섹션별로 병합한다 (덮어쓰기 금지).

#### CLAUDE.md 전체 구조

```markdown
# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 프로젝트 개요

{프로젝트 한 줄 설명}

### 기술 스택
- **언어**: {언어 및 버전}
- **프레임워크**: {프레임워크}
- **DB**: {DB 종류} ({DB 타입 분기 방식 등 특이사항})
- **빌드**: {빌드 도구}
- **서버**: {서버} ({배포 방식})
- **프론트엔드**: {프론트엔드 기술} (프론트 없으면 생략)
- **로깅**: {로깅 프레임워크 및 설정 파일 위치}

### 모듈 구조
| 모듈 | 역할 | 패키징 |
|------|------|--------|
| `{모듈명}` | {역할} | {JAR/WAR} |

### 빌드 명령어
```bash
{실제 빌드 명령어}
```

### 런타임 설정 파일 (빌드 산출물에 미포함)
- `{경로}` — {설명}

### 주요 경로
- {역할}: `{경로}`

### 아키텍처 특이사항
- {코드/설정에서 발견한 것만 기재. 없으면 섹션 생략}

---

## Harness Configuration

에이전트 md 파일이 참조하는 프로젝트별 변수. 새 프로젝트에서 이 섹션만 수정하면 `.claude/agents/`를 그대로 재사용할 수 있다.

| 변수 | 값 | 설명 |
|------|-----|------|
| `projectName` | {projectName} | 에이전트 자기소개에 사용되는 프로젝트명 |
| `memoryDir` | `{memoryDir}` | 실패 패턴·학습 기록 저장 디렉터리 |
| `frontendRoot` | `{frontendRoot}` | 프론트엔드 소스 루트 (developer-backend 수정 금지 경계) |
| `backendRoot` | `{backendRoot}` | 백엔드 소스 루트 (developer-frontend 수정 금지 경계) |
| `modules` | {modules} | 오케스트레이터 모듈 컨텍스트 예시 |
| `backendExamples` | {backendExamples} | 백엔드 tester 회귀 검증 대표 클래스 예시 (도메인당 3개) |
| `frontendExamples` | {frontendExamples} | 프론트엔드 tester 회귀 검증 대표 컴포넌트 예시 (도메인당 3개) |

> **주의:** 이 섹션의 변수가 잘못되면 모든 에이전트가 오동작한다. 새 프로젝트 셋업 후 반드시 값 검증 필요.
```

---

### Step 5 — 완료 보고

```
CLAUDE.md 설정 완료.

생성된 섹션:
- 프로젝트 개요 (기술 스택, 모듈 구조, 빌드 명령어, 아키텍처)
- Harness Configuration (7개 변수)

다음 단계:
1. memoryDir 값이 실제 Claude Code 프로젝트 경로와 일치하는지 확인
2. /rule-maker 실행 → 프로젝트 전용 backend.md / frontend.md 자동 생성
3. .claude/는 harness-setup repo를 통째로 clone한 것이므로 agents/skills/hooks는 이미 포함됨. 루트 .gitignore에 /.claude/ 추가해 상위 repo가 중복 추적하지 않게 한다.
```

---

## 주의사항

- CLAUDE.md를 직접 열어서 읽은 후 수정한다 (덮어쓰기 금지)
- 기존 섹션이 있으면 내용을 병합하고 다른 섹션은 건드리지 않는다
- **프로젝트 개요는 확인된 정보만** — 없는 내용 추측 금지
- memoryDir은 OS에 따라 경로 구분자가 다르므로 반드시 사용자 확인
- modules, backendExamples, frontendExamples는 "예시" 값이므로 완벽할 필요 없음 — 사용자가 나중에 수정 가능
