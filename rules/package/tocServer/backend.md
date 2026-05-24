# tocServer 백엔드 규칙

## 역할
Spring MVC 기반 스팸차단 웹 어드민 (WAR). 수신/발신 메일 로그 조회, 필터 관리, 도메인/사용자 관리, 통계, 설정 등 관리자 기능 전체를 담당.

---

## 클래스 네이밍 패턴

| 역할 | 접미사 | 어노테이션 | 비고 |
|------|--------|-----------|------|
| 페이지 컨트롤러 | `*MainFrame` | `@Controller` + `@RequestMapping` | String 반환, Model 사용 |
| REST/비동기 컨트롤러 | `*Async` | `@Controller` + `@ResponseBody` | `Map<String,Object>` 반환 |
| 서비스 | `*Manager` | `@Service` | 비즈니스 로직 담당 |
| DAO | `*DAO` | `@Repository` (또는 MyBatis) | DB 접근 |
| 인터셉터 | `*Interceptor` | `HandlerInterceptorAdapter` 상속 | |
| 스케줄러 | `*Scheduler` | `@Scheduled` | |

---

## 컨트롤러 구조

### MainFrame (페이지 컨트롤러)
```java
@Controller
@RequestMapping("/filter")
public class FilterMainFrame {

    @Autowired private FilterSmtpManager filterSmtpManager;
    @Autowired private SessionManager sessionManager;

    @GetMapping(value = "")
    public String mainframe(Model model, HttpServletRequest request) {
        SbUser sbUser = sessionManager.getSbLoginUser(request.getSession());
        model.addAttribute("include", FilterPartKey.SMTPPART);
        return "/pages/filter/mainframe";
    }

    @GetMapping(value = "/smtp/{subMenu}")
    public String smtpFilterMain(Model model, @PathVariable("subMenu") String subMenu) {
        // ...
        return "/pages/filter/_smtp_list";
    }
}
```

### Async (REST 컨트롤러)
```java
@Controller
@RequestMapping("/maillog")
public class MailLogListAsync {

    @Autowired private MailLogManager mailLogManager;
    @Autowired private SessionManager sessionManager;

    @PostMapping(value = "/in/mail/list.json")
    @ResponseBody
    public Map<String, Object> maillogInList(HttpSession session, SbMailLogForm mailLogForm) throws Exception {
        SbUser loginUser = sessionManager.getSbLoginUser(session);
        return mailLogManager.doSelectIn(mailLogForm);
    }
}
```

---

## 의존성 주입

`@Autowired` **필드 주입** 사용 (Lombok `@RequiredArgsConstructor` 미사용).

```java
@Autowired private FilterSmtpManager filterSmtpManager;
@Autowired private SessionManager sessionManager;
```

---

## 응답 형식

### 목록 조회 (Async)
```java
Map<String, Object> resultMap = new HashMap<>();
resultMap.put(WebConstant.totalCount, dao.getCount(form));
resultMap.put(WebConstant.contents, dao.getList(form));
return resultMap;
```

### CUD 작업 (성공/실패)
```java
Map<String, Object> resultMap = new HashMap<>();
resultMap.put(JsonUtil.RESULT, JsonUtil.FAILURE);   // 기본값 실패
resultMap.put(WebConstant.msg, msa.getMessage("Info.failure.insert", locale));

// ... 처리 ...

resultMap.put(JsonUtil.RESULT, JsonUtil.SUCCESS);
resultMap.put(WebConstant.msg, msa.getMessage("Info.success.insert", locale));
return resultMap;
```

- `JsonUtil.RESULT` = `"result"`, `JsonUtil.SUCCESS` = `true`, `JsonUtil.FAILURE` = `false`
- `WebConstant.totalCount` = `"totalCount"`, `WebConstant.contents` = `"contents"`, `WebConstant.msg` = `"msg"`

---

## 감사 로깅 (Audit)

### 어노테이션 선언
```java
@Audit(actionType = 17)
public Map<String, Object> doAddFilter(HttpServletRequest req, String emailId, SbMailLogForm mailLogForm) {
```

### Request Attribute 설정 (AOP가 수집)
```java
req.setAttribute(WebConstant.actionResult, 1);   // 1=실패, 2=성공
req.setAttribute(WebConstant.subject, emailId);
req.setAttribute(WebConstant.actionScreen, 3);
req.setAttribute(WebConstant.actionDetail, detailObject);
```

- `@Audit` 어노테이션 → `AuditAdvice` AOP가 `@AfterReturning`으로 처리
- `request` 파라미터가 첫 번째 인자여야 AOP pointcut에 걸림
- 성공 후 `req.setAttribute(WebConstant.actionResult, 2)` 로 업데이트

---

## 로깅

**선언 방식**: Lombok `@Slf4j` 미사용, 직접 선언.
```java
private static final Logger logger = LoggerFactory.getLogger(MailLogManager.class);
```

**메시지 패턴**: `도메인 > 액션 > 결과 : 상세정보`
```java
logger.info("MAIL > RECOVERY > SUCCESS : from={}, to={}, code={}", from, to, code);
logger.warn("MAIL > DELETE > FAIL : Null or empty page");
logger.error("MAIL > RECOVERY > ERROR : {}", e.getMessage(), e);
```

---

## 에러 처리

```java
// Early return 패턴 (검증 실패 시 즉시 반환)
if (StringUtils.isEmpty(page)) {
    logger.warn("MAIL > DELETE > FAIL : Null or empty page");
    return resultMap;
}

// 예외는 try/catch로 감싸고 logger.error
try {
    // ...
} catch (Exception e) {
    logger.error("DOMAIN > ACTION > ERROR : {}", e.getMessage(), e);
    return resultMap;
}
```

---

## 인증/인가

```java
// 세션에서 로그인 사용자 조회
SbUser loginUser = sessionManager.getSbLoginUser(session);

// 권한 레벨 체크
if (loginUser.getUserLevel() == UserLevel.SUPERADMIN.getValue()) { ... }
if (sbUser.getUserLevel() == 4) { ... }  // 4 = 슈퍼관리자

// UserLevel enum
UserLevel.getUserLevel(loginUser.getUserLevel())  // SUPERADMIN, DOMAINADMIN, USER
```

- 인터셉터(`LoginCheckInterceptor`)가 세션 유무와 IP 접근 정책을 사전 검증
- IP 검증: `accessChecker.isAccessibleIP(remoteIp)` → 실패 시 404 반환

---

## 입력값 검증

- 프레임워크 `@Valid` 미사용; 직접 `StringUtils.isEmpty()`, `CollectionUtils.isEmpty()` 확인
- 파라미터 바인딩: `@ModelAttribute` 또는 메서드 파라미터 직접 바인딩 (Form 객체)
- JSON 역직렬화가 필요한 경우 Jackson `ObjectMapper` 사용:
  ```java
  ObjectMapper mapper = new ObjectMapper();
  mapper.configure(DeserializationFeature.FAIL_ON_UNKNOWN_PROPERTIES, false);
  SomeForm form = mapper.readValue(url, SomeForm.class);
  ```

---

## JSON 라이브러리

- **Jackson**: 요청/응답 직렬화 주력 (`ObjectMapper`)
- **Gson**: 특정 데이터 파싱에 혼용 (예: `mailLog.getPattern_multi()` 역직렬화)
  ```java
  Gson gson = new Gson();
  List<FilterCondition> list = gson.fromJson(json, new TypeToken<List<FilterCondition>>() {}.getType());
  ```

---

## 패키지 구조

```
com.crinity.sb
├── audit/aop/         # AuditAdvice, Audit 어노테이션, AuditService
├── constant/          # WebConstant, UserLevel, FilterKeys 등
└── webapps/
    ├── {domain}/
    │   ├── controller/   # *MainFrame, *Async
    │   ├── service/      # *Manager
    │   └── param/        # *BaseParam (그리드 파라미터)
    ├── common/           # 공통 서비스, 상수
    ├── interceptor/      # 인터셉터
    ├── scheduler/        # 스케줄러
    └── util/             # POIUtil, FileExportUtil, MailViewUtil 등
```

---

## 주의사항

- `org.jsoup` 패키지가 소스에 직접 포함되어 있음 — 분석/수정 대상 아님
- 감사로그 대상 메서드의 첫 번째 파라미터는 반드시 `HttpServletRequest request` 여야 AOP가 작동함
- `JsonUtil.SUCCESS` = `true` (boolean), `JsonUtil.FAILURE` = `false` (boolean) — 숫자 아님
