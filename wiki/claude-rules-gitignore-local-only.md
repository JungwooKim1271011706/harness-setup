---
title: .claude/rules/ 는 gitignore — rule 편집은 git에 안 올라간다(로컬 전용)
type: gotcha
links: [[_schema]]
sources:
  - 발견 세션 2026-07-01 DEVUNIT-repostitch (rule④ 신뢰경계 문서가 커밋 안 됨, git check-ignore 실측)
updated: 2026-07-01
---

## 증상
계획/리뷰가 "rule 파일(`.claude/rules/package/.../backend.md`)에 규칙을 추가하라"는 항목을 내고, developer/finalizer가 그 파일을 실제로 편집했는데, **커밋에 그 파일이 안 잡힌다.** finalizer가 `git check-ignore -v`로 확인하니 무시 대상.

## 진짜 원인
`.claude/`는 **양쪽 git에서 무시**된다:
- **제품 repo**(`repostitch` 등): `.gitignore`에 `.claude/` → `.claude` 통째 무시.
- **`.claude` 자체 nested repo**(origin=harness-setup): 그 안 `.gitignore`에 `rules/` → `rules/` 하위는 harness-setup에도 안 올라감.

즉 rule 파일은 **디스크에만 존재**하고 어느 git 이력에도 안 남는다. rule은 원래 "프로젝트별·로컬"로 설계됐다(민감할 수 있어 gitignore). 로컬 rule-read(planner/developer/tester가 세션에서 Read)엔 정상 작동하지만 **git 동기화·PR·다른 머신 공유는 안 된다**.

## 회피 / 인지
- rule 파일 편집을 "커밋했다"고 착각하지 말 것. 편집 = 로컬 적용까지만.
- **다른 머신·팀과 공유해야 하는 규칙**이면 rule이 아니라 추적되는 곳(`CONTEXT.md` 용어, `docs/` 설계, 또는 harness-setup에서 `rules/` gitignore 정책 재검토)에 둔다.
- 위임 지시에 "rule은 추적됨/커밋 대상"이라 쓰지 말 것 — 실측(`git check-ignore -v <path>`)이 SSOT.
- wiki/(여기)는 `rules/`와 달리 **추적됨**. 그래서 이 gotcha는 wiki엔 남는다.

## 확장 축 — `docs/*`도 `.git/info/exclude` 대상이면 feature 문서가 복구 불가다

같은 뿌리(gitignore/exclude로 산출이 어느 git 이력에도 안 남음)인데 **위험도가 다르다**. 하네스는 `docs/features/*.md`를 **설계 SSOT**로 쓴다 — planner가 쓰고, 설계패널이 `planPath`로 읽고, 7c 합의·워크스루가 대조하고, 다음 세션이 재개 근거로 삼는다.

그런데 프로젝트에 따라 `docs/*`가 `.git/info/exclude`에 들어 있으면(로컬 전용 제외라 `.gitignore`와 달리 **커밋된 파일에도 안 보인다**) 그 문서는 **git 이력에 없다** → **파괴 시 복구 수단이 0**이다.

- 실측(2026-08-24): 세션 중 RESUME 문서가 **0바이트로 파괴**됐고 git으로 되살리지 못해 컨텍스트에서 재구성했다.
- 판별: `git check-ignore -v docs/features/<파일>` + `cat .git/info/exclude`. ⚠ `.gitignore`만 보면 못 잡는다.
- 회피: ① feature 문서를 덮어쓰기 전 **파일 크기·끝 수 줄 확인**(0바이트·잘림 감지) ② 장시간 트랙이면 `.claude/tmp/`에 스냅샷 1부 ③ 애초에 exclude에서 빼는 게 가능한 프로젝트면 뺀다.

