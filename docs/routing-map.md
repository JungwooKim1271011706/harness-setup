# Routing Map — gstack 스킬 라우팅 흐름도

> **분리 문서** — `orchestrator.md`의 `## gstack 스킬 라우팅` ASCII 다이어그램을 추출(v3.2.0). 한눈에 보는 시각 자료 — 매 턴 필요하지 않아 분리. 라우팅 표(스킬↔조건)는 orchestrator.md에 인라인 유지. 흐름 시각화가 필요할 때 Read.
> **버전 동기 대상**: orchestrator 3트랙·게이트·TDD·FAIL 분기 변경 시 이 다이어그램도 갱신한다. finalizer bump 의식의 "분리 문서 정합성 점검"이 강제.

---

```
[사용자 요청]
      │
      ▼
 ┌─────────────────────────────────────────────────────┐
 │  0단계: 진입 분기                                    │
 │  ① 복잡도 판정  ② 보안 2차 스캔  ③ 모듈·rule 확정   │
 │  ④ 데이터 전제 검증(외부·런타임 데이터 의존 픽스 —   │
 │     진입 전 실 샘플 ≥1 inspect / 불가시 ⚠미검증전제) │
 └──────────────┬──────────────────────────────────────┘
                │
    ┌───────────┼────────────────┐
    ▼           ▼                ▼
[단순수정]   [신규기능]      [고복잡도]
    │        (보안 포함)          │
    │           │        planner-high-complexity
    │  [선제 게이트: docs/features 승인문서 확인          │
    │   → 있으면 재office-hours 금지·SSOT 재개]           │
    │    /office-hours           │
    │    /grill-with-docs        │
    │    /co-plan(OOP5)          │ (신규기능 트랙 합류 →)
    │           │           설계패널게이트 3~4 (eng 다라운드)
    │      planner-*             │
    │           │                │
    │    ┌──────────────────────────────────┐
    │    │  설계패널게이트 (3~4, 병렬 호출)   │
    │    │  eng + cso/design/devex(태그)      │
    │    │  ∥ codex 형제(consult, cross-model)│
    │    │  → 합집합 dedup+코드대조 게이트     │
    │    │  PASS=확인근거 명시 필수(빈약시 재검토1회)│
    │    │  critical 있으면 planner 재작업     │
    │    │  루프 최대 3회, 초과→사용자 에스컬레이션│
    │    └────────────┬─────────────────────┘
    │                 │
    │      [디자인 목업 게이트] UI태그+신규화면 시
    │      /design-shotgun → /design-html
    │      (목업=승인 아티팩트, 산출물 아님)
    │                 │
    │          [사용자 승인]
    │                 │
    │    ┌────────────▼─────────────────────┐
    │    │  TDD 합의 (신규기능·고복잡도 전용)  │
    │    │  7a tester-design ∥ 7b codex      │
    │    │         ↓ 7c diff 합의             │
    │    │  7.5 codex RED 테스트 작성         │
    │    │  7.6 RED sanity(컴파일+RED실행)    │
    │    │  7.7 tester-quality(품질게이트)    │
    │    │  critical 0+근거 → 8              │
    │    │  아니면 작성자반환 [LOOP n/3]      │
    │    └────────────┬─────────────────────┘
    │                 │
 7s.tester-design   ▼
 (경량: 버그재현   developer-* (8: GREEN 구현)
  테스트 1개,
  codex합의·저자
  스킵)
      │
      ▼
 developer-*
      │
      ▼
 tester-backend ∥ tester-frontend
      │
      ├── PASS → [design-reviewer: 목업 게이트 발동 시만, report-only→developer]
      │               │
      │    /verify-implementation (verify-* 등록 시)
      │               │
      │    /review(code-reviewer) ∥ /codex review (병렬, 필수)
      │               │
      │    /cso (인증/권한/암호화 변경 시 필수)
      │               │
      │    워크스루·인출 (6단계: 브리핑1~4 → Q&A → 인출.
      │     인출 완료=finalizer 트리거. 단순수정 생략 가능)
      │               │
      │           finalizer
      │
      └── FAIL → /investigate
                     │
           ┌─────────┼──────────────┐
           ▼         ▼              ▼
       [구현결함]  [설계결함]    [환경문제]
     learning-gate  planner 재호출  사용자 가이드
     developer 재수정 설계패널 재게이트 tester-runtime 재실행
     [LOOP n/3]   사용자 재승인
```
