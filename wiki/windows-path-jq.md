---
title: Windows에서 훅이 jq를 못 찾는 문제 (stale PATH)
type: gotcha
links: [[slack-notify-hook]], [[jq-korean-encoding]]
sources:
  - (pre-inbox, 근거 유실)
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

## 자매 축 — git-bash PATH는 `/c/...` POSIX 형식이어야 한다

같은 "Windows PATH가 셸에서 깨진다" 클래스의 다른 얼굴이다. git-bash에서 `PATH`에 **`C:/...` 윈도 형식**이 섞이면 `command -v`/`which`가 그 항목을 해석하지 못해 **거기 있는 실행파일을 못 찾는다**(예: `mvn`이 "설치돼 있는데 없다"고 나온다).

- 판별: `echo "$PATH" | tr ':' '
' | grep -n '^[A-Za-z]:'` → 매치가 있으면 그 항목이 죽은 경로다.
- 회피: git-bash 안에서 조립하는 PATH는 **`/c/...` POSIX 형식**으로 통일한다(`cygpath -u`로 변환).
- 실측: 2026-08-24 세션에서 `mvn` 미검출로 빌드 단계가 막혔다.

