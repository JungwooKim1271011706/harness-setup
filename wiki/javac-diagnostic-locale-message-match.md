---
title: javac 진단을 로케일 메시지로 매칭하면 영원히 false — 판정은 getCode()로
type: gotcha
links: [[surefire-nested-skip]], [[spring-componentscan-basepackages-root-omission]], [[device-guard-blocks-jdk-javac]]
sources:
  - 발생세션: selfheal-javac WEB-INF/lib 리뷰 수정 라운드1 (autoPatch, 소비자 세션, 2026-07-15)
  - 커밋 bd63f1dd
  - docs/adr/2026-07-14-selfheal-javac-webinflib.md (제품 repo)
  - codex review P2 + code-reviewer 겹침 지적, developer 실측 프로브(JDK 11.0.2 `CODE=compiler.err.doesnt.exist`)
  - inbox: ~/.claude/harness-retro-inbox/20260714T235613Z__DEVUNIT-authpatch_draft__javac-diagnostic-locale.md
updated: 2026-07-15
---

**증상:** javac 컴파일 실패 시 붙어야 할 진단 힌트가 **한 번도 안 붙는다**. 예외 없음, 로그 없음, 테스트도 GREEN. 테스트가 키워드만 느슨히 단언하면(`hasMessageContaining("tocFramework")`) 힌트 로직이 통째로 죽어 있어도 통과. [[surefire-nested-skip]]·[[spring-componentscan-basepackages-root-omission]]과 같은 **"에러 없이 그냥 안 되는"** 계열.

**진짜 원인:** `compiler.getStandardFileManager(diagnostics, Locale.KOREAN, UTF_8)` + `d.getMessage(Locale.KOREAN)`으로 진단을 뽑으면 메시지가 **한글로 렌더**된다. 그 문자열에 영어 리터럴 `"cannot find symbol"`을 `contains()` 하면 **영원히 false**. 로케일을 정한 코드와 매칭하는 코드가 같은 클래스 안에 있어도 눈에 안 띈다(리뷰 2소스 중 codex만 지적).

**회피:** 사람용 메시지로 분기하지 마라. 언어 무관 판정은 **`Diagnostic.getCode()`** — `compiler.err.*` 리소스 키다. 메시지는 사람에게 보여줄 때만, 판정은 code로.

**추가 함정 (실측으로만 나옴):** 미해결 심볼이라고 다 같은 code가 아니다.
- 클래스 미해결 → `compiler.err.cant.resolve[.location][.args][.params]`
- 패키지 자체가 classpath에 없음 → **`compiler.err.doesnt.exist`** ("package X does not exist")

classpath가 통째로 빠진 상황(= self-heal이 잡으려던 바로 그 케이스)은 `doesnt.exist`로 떨어진다. `cant.resolve` 계열만 필터하면 **고친 뒤에도 여전히 못 잡는다**. JDK 11.0.2로 직접 프로브해 확인 — 추측하지 말고 실제 javac에 물어볼 것.

**널가드 필수:** `getCode()`는 null 가능. `Set.of(...).contains(null)`은 NPE(Set.of는 null 거부) → `d.getCode() != null && CODES.contains(d.getCode())`.

**검증 노트:** 이 계열은 mock 진단으로 테스트하면 자기충족(테스트가 리터럴을 넣고 리터럴을 찾음)이 된다. **실제 JDK javac로 미해결 심볼을 컴파일시켜** 힌트 부착을 확인해야 진짜 검증(tester-backend 재검증서 실증).
