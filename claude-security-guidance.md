# 프로젝트 보안 가이드 (security SSOT)

scourt_spambreaker(Spring MVC + MyBatis + JSP 메일 스팸차단 어드민)의 **프로젝트별 보안룰**.
계획·코드 양 스테이지가 공유하는 단일 보안기준(SSOT).

**용처:**
- 설계패널 cso 렌즈(design-panel.js `CSO_LENS`)가 이 파일을 Read해 **계획 비평** 기준으로 사용 (제너릭 OWASP→프로젝트인지).
- `/cso`, `/review` 가 코드 리뷰 시 참조.

**근거:** 카테고리는 security-guidance 공식 플러그인(injection/역직렬화/unsafe DOM) + OWASP/STRIDE.
체크는 `.claude/rules/package/tocServer/backend.md` 보안 섹션과 실제 코드 패턴에서 도출.

> ⚠ 이 문서는 **정적 룰**이다. 자동수정 런타임(security-guidance 플러그인)은 도입하지 않았다
> (자동수정이 거버넌스 '코드 자동수정 금지'와 충돌, no-fix 모드 부재 — 백로그 #7 참조).

---

## 1. SQL Injection (MyBatis)

- MyBatis 매퍼에서 **`${}`(문자열 치환) 금지, `#{}`(바인딩) 사용**. `${}`는 ORDER BY 컬럼명 등 불가피한 경우만, 화이트리스트 검증 후.
- `sqlSession.selectList/insert/update`에 들어가는 파라미터(Form/HashMap)는 사용자 입력 → 동적 SQL 조립 시 바인딩 확인.
- 검색·필터 조건(LIKE, IN clause)에 사용자 입력이 raw concat 되지 않는지.
- **계획 점검**: 신규 쿼리/매퍼가 사용자 입력을 받으면 바인딩 방식 명시됐나?

## 2. 인증 / 인가

- 모든 컨트롤러 진입점은 `LoginCheckInterceptor`(세션+IP 사전검증)를 거치는 경로인가. 인터셉터 제외 URL 추가 시 의도 확인.
- 권한 분기: `sessionManager.getSbLoginUser(session)` → `UserLevel`(SUPERADMIN=4/DOMAINADMIN/USER) 체크. **권한 상승 경로** 없나(레벨 검증 누락, 클라이언트 전달 레벨 신뢰 금지).
- 도메인관리자가 타 도메인 데이터 접근 못 하게 — 조회/수정 시 소유 도메인 스코프 검증.
- IP 접근제어: `accessChecker.isAccessibleIP(remoteIp)` 우회 경로 없나.
- **계획 점검**: 신규 기능이 권한 체크 위치를 명시했나? 누가 호출 가능한가?

## 3. 입력 검증

- 프레임워크 `@Valid` 미사용 → **직접 검증 필수**: `StringUtils.isEmpty()`, `CollectionUtils.isEmpty()`, 범위/형식 체크.
- Form 바인딩 객체의 모든 사용자 필드는 사용 전 검증. early-return 패턴.
- 숫자/페이지/seq 파라미터 음수·과대값 가드.
- **계획 점검**: 사용자 입력 진입점마다 검증 계획 있나?

## 4. 역직렬화 (Unsafe Deserialization)

- `ObjectMapper`/Gson 역직렬화 대상이 **신뢰 경계 밖 데이터**인지 확인.
- ⚠ **알려진 위험 패턴**: `mapper.readValue(url, SomeForm.class)` — URL/외부소스에서 직접 역직렬화는 SSRF + 신뢰경계 위반. URL이 사용자 영향 받으면 금지·검증.
- `FAIL_ON_UNKNOWN_PROPERTIES=false`는 편의지만, 다형성 역직렬화(타입 정보 포함)는 가젯체인 위험 — 사용 금지.
- Gson `fromJson`(예: `mailLog.getPattern_multi()`) 입력 출처 확인.

## 5. XSS / Unsafe DOM (JSP + JS)

- JSP 출력: 사용자/DB 데이터를 화면에 낼 때 **이스케이프**. raw `${...}`로 HTML 컨텍스트에 직접 출력 시 XSS — `<c:out>` 또는 `fn:escapeXml` 사용.
- JavaScript: 서버 데이터를 `innerHTML`/`document.write`로 주입 금지. 텍스트는 `textContent`.
- `<script>` 블록에 서버 값 인라인 시 JS 문자열 이스케이프(`</script>` breakout, 따옴표).
- `data-*` 속성 값에 사용자 데이터 넣을 때 속성 이스케이프.
- **계획 점검**: 신규 화면이 사용자/외부 데이터를 표시하나? 이스케이프 명시?

## 6. 파일 업로드 / 다운로드 / 경로조작

- 업로드 파일명·경로에 `../` 경로조작 차단. 저장 경로는 화이트리스트 기준 디렉터리 하위로 강제.
- 다운로드/첨부(`POIUtil`, `FileExportUtil`, `MailViewUtil`) 시 사용자 지정 경로를 파일시스템에 직접 매핑 금지.
- 확장자·MIME 검증, 실행파일 업로드 차단.
- **계획 점검**: 파일 I/O가 사용자 입력 경로/이름을 쓰나?

## 7. 감사 로깅 (Audit)

- 민감 동작(생성/수정/삭제, 권한변경, 메일복구/삭제)에 `@Audit(actionType=…)` 선언됐나.
- `@Audit` 대상 메서드 **첫 파라미터 = `HttpServletRequest`** (AOP pointcut 조건). 누락 시 감사 미수집.
- `req.setAttribute(WebConstant.actionResult, …)`로 성공/실패 기록.
- **계획 점검**: 신규 민감동작에 감사 계획 있나?

## 8. 비밀 / 자격증명

- 코드·로그·WI·커밋에 평문 자격증명(DB PW, SFTP, API키) 금지. 런타임 conf(`WEB-INF/conf/*`)로 분리.
- 로그에 세션ID·비밀번호·개인정보 출력 금지. `LogMessage` 패턴 준수하되 민감값 마스킹.
- 예외 메시지·스택트레이스를 사용자 응답에 그대로 노출 금지.

## 9. 신뢰 경계 (STRIDE)

- 계획/코드가 trust boundary(클라이언트→서버, 어드민→엔진 rlod, 외부 메일소스)를 넘을 때 경계마다 재검증.
- tocProcess(엔진) ↔ tocServer(어드민)는 DB/rlod 폴링 경유 — rlod로 전달되는 설정값 검증.
- Spoofing/Tampering/Repudiation/Info-disclosure/DoS/Elevation 매핑.

---

## 심각도 기준 (cso 렌즈용)

- **critical**: 설계결함 수준 보안 누락(인증 우회, injection 표면 노출, 평문 자격증명, URL 역직렬화). 게이트 차단감.
- **major**: 강화 권고(검증 보강, 이스케이프 누락 가능성, 감사 누락). 통과허용·노출.
- **minor**: 방어적 개선 제안.
