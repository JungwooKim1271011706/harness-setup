---
title: Orca 내장 브라우저로 렌더 E2E 실측하기 — 러너 없는 스택의 탈출구
type: 노하우
links: [[gates-verify-present-code-only]] [[claude-rules-gitignore-local-only]]
sources:
  - sources/20260909T063940Z__khnp-cme-9.3.1.md
updated: 2026-09-09
---

## 왜 필요한가

렌더 영향 변경은 정적 검증(타입체크·태그 대조·lint)만으로 종결하면 안 된다. 그런데 **Playwright/vitest 같은 러너가 없는 스택**(JSP + jQuery + 자체 컴포넌트 등)에서는 *"자동화 인프라 없음 → 사람 E2E 이관"*이 **사실상 기본값으로 굳는다.**

그 상태에서 실제 사고가 났다 — 게이트 6종(정적·유닛·`/review`·`/codex`·`/cso`·워크스루) **전원 PASS**로 커밋된 뒤 사용자가 화면을 열자 팝업이 인라인 노출돼 수정 커밋 1라운드(2026-08-24).

**Orca ADE가 설치된 환경이면 인프라가 있다.** 브라우저 자동화가 CLI로 노출돼 있어 **Bash만 있으면** 몰 수 있다 — `tester-frontend`는 이미 `Bash`를 갖고 있으므로 정식 위임으로 처리되고 하네스 역할 분리를 깨지 않는다.

실측(2026-09-09): 러너 없는 스택에서 E2E **4케이스 전부 자동 실행·판정**. 기간 상한 초과 토스트 + 파라미터 3중 동기 / 월말 보정(`5/31 → 2/28`, JS `Date`가 3/3으로 넘기는 함정 회피, 경계 ±1초 데이터로 판별) / 플래그 토글 양방향(경고 소멸·재노출, 관리 UI로 저장·원복까지) / 엑셀 내보내기 전송 파라미터 가로채기 + 다운로드된 xlsx **실물 파싱**.

## 최대 이점 — 사용자 로그인 세션을 그대로 쓴다

`chrome-devtools-mcp`는 **별도 브라우저 프로필**로 뜬다. 사내 관리자 콘솔처럼 로그인이 필요한 화면은 계정을 따로 받거나 쿠키를 주입해야 한다.

Orca 내장 브라우저는 **사용자가 ADE에서 이미 로그인해 둔 세션을 공유**한다. 로그인 URL로 이동시켰더니 곧바로 콘솔 대시보드로 리다이렉트됐다 — 이미 로그인 상태였다. **계정 정보를 주고받을 필요가 없다.**

부수 확인: `chrome-devtools MCP`가 `claude mcp list`상 Connected인데도 **세션 도구 목록에 안 뜨는** 상태였다(재현 반복 중). Orca CLI로 우회하면 **세션 재시작이 불요**하다.

## 사용법

경로는 반드시 탐지 래퍼를 경유한다 — 아래 **이식성 경고** 참조.

```bash
eval "$(bash .claude/scripts/browser-probe.sh)"   # TOOL=orca BIN=...
"$BIN" tab create --url "http://<host>/<path>"
"$BIN" tab list                       # pageId 확인
"$BIN" eval --expression "JSON.stringify({url:location.href})"
"$BIN" find --locator text --value "<메뉴명>" --action click
"$BIN" screenshot --format png --json > shot.json    # base64 를 JSON에서 추출
```

명령군: `tab create/list/show/current/close`, `goto`, `snapshot`, `click`, `fill`, `type`, `select`, `hover`, `keypress`, `scroll`, `back`, `reload`, `screenshot`, `eval`, `wait`, `check`, `find`, `get`, `is`, `mouse *`, `set device/offline/headers`

## 함정 (전부 실측)

### 1. `snapshot`은 깨진다 — `eval`로 대체하라

`snapshot`이 **매번** `runtime_unavailable`("The Orca runtime closed the connection before responding")로 실패했다. 그 직후 `status`는 `runtimeState: ready`였다 — **런타임은 멀쩡하다.** 접근성 트리 직렬화가 큰 페이지에서 죽는 것으로 보인다.

→ `eval --expression`으로 DOM을 직접 질의한다. 오히려 필요한 값만 뽑아 반환 크기도 작다.

### 2. `screenshot`은 간헐 실패 — 재시도로 감싼다

같은 `runtime_unavailable`이 `screenshot`에도 뜬다(1회차 실패 → 2회차 성공이 흔함). 결과가 파일이 아니라 **JSON 안의 base64**다(`--filePath` 옵션 없음).

```bash
for i in 1 2 3; do
  "$BIN" screenshot --format png --json > s.json && \
    python -c "...base64 추출·저장..." && break
  sleep 3
done
```

### 3. 프로그램적 setter는 이벤트를 안 쏜다 — 이게 오히려 무기다

자체 컴포넌트의 `setValue`/`setDate` 류는 값만 넣고 `onChange` 콜백을 호출하지 않는 경우가 많다(사용자가 UI로 고른 경로만 호출).

그래서 **"화면 값은 바뀌었는데 아직 조회는 안 한 상태"**를 정확히 만들 수 있다. *"내보내기 경로가 자체적으로 기간 보정을 하는가"*를 검증할 때 이게 결정적이었다 — 목록 검색을 **한 번도 안 거친 채** 내보내기를 눌러 그 경로의 보정 로직만 단독으로 찔렀다.

### 4. 자체 컴포넌트 조작 규약은 프로젝트 지식이다

합성 `MouseEvent`를 무시하는 그리드·트리, label 오버레이 때문에 `input.checked` 만으로는 시각 상태가 안 따라오는 라디오/체크박스, 표시 입력칸이 `readonly`라 달력을 클릭해야 하는 datepicker — 이런 건 **그 프로젝트 컴포넌트 라이브러리의 규약**이다.

> ⚠ **하네스 wiki에 쓰지 않는다.** 컴포넌트 이름·클래스명·접미 규약은 프로젝트 특화라 여기 담으면 소비자 오염이다. 해당 프로젝트 `rules/`에 남긴다([[claude-rules-gitignore-local-only]] — 로컬 전용이라 휘발성 주의).
>
> 일반화되는 교훈만 남긴다: **합성 이벤트가 안 먹으면 컴포넌트 API를 직접 호출한다.** 그리고 **셀렉터를 "정상" 클래스로 좁히면 예외 케이스에서 실패한다** — 달력에서 일요일·전후달 셀이 다른 클래스를 쓰는 식이다. 공통 클래스 + 가시성(`offsetParent !== null`) + 텍스트로 필터하는 편이 안전하다.

## 부수 노하우

- **토스트 캡처**: 알림 함수를 래핑해 배열에 기록(원본 위임 유지). 렌더된 DOM은 사라지지만 문구는 남는다.
- **전송 파라미터 검증**: 다운로드·AJAX 함수를 래핑해 `data`를 캡처하면 실제 요청값을 볼 수 있다. **UI 표시값과 전송값이 갈리는 버그**를 잡는다.
- **다운로드 산출물 검증**: xlsx는 `openpyxl`로 열어 머리말·데이터 행을 단언한다. `sharedStrings` 인덱스를 손으로 파싱하면 틀리기 쉽다.
- **API 직접 호출은 UI 보정을 우회한다.** 서버가 별도 상계를 갖는 설계면 `fetch`로 만든 결과와 화면 결과가 다르다 — **테스트는 UI 경로로.**

## ⚠ 이식성 — 경로를 하드코딩하지 마라

`orca` 실행 경로는 **머신 종속**이다. 하네스는 여러 머신·여러 사람이 공유하므로 규칙이나 agent md에 절대경로를 박으면 **그 경로가 없는 세션이 전부 깨진다.**

→ `.claude/scripts/browser-probe.sh` 탐지 래퍼를 경유하고, **못 찾으면 조용히 사람 E2E로 폴백**한다(차단 아님). orchestrator가 가용성을 확정해 하위 에이전트에 주입하고, **tester는 스스로 탐지하지 않는다** — `## codex 호출 가드`가 codex 가용성을 다루는 방식과 동형이다.
