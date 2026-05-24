# tocFramework 백엔드 규칙

## 역할
tocServer와 tocProcess 양쪽에서 공유하는 공통 라이브러리. DAO/VO/Form/상수, 프레임워크 유틸리티, Spring 설정, 커스텀 태그라이브러리(crlib.tld) 구현체를 제공한다. 직접 실행되는 모듈이 아니라 JAR로 패키징되어 의존성으로 사용된다.

---

## 패키지 구조

```
com.crinity
├── ar.*              # AR(Archive) 도메인 DAO/VO/Service
├── config.*          # 설정 관련 DAO/VO/Manager
├── framework.*       # 핵심 유틸리티 (session, file, mail, util, log)
├── sb.*              # SB 도메인 DAO/VO/Form/상수 (tocServer/tocProcess 공유)
│   ├── constant/     # WebConstant, UserLevel, FilterKeys, ActionType 등
│   ├── {domain}/dao/ # 도메인별 DAO
│   ├── {domain}/vo/  # 도메인별 VO
│   └── {domain}/form/# 폼 바인딩 객체
├── webcmp.taglibs.*  # cr: 커스텀 태그라이브러리 구현체
└── org.jsoup.*       # 내장 jsoup (수정 금지)
```

---

## DAO 패턴 (MyBatis)

```java
@Repository
public class ArGroupDAO {

    @Resource(name = "arSession") private SqlSession sqlSession;
    // SB 도메인은: @Resource(name = "sbSession") private SqlSession sqlSession;

    public int insertGroup(ArGroup group) {
        return sqlSession.insert("insertGroup", group);
    }

    public int updateMultiGroup(int[] seq, ArGroup group) {
        HashMap<String, Object> param = new HashMap<>();
        param.put("groupUid", seq);
        param.put("groupDesc", group.getGroupDesc());
        // ...
        return sqlSession.update("updateMultiGroup", param);
    }

    public ArGroup getGroup(int seq) {
        return sqlSession.selectOne("getGroup", seq);
    }

    public List<ArGroup> getGroupList(ArGroupForm form) {
        return sqlSession.selectList("getGroupList", form);
    }
}
```

**SqlSession 이름 규칙:**
- `arSession` — AR 도메인 DB
- `sbSession` — SB 도메인 DB
- `emSession` — 임베디드 DB (embedded)

**복수 파라미터는 HashMap으로 래핑**하여 전달. 단일 파라미터는 직접 전달.

---

## 의존성 주입

- DAO: `@Resource(name="세션명")` — SqlSession 이름 기반 주입
- Service: `@Autowired` 필드 주입 (Lombok 미사용)
- 로거: `private static final Logger logger = LoggerFactory.getLogger(ClassName.class)`

---

## 프레임워크 유틸리티

### SessionManager (`com.crinity.framework.support.session`)
```java
// 세션에서 사용자 조회
SbUser sbUser = sessionManager.getSbLoginUser(session);
CrUser crUser = sessionManager.getLoginUser(session);

// 세션 값 조작
sessionManager.setSessionValue(session, "key", value);
Object val = sessionManager.getSessionValue(session, "key");
sessionManager.removeSessionValue(session, "key");
```

### LogMessage (`com.crinity.framework.support.log`)
```java
// 형식: [owner:email]{ip} CATEGORY/CATEGORY - 메시지
logger.info(LogMessage.getMessage(getClass(), LogMessage.MANAGE, request, emailId, "상세메시지"));
logger.info(LogMessage.getMessage(getClass(), LogMessage.MANAGE, request, "메시지"));
logger.info(LogMessage.getMessage(getClass(), LogMessage.LOGIN, emailId, "메시지"));

// 카테고리 상수 (LogMessage.*)
LogMessage.LOGIN, LogMessage.LOGOUT, LogMessage.MANAGE,
LogMessage.REMOVE, LogMessage.SEND, LogMessage.ATTACH
```

### JsonUtil (`com.crinity.framework.util`)
```java
JsonUtil.RESULT    // "result"
JsonUtil.SUCCESS   // true (boolean)
JsonUtil.FAILURE   // false (boolean)
```

### WebConstant (`com.crinity.sb.constant`)
```java
WebConstant.totalCount   // "totalCount"
WebConstant.contents     // "contents"
WebConstant.msg          // "msg"
WebConstant.actionResult // "actionResult"
WebConstant.actionDetail // "actionDetail"
WebConstant.subject      // "subject"
WebConstant.actionScreen // "actionScreen"
WebConstant.actionType   // "actionType"
WebConstant.passAuditFlag// "passAuditFlag"
```

---

## 주의사항

- `com.crinity.webcmp.taglibs.*` — crlib.tld 태그 구현체. 태그 동작을 변경하면 전체 JSP UI에 영향 — **신중히 수정**
- `org.jsoup.*` — 외부 라이브러리 소스 직접 포함. **수정 금지**
- 이 모듈의 DAO/VO/상수를 수정하면 tocServer와 tocProcess 양쪽에 영향을 줌
- SqlSession 이름(`arSession`, `sbSession`)은 Spring XML 설정에서 정의됨. 임의로 변경 불가
