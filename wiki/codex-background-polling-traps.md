---
title: codex 백그라운드 실행 폴링 함정 3종 (git-bash/Windows) — 거짓 성공·pgrep 부재·sleep 차단
type: gotcha
links: [[codex-bash-direct-timeout]], [[codex-model-stall-windows]], [[codex-bash-heredoc-metachar]]
sources:
  - sources/2026-08-02-authpatch-bl035-gotchas.md
updated: 2026-08-03
---

codex를 백그라운드(`nohup … &`)로 돌리고 로그를 폴링해 완료를 판정할 때 밟는 함정들. 셋 다 **조용히 잘못된 판정**을 만든다.

## ① 거짓 성공 폴링 — codex가 프롬프트를 로그에 에코한다

**증상:** `until grep -q '^## FINDINGS' "$LOG"` 루프가 **즉시 통과**(polls=0). 실제 결과는 5000줄 뒤에 나온다.

**원인:** codex는 **받은 프롬프트를 로그에 그대로 에코**한다. 프롬프트에 출력 형식 예시로 `## FINDINGS`를 넣었으면 그 문자열이 로그 맨 앞에 이미 있다. 마커 존재로 판정하면 자기 지시문을 결과로 읽는다.

**회피 — 개수로 판정하고 마지막 블록을 취한다:**
```bash
# ❌ grep -q '^## FINDINGS' "$LOG"
# ✅
[ "$(grep -c '^## FINDINGS' "$LOG")" -ge 2 ] || continue
START=$(grep -n '^## FINDINGS' "$LOG" | tail -1 | cut -d: -f1)
sed -n "${START},\$p" "$LOG"
```
프롬프트에 형식 예시를 **안 넣는 것**도 해법이지만, 예시가 산출 품질을 올리므로 개수 판정이 낫다.

## ② `pgrep` 부재 (git-bash)

**증상:** `pgrep -f "codex exec"` → `command not found`.

**원인:** git-bash에 `pgrep`이 없다. 프로세스 생존으로 완료를 판정하는 관용구가 통째로 안 돈다.

**회피:** 프로세스 감시를 버리고 **로그 내용**(위 ①의 블록 개수, `tokens used` 같은 종료 마커) 또는 journal 이벤트 카운트로 폴링한다. PowerShell을 섞을 수 있으면 `Get-CimInstance Win32_Process`.

## ③ foreground `sleep`이 도구 레벨에서 거부된다

**증상:** `sleep 90; <check>` 형태가 실행되지 않고 *"use Monitor with an until-loop"* 로 거부.

**회피 — bounded 루프로:**
```bash
i=0; until <cond> || [ $i -ge 30 ]; do sleep 6; i=$((i+1)); done
```

## ④ 세션 경계 끊김 — **끊김 통지 ≠ 산출 유실**

백그라운드 codex는 세션 경계에서 끊길 수 있다(task notification이 `stopped`로 도착). 하지만 **로그 파일은 남아 있어 사후 회수된다.** 실측 사례에서 통지는 `stopped`였는데 실제로는 정상 완주(`tokens used` + Stop hook 마커 확인)해 findings를 온전히 건졌다.

→ **재실행 전에 로그부터 확인하라.** 일반 서브에이전트의 "사망 산출 판정"(`docs/playbook-delegation.md`)과 동일 정신 — 부재 통지를 산출 0으로 읽지 않는다.

**같은 계열(codex 실행·수집 함정):** [[codex-bash-direct-timeout]](직접 실행 타임아웃) · [[codex-model-stall-windows]](모델 stall) · [[codex-bash-heredoc-metachar]](heredoc 메타문자). 공통 교훈 — **codex의 stdout은 결과가 아니라 결과를 포함한 스트림이다. 마커 존재가 아니라 구조로 파싱한다.**
