---
title: 실 프로세스 대량 spawn 통합테스트가 vitest 전체 동시실행서 크래시 (STATUS_DLL_INIT_FAILED)
type: gotcha
links: [[surefire-runaway-test-timeout]], [[shared-test-db-worktree-noop]]
sources:
  - sources/20260813T042455Z-repostitch-wiki-mirror-sync.md
updated: 2026-08-14
---

**증상:** 특정 통합테스트 파일이 **standalone은 전건 PASS**인데 **전체 실행에선 무더기 크래시**한다. Windows에서 `STATUS_DLL_INIT_FAILED (0xC0000142)`로 뜬다. 회귀로 오독하기 쉽다.

**진짜 원인:** 실 `git.exe` 같은 **외부 프로세스를 대량 spawn**하는 테스트가 vitest 병렬 워커와 겹치면 OS 자원(프로세스·DLL 로더) 한계에 걸린다. **코드 회귀가 아니라 부하**다.

- 실측: `migrate-builder-diskintegration.test.js` 53케이스가 전체 548초 중 **533초**를 먹었고, 전체 동시실행에선 **16건 크래시**. standalone은 53/53 PASS.

**회피:**
- 개발 루프: `--exclude '**/migrate-builder-diskintegration.test.js'` 로 빼면 **548s → 32s**.
- ⚠ **전체회귀 때는 그 파일을 별도 순차·격리 실행**해야 커버리지가 안 빈다. 제외한 사실은 **항상 명시 기록**한다 — 조용히 빼면 "전량 통과"로 읽히는 무음 부분실행이 된다.

**교훈:** "standalone PASS / 전체 FAIL"은 회귀 신호가 아니라 **자원 경합 신호**다. 같은 축의 다른 형태로 공유 실DB([[shared-test-db-worktree-noop]])·빌드 산출 디렉터리가 있다.
