---
name: rule-maker
description: "소스코드 분석 기반 rules 파일 자동 생성. 새 프로젝트에서 .claude/ 재사용 시 모듈별 backend.md + frontend.md를 코드 패턴 분석으로 생성."
---

# rule-maker

소스코드를 직접 읽어 실제 코딩 패턴을 분석하고,
`.claude/rules/package/<모듈>/backend.md` + `frontend.md`를 자동 생성한다.

호출: `/rule-maker`

---

## Step 1: 프로젝트 경로 확인

사용자에게 질문:
"프로젝트 홈 경로를 알려주세요. (미입력 시 현재 디렉터리 사용)"

- 입력 있으면 해당 경로 사용
- 미입력이면 현재 작업 디렉터리 사용

---

## Step 2: 모듈 구조 탐색

### 멀티 모듈 감지 (Maven/Gradle)

루트 `pom.xml`이 없고 서브 디렉터리에 `pom.xml`이 여러 개 있으면 멀티 모듈 프로젝트다.

```bash
# 서브 모듈 pom.xml 탐색 (depth 1)
Glob: "*/pom.xml"

# 각 모듈의 artifactId 확인
Read: {module}/pom.xml (상단 20줄)
```

각 `pom.xml`에서 `<artifactId>` 추출 → 모듈 역할 파악.

### 백엔드 소스 루트 확인

각 모듈별로 탐색:
```bash
Glob: "*/src/main/java/**/*.java"  # 전체 자바 파일 목록
```

### 프론트엔드 감지 (우선순위 순)

1. **Vue/React/Vite** — `package.json` 탐색 후 의존성 확인
2. **JSP** — `src/main/webapp/WEB-INF/jsp/` 디렉터리 존재 여부
3. **없음** — 순수 백엔드 모듈

```bash
Glob: "*/src/main/webapp/WEB-INF/jsp/pages/**/*.jsp"  # JSP 도메인 구조 파악
```

### 네이밍 패턴 사전 감지 (**중요**)

파일 분석 전에 실제로 어떤 네이밍 패턴을 쓰는지 먼저 파악한다.
표준 `Controller/Service/Repository`가 아닐 수 있다.

```bash
# 전체 자바 파일명 목록 확인
Glob: "{mainModule}/src/main/java/**/*.java"
```

파일명 목록에서 접미사 패턴 분류:

| 패턴 유형 | PageController | REST/Async | Service | 비고 |
|----------|---------------|-----------|---------|------|
| 표준형 | `*Controller` | `*RestController` | `*Service` | Spring Boot 일반 |
| MainFrame형 | `*MainFrame` | `*Async` | `*Manager` | 이 프로젝트 tocServer |
| 혼합형 | 위 중 감지된 것 | 위 중 감지된 것 | 위 중 감지된 것 | |

이 단계에서 잘못 가정하면 Step 4에서 파일을 못 찾는다.

---

## Step 2.5: 모듈 의존성 분석

멀티 모듈인 경우, 각 모듈 pom.xml에서 **내부 모듈 간 의존 방향**을 추출한다. (의존 방향은 프로젝트마다 다르므로 가정하지 말고 pom에서 직접 읽는다.)

~~~bash
# 각 모듈 pom에서 같은 조직 그룹(com.<org>) 의존만 추출
# 예: grep -A2 "<groupId>com.crinity" {module}/pom.xml → artifactId 수집
~~~

추출 절차:
1. 각 모듈의 `<artifactId>` (자기 자신) 식별
2. 각 모듈 `<dependencies>`에서 **다른 모듈의 artifactId**를 의존으로 수집 (외부 라이브러리 제외, 같은 조직 groupId만)
3. 방향 그래프(DAG) 구성: `A → B` = A가 B에 의존
4. 순환 의존 발견 시 경고로 표시
5. 최하위(의존 0) 모듈 = 공통 라이브러리로 식별

이 결과로 각 모듈 backend.md의 `## 의존성 방향` 섹션을 자동 작성한다. 단일 모듈 프로젝트면 이 Step과 의존성 방향 섹션을 생략한다.

---

## Step 3: 디렉터리명 확인

발견된 모듈을 사용자에게 보여주고 각각의 `.claude/rules/package/` 하위 디렉터리명을 확인한다.

예시 출력:
```
발견된 모듈:
  [1] tocServer/src/main/java/ (Spring MVC 웹앱) → 디렉터리명? [기본: tocServer]
  [2] tocFramework/src/main/java/ (공통 프레임워크) → 디렉터리명? [기본: tocFramework]
  [3] tocServer/src/main/webapp/WEB-INF/jsp/ (JSP 프론트) → tocServer/frontend.md로 생성
```

미입력 시 기본값(모듈 디렉터리명)을 그대로 사용한다.

---

## Step 4: 소스코드 분석

각 모듈에서 대표 파일을 **Read로 전체 읽기** (샘플링 아님, 정확도 우선).  
Step 2에서 감지한 네이밍 패턴을 기준으로 파일을 선택한다.

### 백엔드 대상 파일 선택 기준 (모듈당 4~6개)

**필수 (레이어 균형)**
- PageController 계열 1개 (`*MainFrame` 또는 `*Controller`)
- REST/Async 계열 1개 (`*Async` 또는 `*RestController`)
- Service 계열 1개 (`*Manager` 또는 `*Service`)

**선택 (프로젝트 특성 반영)**
- Interceptor / Filter 1개 (인증/보안 패턴 파악)
- Scheduler 1개 (있는 경우)
- DAO / Repository 1개 (있는 경우)

**제외 대상**
- `target/`, `test/` 하위 파일
- 외부 라이브러리 소스 (예: `org.jsoup`, `org.apache.james` 등)
- VO, DTO, Form, Enum 단순 데이터 클래스 (패턴 분석에 불필요)

### 모듈 간 스타일 차이 감지 (**중요**)

같은 프로젝트라도 모듈마다 스타일이 다를 수 있다.  
각 모듈의 파일을 읽은 후 아래 항목을 **모듈별로 비교**한다:

| 항목 | 확인 방법 |
|------|---------|
| DI 방식 | `@Autowired` 필드 vs `@RequiredArgsConstructor` 생성자 |
| 로거 선언 | `LoggerFactory.getLogger()` vs `@Slf4j` (Lombok) |
| 응답 타입 | `Map<String, Object>` vs `ResponseEntity<T>` |
| JSON 라이브러리 | Jackson (`ObjectMapper`) vs Gson |
| 커스텀 어노테이션 | `@Audit`, `@CrValidationForm` 등 |
| Lombok 사용 여부 | `@Data`, `@Slf4j`, `@RequiredArgsConstructor` |

차이가 있으면 각 모듈 rules 파일에 **비교 표**로 명시한다.

### 프론트엔드 대상 파일

**Vue/React 프로젝트**
- `package.json` → 프레임워크/라이브러리 감지
- 주요 페이지 또는 컴포넌트 파일 2~3개
- API 레이어 파일 1~2개
- 상태관리 파일 1~2개 (있으면)

**JSP 프로젝트**
- 도메인별 JSP 1개씩 (목록 페이지 우선, popup/include 제외)
- 커스텀 태그라이브러리 TLD 파일 경로 확인
- 공통 레이아웃 JSP (head.jsp, top.jsp 등)

---

## Step 5: 패턴 분석

읽은 파일에서 아래 항목을 추출한다.

### 백엔드 추출 항목

- **네이밍**: 클래스명/메서드명/변수명 패턴 (표준형 vs 프로젝트 고유형)
- **의존성 주입**: 필드 주입 vs 생성자 주입, `private` 키워드 포함 여부
- **어노테이션**: 커스텀 어노테이션 포함 (`@Audit`, `@CrValidationForm` 등)
- **응답 형식**: 반환 타입, Map 구현체 종류 (`HashedMap` vs `HashMap`), 공통 키 상수
- **감사 로깅**: 커스텀 감사 어노테이션 유무, `req.setAttribute` 패턴
- **에러 처리**: try/catch 구조, `@ExceptionHandler`, Early return 패턴
- **로깅**: 로거 선언 방식, 커스텀 로그 유틸 클래스 (`MbLogMessage` 등)
- **인증/인가**: 세션/토큰 처리, 권한 체크 방식, IP 검증
- **입력 검증**: 커스텀 유틸 (`ObjectUtils`, `PatternCheckUtil`) vs 표준 (`@Valid`)
- **보안**: XSS/CSRF 필터, 암호화 방식 (RSA, SHA256 등)
- **JSON**: 직렬화 라이브러리 (Jackson vs Gson), 역직렬화 패턴

### 프론트엔드 추출 항목

**Vue/React**
- 프레임워크, 컴포넌트 구조, API 호출, 상태관리, 네이밍, CSS 방식

**JSP**
- 커스텀 태그라이브러리 종류와 사용 패턴 (`<cr:select>`, `<cr:input>` 등)
- i18n 방식 (`<spring:message>` 코드 패턴)
- 권한별 조건 렌더링 패턴 (`${_level}`, `${type}`)
- 페이지 레이아웃 CSS 클래스 컨벤션
- JavaScript 네이밍 (페이지별 객체 `_도메인.메서드()` 패턴)
- JSTL 사용 패턴 (`c:forEach`, `c:if`)

---

## Step 6: 추출 결과 확인

분석 결과를 모듈별로 보여준다:

```
[tocServer] 분석 완료
백엔드 핵심 패턴:
  - 클래스 네이밍: *MainFrame (페이지), *Async (REST), *Manager (서비스)
  - 응답: HashedMap + JsonUtil.RESULT 상수
  - 감사로그: @Audit 어노테이션 + req.setAttribute(AUDIT_RESULT)
  - 로깅: MbLogMessage.getMessage(도메인상수, 레벨, req, emailId, "메시지")
  - 의존성 주입: @Autowired 필드 주입

[mbfilter] 분석 완료
백엔드 핵심 패턴 (tocServer와 다른 점):
  - Lombok: @Slf4j, @RequiredArgsConstructor 사용
  - 응답: ResponseEntity<T> (Map 아님)
  - JSON: Gson (Jackson 아님)

[tocServer JSP] 분석 완료
프론트엔드 핵심 패턴:
  - 커스텀 태그: <cr:select>, <cr:input>, <cr:datepicker>
  - i18n: <spring:message code="..."/> 필수
  - JS 객체: _mail.doSearch(), _filter.doInsert() 등

추가하거나 제외할 항목이 있나요?
```

사용자 피드백 반영 후 다음 단계 진행.

---

## Step 7: 파일 생성 / 병합

### 신규 생성
아래 경로에 파일 작성:
- `.claude/rules/package/<확정명>/backend.md`
- `.claude/rules/package/<확정명>/frontend.md` (프론트 있는 경우만)

### 기존 파일 있는 경우
1. 기존 파일 Read
2. 섹션별 내용 비교
3. 새로 분석한 내용으로 병합 (더 구체적인 규칙 우선, 중복 제거)
4. 병합 결과로 덮어쓰기

### backend.md 필수 섹션 구조

```markdown
# {모듈명} 백엔드 규칙

## 역할
(이 모듈이 무엇을 담당하는지 1~2줄)

## 의존성 방향 (멀티 모듈인 경우)
(Step 2.5 분석 결과. 이 모듈이 의존하는/하지 않는 모듈과 역참조 금지 규칙.)

## 클래스 네이밍 패턴
(표 형식 — 역할/접미사/어노테이션)

## 컨트롤러 구조
(코드 예시 포함)

## 의존성 주입
## 응답 형식
## 감사 로깅 (있는 경우)
## 로깅
## 에러 처리
## 인증/인가
## 입력값 검증
## 패키지 구조
## 안티패턴 (절대 금지)
(기존 '주의사항'에 산재한 금지 규칙을 명시적으로 모은 섹션 + 의존 방향 위반 금지.)
## 주의사항 (있는 경우)
```

### frontend.md 필수 섹션 구조

**Vue/React**
```markdown
## 기술 스택
## 컴포넌트 구조
## API 호출 패턴
## 상태관리
## 네이밍 컨벤션
## CSS/스타일
```

**JSP**
```markdown
## 기술 스택
## JSP 파일 헤더 (필수)
## 페이지 레이아웃 구조
## 커스텀 태그 사용법
## 권한별 조건 렌더링
## JavaScript 네이밍 컨벤션
## CSS 클래스 컨벤션
## 반복 목록 패턴
## 데이터 바인딩 패턴
```

---

## 출력 형식

```
## rule-maker 완료
### 생성된 파일
- .claude/rules/package/<모듈>/backend.md
- .claude/rules/package/<모듈>/frontend.md

### 주요 추출 규칙 요약
(각 모듈별 핵심 규칙 3~5개)

### 모듈 의존성 방향 (멀티 모듈인 경우)
(예: tocFramework ← tocProcess, tocServer / 순환 없음 / 최하위=tocFramework)

### 모듈 간 스타일 차이 (멀티 모듈인 경우)
| 항목 | 모듈A | 모듈B |
|------|-------|-------|
| DI 방식 | @Autowired 필드 | @RequiredArgsConstructor |
| ...  | ...   | ...   |
```

---

## 주의사항

- **의존성 방향을 가정하지 않는다** — pom의 실제 의존 관계를 파싱한다. 모듈 수·이름·방향은 프로젝트마다 다르다
- **네이밍 패턴을 가정하지 않는다** — 파일 목록을 먼저 보고 실제 접미사를 확인한다
- **모듈 간 차이를 놓치지 않는다** — 같은 프로젝트라도 모듈마다 Lombok 유무, DI 방식, 응답 타입이 다를 수 있다
- **외부 라이브러리 소스 제외** — `org.jsoup`, `org.apache` 등 벤더 코드는 분석 대상에서 제외
- **JSP 프론트 감지** — `package.json`이 없다고 프론트가 없는 게 아니다. `WEB-INF/jsp/` 확인 필수
- 기존 `## Harness Configuration` 섹션이 있으면 값만 업데이트하고 다른 섹션은 건드리지 않는다
