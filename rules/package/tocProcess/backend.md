# tocProcess 백엔드 규칙

## 역할
SMTP 메일 처리 엔진 (MDA/MTA). 수신/발신 메일의 필터링, 큐 처리, 인덱싱, 설정 리로드(rlod) 등 메일 서버 백엔드 로직을 담당. Spring MVC 웹 레이어 없음 — 독립 JAR 프로세스로 실행.

---

## 패키지 구조

```
com.crinity
├── cm.*                        # Repository 어댑터 레이어 (DAO 추상화)
│   ├── api/                    # CmRepositoryAdapter 인터페이스
│   └── repository/             # DB별 구현체 (essential, master)
├── indexer.*                   # 메일 인덱싱 엔진 (Lucene 기반)
│   ├── processor/              # 인덱싱 프로세서
│   ├── queue/                  # 인덱싱 큐
│   └── service/                # 인덱싱 서비스
├── smtp._mda.*                 # MDA (Mail Delivery Agent)
│   ├── filter/                 # 메일 필터 구현체
│   └── queue/                  # MDA 큐 처리
├── smtp._mta.*                 # MTA (Mail Transfer Agent)
│   ├── command/                # SMTP 커맨드 핸들러
│   └── queue/                  # MTA 큐 처리
├── smtp.sb.*                   # SB(SpamBreaker) SMTP 공통
│   ├── common/                 # 설정 관리, 스케줄러, 서비스
│   ├── mda/                    # SB MDA 구현
│   └── mta/                    # SB MTA 구현
├── migration.*                 # 마이그레이션 도구 (운영 제외 시 컴파일 제외됨)
└── org.apache.*                # Apache James 소스 내장 (수정 금지)
```

---

## 컴포넌트 패턴

### 일반 서비스/필터
```java
@Component          // 또는 @Service
public class APTFilter {

    private static final Logger logger = LoggerFactory.getLogger(APTFilter.class);

    @Autowired private SbSmtpConfigManager config;
    @Autowired private WaitQueue waitQueue;
    @Autowired private LogService logService;

    public boolean doProcessCheckResult(MailetQueueEntity entity) throws Exception {
        // ...
    }
}
```

### 스케줄러 (AbstractCtsServerTask 상속)
```java
@Service
public class SbRlodScheduler extends AbstractCtsServerTask {

    private static final Logger logger = LoggerFactory.getLogger(SbRlodScheduler.class);

    @Autowired SbEngineCommonRlodService rlodCommonService;

    @Override
    protected void init() throws Exception {
        // 최초 1회 초기화
        rlodLastUpdated = rlodEngineDAO.getRlodlastUpdated() - 10000L;
    }

    @Override
    public void run() {
        // 주기적으로 실행되는 로직
    }
}
```

---

## 의존성 주입

- `@Autowired` 필드 주입 (tocServer와 동일, Lombok 미사용)
- 로거: `private static final Logger logger = LoggerFactory.getLogger(ClassName.class)`

---

## 설정 관리

```java
// SMTP 설정 접근
SbSmtpConfigManager configManager.getSbSmtpConfig()   // _SbSmtp 전체 설정
configManager.getSbAdminConfig()                       // _SbAdmin 관리 설정

// 설정 구조
_SbSmtp config = configManager.getSbSmtpConfig();
config.getMda().getApt().getProductType()             // MDA APT 설정
config.getCommon().getEngines()                       // 엔진 목록 (_Engine 리스트)
config.getCommon().getSbStorage().getSftp()           // SFTP 설정
```

---

## 로깅 패턴

tocServer와 동일한 `"도메인 > 액션 > 결과"` 패턴 사용.

```java
logger.info("RLOD > EXECUTE : COMMAND = [{}, {}, {}, {}]", server, category, cmd, data);
logger.debug("APT > CHECK > START : seq={}", entity.getSeq());
logger.warn("RLOD > SKIP : no service matched, server={}", server);
logger.error("RLOD > ERROR : {}", e.getMessage(), e);
```

---

## 리로드 (rlod) 패턴

설정 변경 시 엔진에 실시간 반영하는 구조.

```java
// 어드민(tocServer)에서 필터 등록 후 리로드 요청
rlodService.addFilterRlod(reloadList);

// 엔진(tocProcess)에서 SbRlodScheduler가 주기적으로 DB 폴링
List<SbRlodEngineDTO> rlodDTOList = rlodCommonService.getRlodDTOList(rlodLastUpdated);
```

---

## 주의사항

- `org.apache.james.*`, `org.apache.mailet.*` — Apache James 소스 내장. **수정 금지**
- `com.crinity.migration.*` — 마이그레이션 도구. pom.xml에 컴파일 제외 설정 있음. 일반 개발 대상 아님
- `AMQLOGService` — 전체 코드가 주석 처리됨 (ActiveMQ 미사용 상태). 활성화 전 전체 검토 필요
- tocProcess는 Spring MVC가 없으므로 `@Controller`, `@RequestMapping` 등 웹 레이어 어노테이션 사용 불가
- DB 접근은 tocFramework의 DAO를 직접 `@Autowired`하거나 `cm.repository` 레이어를 통해 수행
