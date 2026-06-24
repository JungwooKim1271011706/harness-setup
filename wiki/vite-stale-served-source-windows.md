---
title: Vite dev server가 stale transform 서빙 (Windows 워처 miss) — 디스크≠서빙
type: gotcha
links: [[vue-immediate-watch-template-ref]] [[gstack-install-windows]]
sources:
  - ~/.claude/harness-retro-inbox/20260622T070635Z__DEVUNIT-authpatch_draft__wiki-vite-stale-served.md
  - 발생세션 bugfix-autopatch-dashboard (:5173 미반영 → :5191 별도 기동 실측)
updated: 2026-06-24
---

## 증상
소스 수정 + 하드 리로드(Ctrl+Shift+R)했는데도 브라우저에 옛 동작. 디스크 파일엔 수정이 있는데 화면은 그대로. HMR도 안 탐.

## 진짜 원인
Windows에서 Vite dev server 파일 워처가 편집을 놓쳐 **변환 캐시가 stale**한 채 옛 모듈을 서빙. 디스크(`grep` 파일)는 새 코드인데 서버가 주는 모듈은 옛 코드. **디스크 ≠ 서버가 실제로 주는 소스.**

## 회피 (검증 절차)
실행 중 dev server로 수정을 검증할 때는 **디스크만 믿지 말고 "서버가 실제로 주는 소스"를 확인**:
```
curl -s "http://localhost:5173/src/path/Component.vue" | grep -n "내가_넣은_심볼"
```
디스크엔 있는데 서빙엔 없으면 = stale. 해결: dev server **재시작**(또는 별도 포트로 새 인스턴스 기동해 검증). 쿠키는 host 기반이라 다른 포트에도 적용됨(세션 재로그인 불요).

## 관련
- 브라우저 실측 검증 일반(browse 스킬 + canvas client 크기 대조) — tester-frontend 렌더검증서 이 함정에 막히면 stale 의심.
- 조용한 렌더 실패의 다른 원인: [[vue-immediate-watch-template-ref]].
