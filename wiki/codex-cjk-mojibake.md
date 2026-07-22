---
title: codex CJK 소스 전반 mojibake 독해 불능 → 파일쓰기·문서독해 역할 배제
type: gotcha
links: [[codex-review-mojibake-line-merge]], [[codex-python-shim-windows]]
sources:
  - 발생세션 DEVUNIT-authpatch_draft WI-B 러너 clone 캐싱 (2026-07-20), codex 자기보고 반복(7b·review)
  - ~/.claude/harness-retro-inbox/20260719T161401Z__DEVUNIT-authpatch_draft.md 후보 C (inbox 드레인 2026-07-20)
  - 발생세션 DEVUNIT-authpatch_draft CI joblog (2026-07-21) — 7.7 codex critical 4건 전건 거짓양성, od -c로 기각
  - ~/.claude/harness-retro-inbox/20260721T234147Z__DEVUNIT-authpatch_draft.md 후보 A (inbox 드레인 2026-07-22)
updated: 2026-07-22
---

## 증상
codex가 한글 중심 프로젝트의 파일(설계 문서·rule md·소스 주석)을 **전반적으로 mojibake로 읽음**.
7b 케이스 산출서 codex 자기보고: "문서 한글이 mojibake로 깨져 보임, 프롬프트 요약에 의존".
CJK 프로젝트에서 codex의 문서 독해·파일 쓰기가 구조적으로 불가.

## 원인
Windows codex의 CJK 인코딩 처리 한계. [[codex-review-mojibake-line-merge]](인접 라인 병합
오독 → 거짓 P1)와 **다른 결함 모드** — 그쪽은 특정 렌더 아티팩트로 오독, 이쪽은 전반 독해 불능.

## 증상 2 — 거짓 critical 클래스 (2026-07-21 추가)
소스 직독(7.7 교차판정·review)에서 codex가 **"구문오류/미종료 문자열 리터럴/주석처리된 단언" 계열 critical을 양산** — 인용 quote에 mojibake(`痍⑥냼??`=취소됨) 동반. 원본은 정상(od -c: 주석 마커 `//`=0x2F2F, 문자열 정상 종료; vitest 43테스트 정상 파싱). codex 입력단(git diff/PowerShell 뷰어)이 UTF-8을 CP949로 오해석 → 멀티바이트 경계 깨짐. Read 코드대조로도 판정 애매(Read 렌더 아티팩트 ↔ codex 표기 불일치)해 재검증 1라운드 소요.

## 회피 (orchestrator `## codex 호출 가드` ### CJK 소스 프로젝트 제약이 규칙 SSOT)
- codex **파일 쓰기(7.5 RED 작성)·문서 독해 의존 배제** — 비평/consult(로직·계약·보안 렌즈)만 사용.
- 7.5 작성자 = tester-design(claude) 폴백 + `⚠ 교차검증 없음(codex 인코딩, 단일 소스)` 태그 + 7.7 더 엄격.
- codex review/consult 호출 시 "주석 독해 의존 금지, 코드 로직으로 판정" + "원본 UTF-8로 읽어라(git diff/Get-Content 금지)" 주입.
- **거짓 critical 판정 ground-truth**: "구문오류/미종료 리터럴/주석처리" 계열은 `od -c` 바이트검사 + vitest/mvn 재파싱으로만 기각/확정(quote mojibake = 거짓양성 신호).

## 여파
WI-B에서 7.5 작성자를 claude로 전환(한글 주석 회귀 위험 회피) + review codex에 인코딩 주의 주입 필요.
