---
title: PowerShell Set-Content -Encoding UTF8은 BOM을 붙여 YAML/파서 첫 키를 깨뜨린다
type: gotcha
links: [[jq-korean-encoding]]
sources:
  - 발생 세션 2026-06-29 autopatch-dashboard-export-1 (GitLab CI shell executor, PowerShell)
  - 코드: export_config.yml 생성(SnakeYAML 바인딩), application.yml
updated: 2026-06-29
---

## 증상
PowerShell로 생성한 yml/conf를 앱이 읽는데 **첫 번째 키만 안 읽힘** → 그 키에 매달린 바인딩이 전부 null → 엉뚱한 분기/기본값으로 빠짐(예: `exportconfig.*` null → vcsInfo=null → 잘못된 VCS 분기, NPE). 파일을 사람 눈으로 열면 멀쩡해 보여 진단이 헷갈린다.

## 진짜 원인
- PowerShell 5.1의 `Set-Content -Encoding UTF8`(및 `Out-File -Encoding utf8`)은 파일 앞에 **UTF-8 BOM**(`EF BB BF`)을 붙인다.
- SnakeYAML 등 BOM 비관용 파서는 BOM+첫 키를 한 토큰처럼 읽어 첫 키 이름이 깨진다(`exportconfig` → 안 잡힘).

## 회피
- BOM 없는 UTF-8로 쓴다:
  ```powershell
  [System.IO.File]::WriteAllText($path, $cfg, (New-Object System.Text.UTF8Encoding($false)))
  ```
- 내용이 ASCII 범위면 `Set-Content -Encoding ascii`도 가능.
- 검증: `Format-Hex $path | Select-Object -First 1` 의 앞 3바이트가 `EF BB BF`가 아닌지 확인.
- 참고: 이 환경의 PowerShell 기본 파일 인코딩은 UTF-16 LE(BOM)라 도구가 읽을 파일엔 인코딩을 항상 명시해야 한다([[jq-korean-encoding]]도 같은 인코딩 함정 계열).

## 하네스 적용
- Windows에서 코드 에이전트(developer/tester)가 파서가 읽을 설정파일을 PowerShell로 생성할 때 필수 점검. 빌드·CI 산출 yml/json/conf 전부 해당.
- 근원: autopatch 비대화형 export 복구 회고(2026-06-29) — git config인데 SVN 분기로 빠진 진짜 원인이 이 BOM이었다.
