# 회고 inbox — BL-035/036 라운드 gotcha 3건 (소비자 세션 드롭)

**출처 세션**: DEVUNIT/authpatch_draft `feature-dashbaord-commitlog-4`, 2026-08-02
**관련 커밋**: `d0452227`(구현), `3ece9939`(E2E 기록)
**드롭 사유**: 소비자 세션(제품 repo vendoring `.claude`)이라 wiki 직접커밋 금지. dev clone에서 `/harness-retro` 드레인 대상.

---

## 1. Java 렉서는 주석 안의 `\uXXXX`도 해석한다 → `illegal unicode escape`

**증상**: `mvn test-compile`이 Javadoc 라인에서 실패.
```
SubmoduleCommitDiffDtoTest.java:[14,27] illegal unicode escape
SubmoduleCommitDiffDtoTest.java:[23,40] illegal unicode escape
```

**원인**: Java 컴파일러는 **렉서 단계에서** 유니코드 이스케이프를 먼저 치환한다 — 주석 내부도 예외가 아니다. 주석에 `\u` 뒤로 유효한 4자리 hex가 아닌 텍스트(플레이스홀더 `XXXX` 등)를 적으면 그 자체가 컴파일 에러다. **문자열 리터럴 밖이라고 안전하지 않다.**

**아이러니**: 그 주석은 "소스에 `\uXXXX` 이스케이프를 직접 쓰지 말라"고 경고하려던 문장이었다. 경고문이 스스로 함정에 걸렸다.

**회피**: 주석에서도 `\\uXXXX`(이중 백슬래시) 또는 `U+XXXX` 서술 표기를 쓴다. 같은 파일 다른 줄이 이미 `\\u200B-\\u200F`로 올바르게 쓰고 있었는데 2줄만 단일 백슬래시로 남아 있었다 — **부분 적용이 더 위험**(있는 줄을 보고 안전하다고 착각).

**후보 라우팅**: `.claude/rules/package/<proj>/backend.md`의 기존 "Write 도구 이스케이프 함정" 항목과 **같은 계열, 다른 변형**(그건 도구가 raw 바이트를 쓰는 문제, 이건 컴파일러가 표기를 해석하는 문제). 그 항목에 이 변형을 추가하는 편이 자연스럽다. 또는 wiki gotcha 페이지.

---

## 2. `toUpperCase()` no-op 픽스처 — 대소문자 테스트가 통째로 공허

**증상**: 7.7 품질게이트가 critical로 적발. 테스트 3건이 "대소문자 무관 매칭" 계약을 검증한다고 이름 붙여놓고 실제로는 아무것도 검증하지 않았다.

**원인**: SHA 상수가 `"9".repeat(40)` — **전부 숫자**. `SUBMODULE_SHA.toUpperCase()`가 원본과 바이트 단위로 동일한 문자열을 만든다. 구현의 `equalsIgnoreCase`를 `equals`로 바꿔도 3건 전부 통과(mutation 무력).

**재발 사실**: 이 저장소는 **같은 결함을 이미 겪었다**. `SubmodulePathGateTest.java:252~256`에 사고 기록과 교정 헬퍼 `withMixedCase()`(알파 문자 위치를 스캔해 치환)가 남아 있다. 그런데 새 테스트 파일이 그 선례를 안 쓰고 같은 함정을 재생산했다.

**회피**:
- 대소문자 파생 픽스처는 **원본이 실제로 알파를 포함하는지** 확인한다(hex 상수는 숫자만으로도 유효해서 특히 위험).
- **변별력 자가검증을 단언으로 박는다**: `assertThat(upper).isNotEqualTo(original)`. 이게 없으면 누군가 상수를 다시 숫자로 바꿀 때 조용히 재발한다 — 이번 사고가 정확히 그 시나리오다.
- 같은 저장소에 교정 헬퍼가 이미 있으면 재발명하지 말고 재사용/미러.

**일반화**: "대표값 하나로 계약 전체를 대신하는" 결함 계열. 같은 라운드에서 정화 제거집합 7항 중 4항이 무커버였던 것도 같은 뿌리 — **프로덕션이 열거로 계약을 정의하면 열거 항목 수 = 테스트 축 수**인지 대조해야 한다.

**후보 라우팅**: rules backend.md 테스트 함정 절 또는 wiki. tester-design/tester-quality 계약에 "열거 계약 대조표" 체크 추가도 검토 가치.

---

## 3. codex 백그라운드 폴링 함정 3종 (git-bash/Windows)

**증상 A — 거짓 성공 폴링**: `until grep -q '^## FINDINGS' "$LOG"` 루프가 **즉시 통과**(polls=0). codex가 프롬프트를 로그에 에코하는데 그 프롬프트에 출력 형식 예시로 `## FINDINGS`가 들어 있기 때문. 실제 결과는 5000줄 뒤에 나온다.
→ **회피**: 블록 개수로 판정(`grep -c` ≥ 2)하고 **마지막 블록**을 취한다(`grep -n ... | tail -1`).

**증상 B — `pgrep` 부재**: `pgrep -f "codex exec"`가 `command not found`. git-bash에 없다.
→ 회피: 프로세스 감시 대신 **로그 내용**이나 journal 이벤트 카운트로 폴링.

**증상 C — foreground `sleep` 차단**: `sleep 90; <check>` 형태가 도구 레벨에서 거부된다("use Monitor with an until-loop").
→ 회피: `until <cond> || [ $i -ge N ]; do sleep 6; i=$((i+1)); done` 형태의 bounded 루프.

**추가**: codex 백그라운드(`nohup ... &`)는 **세션 경계에서 끊길 수 있다**(task notification이 `stopped`로 옴). 단 로그 파일은 남아 있어 사후 회수 가능했다 — 이번엔 실제로 정상 완주(`tokens used` + Stop hook 마커 확인)해 findings를 온전히 건졌다. **끊김 통지 ≠ 산출 유실**이므로 재실행 전에 로그부터 확인할 것.

**후보 라우팅**: `orchestrator.md` `## codex 호출 가드`(stdout 봉쇄 절에 폴링 패턴 추가) 또는 wiki gotcha.

---

## 부수 관찰 (프로젝트 한정, 규칙화 가치 낮음)

- 이 프로젝트 루트 pom에는 `skipTests`/surefire 리터럴이 **없다** → tester의 sed 오버라이드 절차가 **no-op**이다. trap 원복은 정상 작동하지만 "무변경이 정상"임을 모르면 혼동한다.
