---
title: msys `sed -i`가 CRLF 파일 줄끝을 통째로 LF로 바꾼다 (치환 대상이 없어도)
type: gotcha
links: [[jq-crlf-stdout-windows]], [[gitbash-grep-cr-count-noop]], [[powershell-set-content-utf8-bom]]
sources:
  - sources/20260911T051044Z__khnp-cme-9.3.1.md
  - sources/20260911T041336Z__khnp-cme-9.3.1.md
updated: 2026-09-14
---

**증상:** `sed -i 's#A#B#g' pom.xml` 실행 후 `git status`에 그 파일이 M으로 뜬다. `git diff`는 파일 전체가 바뀐 것처럼 보이는데 `git diff --ignore-cr-at-eol`은 **빈 결과** = 내용은 그대로고 **줄끝만** 바뀌었다. 치환할 문자열이 파일에 **없어도** 일어난다.

**진짜 원인:** Git Bash(msys) `sed -i`는 파일을 다시 쓰면서 CR을 떼어낸다. 저장소가 CRLF인 파일에서만 드러난다.
- 판별: `git ls-files --eol -- <파일>` → `i/crlf w/crlf attr/-text` 면 대상, `i/lf w/lf` 면 무해.
- 실측(khnp cme-9.3.1): `tocFramework/pom.xml`은 `i/crlf`라 손상, `tocAdminServer/pom.xml`은 `i/lf`라 같은 sed가 무해했다. **파일별로 갈린다.**

**왜 조용한가 — 백업까지 오염된다:**
tester의 pom 임시 오버라이드는 `자가치유 sed → cp pom pom.harnessbak → sed → mvn → trap이 harnessbak 복원` 순이다. **자가치유 sed가 `cp`보다 앞**이라 trap이 되돌리는 백업이 **이미 손상본**이다. 사후 확인(`git status --porcelain`)은 이상을 잡지만, 원복 수단이 `mv harnessbak`뿐이라 **쓸 수단이 없어** tester가 금지된 `git checkout -- pom.xml`으로 흘렀다 — 금지만 있고 대안이 없는 규칙이었다. 한 세션 2회 + 다른 세션 1회 재발(2026-09-11).

**회피:**
- **치환 대상 존재를 먼저 확인하고 조건부로만 sed 한다.**
  ```bash
  if grep -q '<skipTests>false</skipTests>' "$POM"; then
    sed -i 's#<skipTests>false</skipTests>#<skipTests>true</skipTests>#g' "$POM"
  fi
  ```
- **줄끝만 손상됐을 때의 탈출구**: `git diff --ignore-cr-at-eol --quiet -- <파일>`이 **참**이면(내용 변경 0) `git show HEAD:<파일> > <파일>`로 원본 바이트 복원. 거짓이면 금지 — 미커밋 변경 보호가 우선.
- ⚠ **역보정(`unix2dos`)을 추측으로 쓰지 마라.** 보정용 `unix2dos`가 원래 LF이던 옆 파일에 CRLF를 주입해 두 번 역보정하는 일이 실제로 났다. 원복은 **바이트 사본(`cp`/`git show`)으로만**, 파일별 EOL을 추측하지 않는다.
- ⚠ `sed -b`(`--binary`)가 CRLF를 보존하는지는 **미검증** — CRLF 파일 1회 실측 전에는 채택하지 않는다.

**교훈:** 인플레이스 편집 도구는 **아무것도 안 바꿔도 파일을 다시 쓴다.** "no-op이니 안전"은 텍스트 모드에서 성립하지 않는다.
