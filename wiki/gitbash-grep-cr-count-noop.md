---
title: Git Bash에서 `grep -c $'\r$'`가 줄끝 판정에 no-op — CR 유무와 무관하게 전체 줄 수
type: gotcha
links: [[jq-crlf-stdout-windows]], [[msys-sed-inplace-crlf-strip]], [[windows-path-jq]]
sources:
  - sources/20260911T051044Z__khnp-cme-9.3.1.md
updated: 2026-09-14
---

**증상:** CRLF 여부를 재려고 `printf 'lines=%s crlf=%s' "$(wc -l < $F)" "$(grep -c $'\r$' $F)"`를 돌리면 `lines=129 crlf=129`가 나온다. "129줄 모두 CRLF"로 읽힌다. 그 전제가 사용자 보고와 하위 에이전트 위임에 함께 실린다.

**진짜 원인:** **미확인** — msys grep의 텍스트 모드 CR 처리이거나 도구 레이어의 `$'…'` 해석 중 하나로 추정. 원인과 무관하게 확정된 사실은 하나다: **이 측정식은 CR이 있든 없든 같은 값(전체 줄 수)을 낸다.** 반례로 확인 — `git ls-files --eol`이 `i/lf w/lf`로 확정한 파일에 같은 식을 돌리니 `grep-crlf=250` = 그 파일 전체 줄 수였고, `tr -cd '\r' < f | wc -c`는 **0**이었다.

**회피 (줄끝 판정 수단):**
- `git ls-files --eol -- <파일>` → `i/…  w/…` (저장소/워킹트리 각각)
- `tr -cd '\r' < <파일> | wc -c` → CR 바이트 개수
- python bytes 카운트

**일반 규칙 — 이 페이지의 진짜 교훈:**
> **판정용 측정식은 답을 아는 반례 1개에 먼저 돌려 값이 갈리는지 확인한다.**

이번엔 LF로 확정된 파일 1개면 **30초**에 드러났다. 파일 손상은 없었다 — 비용은 **틀린 사실이 보고와 위임 전제로 퍼진 것**(정정 보고 1회, tester 2명 중 1명이 같은 오판을 복창)이다.

**같은 계열 (같은 표면: Windows CRLF · 다른 원인):**
- [[jq-crlf-stdout-windows]] — 네이티브 jq가 stdout에 CR을 **넣어서** 후속 판정을 오염시킨다(파이프가 결과를 오염).
- [[msys-sed-inplace-crlf-strip]] — `sed -i`가 CR을 **떼어내서** 파일을 손상시킨다(도구가 대상을 오염).
- 이 페이지 — 측정식이 **아무것도 안 재는데 그럴듯한 숫자를 낸다**(측정식 자체가 no-op).

세 번째가 가장 조용하다. 앞의 둘은 결과가 틀리지만, 이건 **참/거짓을 가르는 능력이 아예 없다.** `orchestrator.md §0④`의 "인코딩·이스케이프·바이트 수준 검증은 파이프를 경유하지 않는다"가 이 축까지 덮도록 확장돼 있다.
