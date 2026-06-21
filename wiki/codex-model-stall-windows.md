---
title: codex 모델 stall — smoke ping은 통과하나 실프롬프트가 hang (probe false-positive)
type: gotcha
links: [[codex-python-shim-windows]] [[codex-tmp-windows-path]]
updated: 2026-06-22
---

## 증상
orchestrator 세션 1회 codex probe(`codex exec "ping" -s read-only < /dev/null`)가 exit0를 빠르게 반환 → "codex 가용" 판정. 그러나 실제 substantive 프롬프트(TDD 7b consult, /codex review)는 **2회 모두 exit124(timeout)** — `< /dev/null` 정상 호출형 + valid 버전(0.139.0) + 파일읽기 0 + 5분 상한에도 hang. 결과: 7b 교차검증 상실, 7.5 RED를 tester-design 단일소스로, /codex review 미가용 → TDD+리뷰 전체가 단일소스 격하. probe가 hang을 못 예측해 실호출 2회 타임아웃 대기로 ~20분 낭비.

## 진짜 원인
초소형 smoke(`ping`)는 모델이 즉답하나, 이 PC codex는 **수백토큰 추론 프롬프트에서 모델 API가 stall**한다(네트워크/계정/모델 라우팅 추정 — 호출형·버전·파일읽기 문제 아님). smoke 크기와 실프롬프트 크기의 거동 차이 = probe가 가용성을 잘못 보고. 기존 [[codex-python-shim-windows]](--json 파서가 Windows Store python shim 골라 broken pipe)와는 **별개 원인**(그건 파이프, 이건 모델 stall).

## 회피 (probe 강화)
probe를 실제 거동에 가깝게 만들어 hang을 **probe 단계서** 조기 발각한다.
- smoke를 초소형 `ping`이 아니라 **대표 크기 프롬프트(수백토큰 추론 1개)**로 + **짧은 하드 타임아웃**(`timeout 60 codex exec "..." -s read-only < /dev/null`).
- **probe 타임아웃(exit124) = codex 불가**로 간주 → 즉시 단일소스 폴백. smoke exit0만으로 가용 단정 금지.
- 효과: stall PC에서 실호출 2회(~20분) 낭비 대신 probe 60s에 발각.
- 폴백 후 거동은 기존 `## codex 호출 가드` 폴백 라우팅 그대로(7b·7.5→tester-design 단일소스+태그, /codex review→code-reviewer 단독+코드대조).

## 하네스 적용
- `agents/orchestrator.md ## codex 호출 가드` → `### 가용성 확정` — probe를 대표프롬프트+60s 타임아웃으로 강화, probe 타임아웃=불가.
- 근원: authpatch_draft 삭제 라이프사이클 통합 세션(2026-06-22) `/harness-check` 자동드롭. 7b 2회 exit124, smoke exit0. 가드의 재시도상한·폴백은 작동했으나 **probe 신뢰성**이 구멍이었음.
- 학습기반 probe 스킵(만성 hang 기억 시 probe 생략)은 false-skip(codex 회복 시 비상관 소스 영구 상실) 위험으로 미채택 — 강화된 probe가 매 세션 1회 판정.
