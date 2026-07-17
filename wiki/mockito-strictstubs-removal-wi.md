---
title: removal-WI가 STRICT_STUBS 테스트를 조용히 깬다 + 부재-테스트 sentinel-stub 덫
type: gotcha
links: [[surefire-nested-skip]], [[spring-componentscan-basepackages-root-omission]]
sources:
  - 발생세션: autopatch-dashboard-export-4 (workspacePath 웹 제거 WI-A, 2026-07-16)
  - docs/features/2026-07-16-workspacepath-web-removal.md (WI-A, 흐름 4 + 6-a)
  - inbox: ~/.claude/harness-retro-inbox/20260716T035500Z__DEVUNIT-strictstubs-removal-wi.md
updated: 2026-07-16
---

**증상:** "필드/응답값 제거" 같은 순수 제거 WI에서 프로덕션 **메서드 호출 라인**을 지웠더니, 그 메서드를 `when(...).thenReturn(...)`으로 stub해둔 **기존 테스트**가 `org.mockito.exceptions.misusing.UnnecessaryStubbingException`으로 죽는다. 컴파일·타입은 멀쩡, full test 돌려야만 드러남.

**진짜 원인:** `@ExtendWith(MockitoExtension.class)`는 기본 `Strictness.STRICT_STUBS`. 호출 라인을 제거하면 그 stub이 unnecessary가 되고 STRICT_STUBS가 예외로 던진다(안 타는 stub = 테스트가 거짓말한다는 신호라 Mockito가 막음).
→ **흐름4(호출 제거)와 그 stub 제거(6-a)를 반드시 같은 커밋에 묶어야 한다.** 분리 커밋하면 중간 커밋이 RED(그 시점 checkout/bisect가 깨진 빌드를 밟음).

**파생 덫 — "필드 부재" 테스트에 sentinel-stub 쓰지 마라:** "응답 JSON에 키가 없다"를 RED로 잠글 때 `getWorkspacePath()`를 non-null sentinel로 stub해서 "구버전이 확실히 키를 만들게" 하고 싶어진다. **그게 같은 덫이다** — 변경 후엔 그 호출이 사라져 sentinel stub 자신이 UnnecessaryStubbing이 되어 GREEN 단계에서 죽는다.

**회피:** stub 없이 직렬화 기본동작을 이용한다. DTO에 `@JsonInclude` 부재를 확인 → mock 기본 null 반환 → `dto.setWorkspacePath(null)` → Jackson이 `"workspacePath":null` 키를 직렬화 → `writeValueAsString(dto)` + `assertThat(json).doesNotContain("workspacePath")`가 현재 상태에서 진짜 FAIL(RED 성립). 필드 되살아나면 값이 null이어도 키가 나오므로 반드시 재-FAIL(공허단언 아님). positive 짝(다른 키 존재)을 붙여 "빈 JSON이라 공허 통과"도 차단.

**교훈:** removal-WI에서 "호출 제거 + 그 호출을 stub/검증한 테스트 정리"는 **한 단위(한 커밋)**. 부재 검증 시 제거 대상 호출을 stub하지 말고 직렬화 기본동작(@JsonInclude 부재)을 이용한다.
