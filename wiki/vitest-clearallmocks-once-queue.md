---
title: vitest clearAllMocks는 *Once 구현 큐를 안 비운다 — 미소비 큐가 다음 테스트로 누출
type: gotcha
links: [[vitest-mockresolvedvalue-microtask-flush]], [[vitest-vimock-partial-throws]]
sources:
  - sources/20260813T042455Z-repostitch-wiki-mirror-sync.md
updated: 2026-08-14
---

**증상:** 테스트를 **단독 실행하면 통과하는데 전체 실행에선 무관한 케이스가 엉뚱한 에러로 실패**한다. 실패 지점이 그 케이스의 단언이 아니라 setup·첫 호출이라 원인이 자기 파일 안에 안 보인다.

**진짜 원인:** `vi.clearAllMocks()`는 `mock.calls`(호출 기록)만 지우고 `mockRejectedValueOnce`/`mockResolvedValueOnce`로 **큐잉된 구현은 남긴다**. RED 단계처럼 구현이 미완이라 그 큐가 **자기 테스트 안에서 소비되지 않으면** 다음 테스트로 누출돼, 무관한 케이스가 남의 `Once` 값을 먹고 단언 도달 전 크래시한다.

- 실측: `E11`의 `readdir.mockRejectedValueOnce(EBUSY)`가 소비되지 않은 채 뒤의 `G-LEGACYb`(overlay 회귀 가드)를 깨뜨렸다. 같은 파일의 `cp.mockRejectedValueOnce`도 동일 위험으로 대기 중이었다.
- RED 단계에서 특히 잘 터진다 — 구현이 없어 큐를 소비할 코드 경로가 아직 없기 때문이다.

**회피:**
- `beforeEach`에서 공용 mock을 **`mockReset()` + base 구현 재설정**으로 통일한다(`clearAllMocks`로는 부족).
- `*Once`를 쓰는 케이스는 **그 케이스 안에서 반드시 소비**되는지 확인한다. 소비 안 될 수 있으면 `Once` 대신 케이스 로컬 `mockImplementation` + 복원.

**판별 신호:** "단독 실행 통과 / 전체 실행에서 무관한 에러로 실패". 이 조합이면 mock 큐 누출을 1순위로 의심한다(`vi.doMock` 모듈 상태·DOM 잔존과 같은 cross-test 누출 계열).
