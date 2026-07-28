---
title: Windows 네이티브 jq는 stdout에 CRLF를 쓴다 — 중간 파이프가 끼면 CR이 살아남아 무음 오판
type: gotcha
links: [[windows-path-jq]], [[jq-korean-encoding]], [[gates-verify-present-code-only]]
sources:
  - ../CHANGELOG.md — v4.3.0 "RED 기준선 대조" (실측 발견)
updated: 2026-07-28
---

**증상:** `jq`로 읽은 파일 경로 목록으로 존재 확인을 돌리면 **실재하는 파일이 "삭제됨"으로 판정**된다. JSON 자체는 멀쩡하다.

```bash
BASE_PATHS="$(jq -r '.files | keys[]' "$STATE" | sort -u)"
while IFS= read -r f; do
  [ -f "$f" ] || echo "삭제됨: $f"     # ← 존재하는데 여기 걸린다
done <<< "$BASE_PATHS"
```

**원인:** winget 등으로 깐 **Windows 네이티브 jq**(`jq-1.8.1`)는 stdout을 텍스트모드로 열어 개행을 `\r\n`으로 쓴다. JSON 파일 안의 키는 깨끗하고, **jq의 출력만** CR이 붙는다.

```
$ jq -r '.a[]' t.json | cat -A
x^M$
y^M$
```

**왜 평소엔 안 터지나 (이게 함정의 핵심):** MSYS/Git Bash 도구 상당수가 텍스트모드 파이프에서 CR을 알아서 걸러준다. 그래서

- `V="$(jq -r '.n' f)"` → 명령치환이 CR을 먹어 `[ "$V" -ge 3 ]` **정상 동작**
- `jq -r '.a[]' f | grep -Fxq -- "x"` → grep이 걸러 **정상 매칭**

즉 **대부분의 경로가 운좋게 통과**한다. 그런데 `jq | sort` 처럼 **중간에 파이프를 하나 끼우면** CR이 그 문자열 안에 살아남고, 이후 `[ -f "$f" ]`·`grep -Fxq "$x"` 같은 **정확 비교가 조용히 어긋난다**. 에러는 0이다.

**회피:** jq 출력은 무조건 CR을 벗겨 받는다. 래퍼 하나로 고정하는 게 안전하다.

```bash
jqr() { jq -r "$@" 2>/dev/null | tr -d '\r'; }
```

`jq -c`/`jq .`로 **JSON을 다시 파일에 쓰는** 경로는 무해하다(파서가 공백을 무시). 문제가 되는 건 `-r` 출력을 **셸이 문자열로 비교**하는 경로뿐이다.

## 왜 위험한가 (무음 실패 클래스)

이 결함은 게이트를 **통과시키는 방향으로** 틀린다. `red-baseline.sh`에서는 백엔드 테스트 파일이 통째로 목록에서 빠지거나 "삭제됨"으로 잘못 분류돼, **테스트 약화 탐지가 조용히 무력화**됐다. 에러 0, 종료코드 0, 사람 육안으로만 발각 — [[gates-verify-present-code-only]]와 같은 클래스다.

## 같은 계열 (Windows + jq)

표면은 비슷하나 근본원인이 각각 다르다.

- [[windows-path-jq]] — jq **바이너리를 못 찾는** 문제(stale PATH 상속)
- [[jq-korean-encoding]] — jq 출력을 **curl 인자로** 넘길 때 cp949 변환으로 한글 깨짐(파일 경유로 회피)
- 이 페이지 — jq **출력 개행**이 CRLF

## 교훈

크로스플랫폼 셸 스크립트에서 **"이 도구의 출력을 문자열로 정확비교"** 하는 지점은 CR 정규화를 명시한다. "테스트해보니 되더라"는 근거가 약하다 — MSYS가 걸러주는 경로에서만 돌려봤을 수 있다.
