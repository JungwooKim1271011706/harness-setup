---
source_session: DEVUNIT-authpatch_draft / feature-dashboard-commitlog-2 (커밋 상세 패널 신규기능)
project: DEVUNIT-authpatch_draft
date: 2026-07-24
signal: 과다 루프 (spec-only 리뷰-fix 3라운드)
priority: medium
---

# 회고 후보: VTU `<Teleport>` 컴포넌트 spec 작성 3라운드 (ETD-02)

## 증상 (무엇이 얼마나 비효율적이었나)
커밋 상세 패널 TDD 중, `<Teleport to="body">`를 쓰는 컴포넌트(ExportTriggerModal detail 흐름)의 RED spec `ETD-02`가 **3라운드**(attempt1→2→3) 재작업 끝에 GREEN. teleport 노드가 마운트 서브트리 밖(`document.body`)으로 옮겨져 VTU `wrapper.find()`/`findAll()`이 못 찾고, `global.stubs.teleport:true`를 쓰면 제자리 렌더라 remount/재열림 아티팩트로 단언이 흔들렸다. 최종 해법 = 네이티브 DOM(`document.body.querySelectorAll` + `dispatchEvent`, teleport stub 제거).

## 추정 원인
tester-design/RED-author가 `<Teleport>` 컴포넌트의 VTU 테스트 관용구(stub 제자리 렌더 함정 ↔ 네이티브 DOM 탐색 트레이드오프)를 **선제 인지하지 못해**, 시행착오로 3라운드 소비. 하네스가 이 함정을 사전 주입할 지점(tester-design 프롬프트 / frontend.md rule / wiki gotcha)이 비어 있었다.

## 제안 개선 방향 (라우팅은 harness-retro가 결정)
- **1순위(wiki)**: `wiki/`에 "VTU Teleport 컴포넌트 spec — stub 제자리렌더 함정과 네이티브 DOM 탐색" gotcha 페이지 신설. checkpoint가 이미 wiki capture 후보로 flag함. 디버깅·테스트 작업 전 Grep으로 재사용되게.
- **2순위(rule)**: `rules/package/autopatch/frontend.md`에 Teleport spec 작성 관용구 1항 추가(이 저장소 teleport 컴포넌트 spec은 전부 `global.stubs.teleport:true`를 쓰는데 그 경우 DOM 위치 불변이라 클리핑/remount류 검증 불가 — 실제 리페어런팅 검증엔 네이티브 DOM 필요).
- **하네스 규칙(agents/*.md) 변경은 아마 불요** — 프로젝트/스택 국한 지식(Vue+VTU)이라 wiki/rule이 맞는 자리. harness-retro가 최종 분류.

## 근거 (이번 실행 인용)
- checkpoint `20260724-220218-...postreview-designpolish-finalizer-next.md` line 23(ETD-02 attempt3 최종: 네이티브 DOM, teleport stub 제거) + line 48(하네스 운영고통 신호로 명시).
- 관련 rule 기존 항목: frontend.md "overflow-x:auto 컨테이너 안의 절대배치 드롭다운 클리핑 — Teleport보다 재배치 우선"(VTU find가 teleport 노드 못 찾는 함정 이미 부분 문서화 — 이 후보는 spec **작성 관용구** 측면으로 보완).

## 관련 파일
- `autopatch-dashboard/src/components/project/ExportTriggerModal.spec.ts` (ETD-02)
- `rules/package/autopatch/frontend.md`
- `wiki/index.md` (신설 페이지 등록처)
