---
title: agent frontmatter tools 선언은 무음 드롭된다 — 플러그인 도구는 서브에이전트에 안 붙는다
type: gotcha
links: [[gates-verify-present-code-only]], [[agent-memory-overrides-rule]], [[claude-model-override-silent-downgrade]]
sources:
  - 발생세션: harness-setup dev clone LSP 권한 검토 (2026-08-18) — 프로브 에이전트 2회 + 소비자 세션 교차
  - 커밋: v5.4.2 (orchestrator tools에 LSP 단독 선언 실험)
updated: 2026-08-18
---

**증상:** 에이전트 md frontmatter `tools:`에 도구를 적었는데 **그 에이전트가 실제로는 못 쓴다.** 에러도 경고도 없다. 서브에이전트는 조용히 다른 수단(grep 등)으로 폴백하고, 위임한 쪽은 도구를 준 줄 안다.

**실측 (프로브 2회):**

| 무엇 | 결과 |
|---|---|
| `tools: [Read, LSP, ThisToolDoesNotExist_XYZ]`로 에이전트 등록 | **로드 통과**. 에이전트 수 `10 → 11` |
| 레지스트리 표기 | `(Tools: Read, LSP, ThisToolDoesNotExist_XYZ)` — **선언 그대로 보인다** |
| 그 에이전트를 스폰해 실제 도구 조회 | **`Read` 하나.** LSP도 가짜 도구도 사라짐 |
| 스폰 자체 | **정상 완주**(2.7s). 미지 도구가 있어도 안 깨진다 |
| 교란 제거(`tools: [Read, LSP]`만) 재측정 | 동일 — `TOOL_ABSENT` |

**핵심 비대칭 (같은 세션 안에서 갈린다):**

| 실행 주체 | 플러그인/deferred 도구 |
|---|---|
| **메인 스레드** (`settings.json`의 `"agent": <name>` 모드 포함) | **붙는다** — 단 agent 모드면 `tools:`에 **이름을 명시**해야 한다 |
| **서브에이전트** (`Agent` 도구로 스폰) | **안 붙는다** — 이름을 명시해도 드롭 |

- 메인 축 증거: orchestrator `tools:`에 `LSP` 한 줄을 추가하자 그 세션에서 LSP 호출이 **도구 부재가 아니라 서버 초기화 타임아웃**(`LSP server 'plugin:jdtls-lsp:jdtls' timed out ...`)으로 실패했다. 도구가 없으면 그 에러 문자열 자체를 못 받는다 = 부착 증명.
- ⚠ **`ToolSearch`를 주면 deferred 도구 전체가 열린다**(`WebFetch`·Cron 계열·MCP 도구 포함). 특정 도구 하나만 필요하면 **이름 단독 선언**으로 족하다 — 경계를 안 허물고 얻는다.

**회피:**
- **도구 권한을 줬다고 가정한 규칙을 쓰기 전에 실제 호출로 확인한다.** 레지스트리 표기·선언 존재는 근거가 아니다.
- 서브에이전트에 플러그인 도구가 필요하면 **구조를 바꾼다**: 메인(orchestrator)이 조회하고 **결과를 위임 컨텍스트에 주입**한다. 조회 주체를 서브에이전트로 두는 설계는 성립하지 않는다.
- `tools:` 키를 통째로 빼면 전 도구 상속이라 붙을 수 있으나(미검증), **`developer-frontend` Bash 부재·`tester-design` 실행 불가 같은 경계가 무너진다** — 작성자≠검증자 불변식과 맞바꾸는 거래라 채택 금지.

**교훈:** 이건 [[gates-verify-present-code-only]] 클래스다 — **부재가 통과처럼 보인다.** 선언은 보이는데 능력은 없고 아무도 안 짖는다. 같은 뿌리의 선례: 모델 핀이 요청일 뿐 보장이 아니었던 [[claude-model-override-silent-downgrade]], 자기보고가 실제와 갈렸던 [[agent-memory-overrides-rule]]. **런타임 능력은 선언이 아니라 실행으로 확인한다.**
