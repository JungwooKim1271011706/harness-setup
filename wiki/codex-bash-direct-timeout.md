---
title: codex를 Bash로 직접 호출 시 Bash timeout param을 codex 하드타임아웃에 맞춰라
type: gotcha
links: [[codex-model-stall-windows]], [[codex-python-shim-windows]]
sources:
  - 발견 세션 2026-07-01 DEVUNIT-repostitch (설계패널 codex 형제 / 7b / review)
  - 2026-07-05 DEVUNIT-authpatch_draft (dry-commands jar source TDD 7.5 workspace-write 오펀)
  - 2026-07-08 autopatch-dashboard-export-1 (Part A MavenBuilder TDD 7.5 — exit143 vs 124 판별)
updated: 2026-07-08
---

## 증상
orchestrator가 codex를 `/codex` 스킬을 거치지 않고 **Bash 도구로 직접** 호출할 때(가용성 probe·설계패널 codex 형제·7b 케이스산출·/codex review), 명령이 `exit 143`(SIGTERM)으로 끊기고 `Command timed out after 2m 0s`가 뜬다. codex 자체는 정상이고 아직 추론 중이었다.

## 진짜 원인
**Bash 도구의 기본 timeout = 120000ms(2분).** codex consult/review는 실프롬프트에서 2~9분 걸린다. `codex exec ... < /dev/null` 안에 `timeout 560`(GNU timeout, 초 단위)을 걸어도, **바깥 Bash 도구가 먼저 2분에 죽인다.** 내부 `timeout`과 Bash 도구 timeout은 별개 레이어이고, 짧은 쪽(Bash 2분캡)이 이긴다.

- **판별 (exit 코드로 원인 갈라라)**: `exit 143` + `Command timed out after 2m 0s` = **Bash 도구 timeout**(codex 정상, 추론/write 中 — Bash param 올려 재시도). `exit 124` = 안쪽 GNU `timeout` 만료 = **진짜 codex stall**(모델 hang, [[codex-model-stall-windows]] — 폴백). 둘을 혼동하면 정상 codex를 stall로 오인해 불필요 단일소스 격하한다.

## 회피
codex를 Bash로 직접 부를 땐 **Bash 도구의 `timeout` param을 codex 하드타임아웃 이상(≥585000ms)으로 명시**한다. GNU `timeout N`(초)도 함께 걸어 이중 안전:
`Bash(command: "timeout 560 codex exec \"...\" -s read-only < /dev/null ...", timeout: 585000)`
- `< /dev/null`은 stdin deadlock 회피(별개 규칙).
- probe는 대표프롬프트+`timeout 60`으로 짧게(모델 stall 조기발각 — [[codex-model-stall-windows]]). 실호출(consult/review)만 긴 timeout.
- **kill 후 복구 (특히 `-s workspace-write` 직접 exec)**: exit 143 후 `tasklist | grep codex.exe`(Win)로 생존 확인. **파일 편집 中(workspace-write) 오펀은 죽이지 마라 — mid-write kill은 산출 손상 위험.** bounded 폴링(10s 간격)으로 완주 대기 후 `git diff`로 최종 산출 재리뷰(SIGTERM에 유실된 codex 요약 대체). read-only/probe 오펀은 손상 없으니 정리 후 재실행 가능.

## 왜 안 헷갈려야 하나
`/codex` 스킬 경유는 스킬이 하드타임아웃을 기계강제하므로 이 문제가 없다. **Bash 직접호출 경로에서만** Bash 도구 timeout param을 사람이 챙겨야 한다. 안 챙기면 매 codex 직접호출마다 2분 낭비 후 실패로 오인 → 불필요한 폴백(단일소스 격하)까지 감.
