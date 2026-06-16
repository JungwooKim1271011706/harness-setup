---
title: Windows에서 훅이 jq를 못 찾는 문제 (stale PATH)
type: gotcha
links: [[slack-notify-hook]], [[jq-korean-encoding]]
updated: 2026-06-14
---

훅 스크립트가 `jq`에 의존하는데, Windows에서 CC가 띄운 훅 셸의 PATH에 jq가 없어 ASCII 폴백으로 빠지는 문제.

## 원인
- CC는 **실행 시점의 환경(PATH)을 자식 셸에 상속**한다. winget으로 jq를 설치하면 user 환경변수 PATH엔 등록되지만, CC가 그 갱신 **이전**에 떠 있었으면 훅 셸까지 전파가 안 된다.
- **CC 재시작해도** 상위 터미널/프로세스 환경이 stale이면 여전히 안 잡힌다 → 재시작에 기대면 안 됨.

## 해법 (스크립트가 채택)
PATH 의존을 없애고 **스크립트가 jq를 스스로 찾는다**. 상단에서 `command -v jq`가 실패하면 알려진 설치 경로를 PATH에 prepend:
- `$HOME/AppData/Local/Microsoft/WinGet/Packages/jqlang.jq*/` (winget 경로엔 버전이 안 박혀 안정적)
- WinGet `Links/`, `/mingw64/bin`, `/usr/bin`
jq-less 셸에서 검증 완료. 정말 못 찾을 때만 ASCII 폴백.

## 교훈
- Windows에서 훅이 외부 CLI(jq 등)에 의존하면 **PATH를 신뢰하지 말고** 스크립트가 직접 탐색하게 짜라.
- "winget 설치했으니 재시작하면 되겠지"는 자주 틀린다.
- 적용 사례: [[slack-notify-hook]] (한글 요약은 [[jq-korean-encoding]] 때문에 jq 필요).
- 같은 stale-PATH 패턴 재발: [[gstack-install-windows]] (bun이 설치돼 있어도 git-bash PATH에 없어 setup 실패).
