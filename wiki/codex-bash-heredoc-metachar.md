---
title: codex를 Bash로 직접 호출 시 프롬프트 셸 메타문자는 heredoc 파일로 전달
type: gotcha
links: [[codex-bash-direct-timeout]], [[codex-tmp-windows-path]]
sources:
  - inbox 20260702T022344Z / autopatch-cli-1 (dry-commands 2차 TDD 7.7) / authpatch_draft
updated: 2026-07-02
---

## 증상
`timeout N codex exec "...프롬프트..." -s read-only < /dev/null`로 codex를 Bash 직접호출할 때, 프롬프트에 백틱(`)·`$`·`[]{}` 등 셸 메타문자가 있으면 double-quoted 문자열이 조기종료/명령치환돼 `unexpected EOF while looking for matching ` (exit 2)로 실패. codex는 호출조차 안 됨(셸 파싱 단계에서 죽음).

## 진짜 원인
Bash가 double-quote 안의 백틱/`$`를 명령치환·변수전개로 해석한다. 리뷰·TDD 케이스산출처럼 프롬프트가 코드/정규식/셸 문자를 논하면 메타문자가 흔히 섞이므로 재발률이 높다.

## 회피 (검증됨)
프롬프트를 single-quote heredoc(`<<'PROMPT'`)으로 임시파일에 쓰고 `codex exec "$(cat "$PF")"`로 전달 → 내부 메타문자 전부 리터럴. 실행 후 `rm -f "$PF"`.
```bash
PF=$(mktemp /tmp/codex-XXXX.txt)
cat > "$PF" <<'PROMPT'
...메타문자 포함 프롬프트...
PROMPT
timeout 330 codex exec "$(cat "$PF")" -s read-only < /dev/null; rm -f "$PF"
```

## 일반화
codex Bash직접호출 표준을 heredoc-파일 전달로 한다(백틱 없어도 무해 — 기본값으로 안전). timeout param은 [[codex-bash-direct-timeout]]과 함께 챙긴다(별개 축: 이건 쿼팅, 저건 timeout 레이어). `/codex` 스킬 경유는 스킬이 전달을 캡슐화하므로 무관 — Bash 직접호출 경로에서만 발생.
