---
title: 경로 부분문자열 매칭 mock이 과잉 적중 — 구현을 완화하면 조용한 under-deletion
type: gotcha
links: [[vitest-clearallmocks-once-queue]], [[gates-verify-present-code-only]]
sources:
  - sources/20260813T042455Z-repostitch-wiki-mirror-sync.md
updated: 2026-08-14
---

**증상:** 특정 단계 하나의 실패만 노린 mock이 **훨씬 앞 단계까지 실패**시킨다. developer가 "테스트가 요구하니" 설계 원안을 완화해 통과시키고, 결과는 겉보기 GREEN인데 **파괴적 연산이 조용히 덜 일어난다**.

**진짜 원인:** 경로를 **부분문자열(`includes`)로 매칭**하는 mock은 의도한 그 경로만이 아니라 **그 문자열을 포함하는 모든 경로**에 걸린다. 특히 다른 mock(`mkdtemp` 등)이 **디렉터리명 자체에 그 토큰을 박으면** 하위 전 경로가 매칭된다.

- 실측: `fsPromises.rm.mockImplementation(p => { if (String(p).includes('wiki-tmp')) throw ... })`가 "push 이후 tmp 정리 실패"만 노린 목이었는데, `mkdtemp` 목이 디렉터리명에 `wiki-tmp`를 넣어 **워킹트리 비우기(`_clearWorkTree`)까지** 실패했다.
- 그 통과를 위해 fail-closed 원안이 best-effort로 완화됐고 → **삭제 미전파 미러**가 됐다: 안 지워진 파일을 `git add -A`가 "변경 없음"으로 보고하고, 백업 게이트의 삭제 집계마저 줄어 **백업조차 안 걸렸다**.

**회피:**
- 목을 **정확 매칭으로 좁힌다**: `/wiki-tmp-\d+$/` 처럼 tmp 루트만 앵커. `includes`는 마지막 수단.
- **테스트가 아프면 구현을 완화하지 말고 목을 좁힌다.** 원안(fail-closed) 복원 + 하드게이트를 잠그는 RED를 따로 신설한다.
- 일반화: **파괴적 연산에서 "정리 실패를 삼킨다"는 완화는 조용한 under-deletion을 만든다.** 실패를 삼키면 그 뒤의 집계·백업 게이트까지 동시에 눈이 먼다.

**교훈:** mock 과잉적중은 "테스트가 까다롭다"로 읽히지만 실제로는 **테스트가 옳고 목이 틀린** 경우가 많다. 완화 방향 수정은 설계 반전이므로 orchestrator 판정 대상이다.
