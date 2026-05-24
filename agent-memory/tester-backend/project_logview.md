---
name: LogView 신규 모듈 코드 품질 이슈
description: scourttemp/logview 신규 모듈의 패키지 구조·DI 패턴·보안 검증 미비 항목
type: project
---

`tocServer/src/main/java/webapps/scourttemp/logview/` 신규 모듈에서 확인된 이슈.

**Why:** tocServer 백엔드 규칙(com.crinity.sb.webapps.* 패키지, @Autowired 필드 주입)을 따르지 않음.

**How to apply:** developer-backend 반환 시 아래 항목 명시.
1. 패키지 선언이 `webapps.scourttemp.logview.*`로 com.crinity.sb 접두사 없음 → AuditAdvice AOP pointcut(`execution(* com.crinity.sb.webapps..*(..))`) 적용 불가
2. 생성자 주입 사용 — 기존 프로젝트 표준은 `@Autowired` 필드 주입
3. 인증/권한 검사 없음 — LoginCheckInterceptor 외 별도 권한 레벨 체크 없음
4. 테스트 없음 — path traversal, 허용 확장자 외 입력, offset 음수 등 보안/경계값 테스트 부재
