---
title: 공유 테스트 DB는 워크트리 분리로 안 풀린다 — @ResourceLock은 프로세스 간 무효
type: gotcha
links: [[vitest-real-process-spawn-crash]], [[surefire-runaway-test-timeout]]
sources:
  - sources/20260814T060000Z-authpatch-path-mapping-8a8b-fullcycle.md
updated: 2026-08-14
---

**증상:** 테스트를 병렬로 돌리면 `DuplicateKeyException`·MockMvc 빈 누락 등 **산발적이고 재현이 불안정한** DB 오염이 난다. 단독 실행에선 안 난다.

**진짜 원인:** JUnit5 `@ResourceLock`·`SAME_THREAD`는 **한 JVM 안의 스레드 조정 장치**다. mvn 프로세스를 2개 띄우면 **프로세스 간에는 아무 효력이 없다**. 테스트 DB가 하나뿐이면 두 프로세스가 같은 테이블을 동시에 쓴다.

**회피:**
- **순차 실행만이 답이다.** 같은 모듈·같은 DB를 쓰는 테스트 배치는 병렬 발사하지 않는다.
- ⚠ **워크트리 분리로도 안 풀린다.** 워크트리는 파일시스템만 나눈다 — DB는 여전히 하나다. 빌드 산출 디렉터리(`target/`) 경합에는 워크트리가 답이 되지만 **공유 DB에는 무효**다.
- 판정 순서: 병렬 발사 전 자가체크에서 자원 축을 볼 때 **"공유 DB인가"를 `target/`·포트·락파일보다 위에** 둔다(해법이 더 좁기 때문).

**교훈:** 자원 경합은 층이 있다 — 파일(워크트리로 해결) < 빌드 산출(워크트리로 해결) < **공유 상태 저장소(해결 불가, 순차만)**. `orchestrator.md ## 핵심 규칙`의 자원 경합 축이 이 페이지를 가리킨다.
