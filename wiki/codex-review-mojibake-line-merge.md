---
title: codex 리뷰가 한글(cp949)/혼합인코딩 파일서 인접 라인 병합 오독 → 거짓 P1
type: gotcha
links: [[codex-python-shim-windows]], [[jq-korean-encoding]], [[powershell-set-content-utf8-bom]], [[codex-cjk-mojibake]]
sources:
  - inbox 20260703T022325Z / repostitch cross-branch 세션 B1 재리뷰
updated: 2026-07-03
---

## 증상
codex review(PowerShell Get-Content 경유)가 한글 주석·혼합인코딩(mojibake) 소스를 읽을 때 인접 코드 라인을 한 줄로 병합 렌더 → 정상 `if(!isRunOk(r)) return{...}`를 "주석 뒤에 붙어 실행 안 됨(주석처리)"으로 오독, 거짓 P1 blocking 생성. 출력에 `3?몄옄??` 류 mojibake 동반.

## 진짜 원인
codex Windows PowerShell Get-Content가 비-UTF8/혼합인코딩 라인 경계를 잃음. python-shim(--json broken pipe)·tmp-path와 별개 축 — 이건 렌더 단계 라인병합.

## 회피 (검증됨)
codex P1/blocking은 **항상 디스크 직접 Read로 인용라인 대조**(receiving-code-review, orchestrator.md ▸/review 실행주체 ④) — 특히 한글 주석/혼합인코딩 파일. codex 출력에 mojibake 보이면 라인병합 오독 의심. 교차증거: 해당 실패경로 변경검증이 GREEN이면 그 체크는 살아있음(codex 주장 반증). orchestrator 인용라인 미대조 시 거짓 P1이 불필요 rework 유발.

## 근거
repostitch B1 codex P1(normalizeGitlinkToBranchTip "주석처리" 주장) → 디스크 Read L845-852 별도줄 확인 + code-reviewer 무flag 3중 기각.
