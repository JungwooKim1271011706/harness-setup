---
title: codex CJK 소스 전반 mojibake 독해 불능 → 파일쓰기·문서독해 역할 배제
type: gotcha
links: [[codex-review-mojibake-line-merge]], [[codex-python-shim-windows]]
sources:
  - 발생세션 DEVUNIT-authpatch_draft WI-B 러너 clone 캐싱 (2026-07-20), codex 자기보고 반복(7b·review)
  - ~/.claude/harness-retro-inbox/20260719T161401Z__DEVUNIT-authpatch_draft.md 후보 C (inbox 드레인 2026-07-20)
updated: 2026-07-20
---

## 증상
codex가 한글 중심 프로젝트의 파일(설계 문서·rule md·소스 주석)을 **전반적으로 mojibake로 읽음**.
7b 케이스 산출서 codex 자기보고: "문서 한글이 mojibake로 깨져 보임, 프롬프트 요약에 의존".
CJK 프로젝트에서 codex의 문서 독해·파일 쓰기가 구조적으로 불가.

## 원인
Windows codex의 CJK 인코딩 처리 한계. [[codex-review-mojibake-line-merge]](인접 라인 병합
오독 → 거짓 P1)와 **다른 결함 모드** — 그쪽은 특정 렌더 아티팩트로 오독, 이쪽은 전반 독해 불능.

## 회피 (orchestrator `## codex 호출 가드` ### CJK 소스 프로젝트 제약이 규칙 SSOT)
- codex **파일 쓰기(7.5 RED 작성)·문서 독해 의존 배제** — 비평/consult(로직·계약·보안 렌즈)만 사용.
- 7.5 작성자 = tester-design(claude) 폴백 + `⚠ 교차검증 없음(codex 인코딩, 단일 소스)` 태그 + 7.7 더 엄격.
- codex review/consult 호출 시 "주석 독해 의존 금지, 코드 로직으로 판정" 주입.

## 여파
WI-B에서 7.5 작성자를 claude로 전환(한글 주석 회귀 위험 회피) + review codex에 인코딩 주의 주입 필요.
