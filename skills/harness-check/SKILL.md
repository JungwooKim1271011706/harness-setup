---
name: harness-check
description: 하네스가 자기 운영 고통(과다 루프·게이트 escalation·출력/런타임 실패·설계 반려 반복)을 스스로 회고해 개선 후보를 탐지한다. 워크플로 종료 시 자동, 또는 "하네스 자가 점검"·session-check 넛지로 호출. 탐지·초안까지만 — 분류·적용은 /harness-retro 승인 게이트로 넘긴다.
argument-hint: "[선택: 특정 실행/영역]"
---

# 하네스 자가 점검 (운영 고통 → 개선 후보 탐지)

하네스가 **자기 자신의 운영 고통**을 회고해 개선 후보를 만든다. 자기개선 루프 **③ 규칙화의 입력 자동 생성기** — 사람이 회고를 가져오지 않아도, 하네스가 겪은 비효율을 스스로 신호로 잡아 `/harness-retro`에 먹인다.

## 불변식
- **탐지=자동, 적용=사람 승인.** 이 스킬은 후보를 만들어 `/harness-retro`에 넘기는 데서 끝난다. 실제 하네스 수정·커밋은 `/harness-retro`의 승인 게이트 뒤에서만.
- **후보 0건이면 조용히 종료**(잔소리 금지).

## 트리거
1. **자동(워크플로 종료)**: orchestrator `## 하네스 운영 자가 회고 (post_commit 자가점검)`에서 아래 고통 신호 중 하나라도 떴으면 호출.
2. **자동(누적)**: 동일 `실패 영역` `failure_*.md`가 2건 이상(기존 `## 실패 패턴 기록` 규칙).
3. **수동/넛지**: 사용자가 "하네스 자가 점검" 요청, 또는 session-check `⚠ 미처리 실패 패턴 N건` 넛지.

## Step 1 — 운영 고통 신호 수집
이번 실행(또는 누적)에서 아래 신호를 "무엇이·얼마나·어디서" 구체로 수집한다.

| 신호 | 무엇 | 소스 |
|------|------|------|
| 과다 루프 | tester↔developer 또는 7.7 품질게이트 LOOP ≥2/3 (결국 PASS여도) | `[LOOP n/3]` 태그 / checkpoint LOOP 값 |
| 게이트 escalation | 3루프 후 FAIL 중단·사용자 에스컬레이션 | `failure_*.md` / 이번 실행 |
| 출력·런타임 실패 | codex hang/타임아웃 폴백, 환경 FAIL, 세션 한도 사망(핸드오프) | codex 가드 폴백 태그 / FAIL 3분기 환경 / context-save 핸드오프 |
| 설계 반려 반복 | DESIGN_MISMATCH 재게이트 ≥2 | 이번 실행 / `failure_*.md` |

- `failure_*.md`가 있으면 전부 읽어 누적 패턴(동일 영역 2건+)도 포함.
- 신호 0건 → 종료.

## Step 2 — 개선 후보로 변환
각 고통 신호를 회고 항목으로 변환한다(= `/harness-retro` 입력 형식): `title` / 문제(증상: 무엇이 얼마나 비효율적이었나) / 추정 원인 / 제안 개선 방향 / 근거(이번 실행 인용·failure 파일).
- 근거가 약하면(1회성·외부요인) priority를 낮추거나 제외한다. 예: **세션 한도 사망은 외부 토큰 문제** — 하네스 레버리지가 작으면 규칙화 후보에서 빼고 관찰만 한다(YAGNI).

## Step 2.5 — inbox 자동 드롭 (transport, 머신글로벌)
check는 보통 **실작업 세션**(worktree·제품 repo)에서 돈다. 적용 자리(harness-setup SSOT dev clone)와 다른 repo이라 거기서 바로 적용 못 한다. 후보를 복붙 없이 dev clone으로 나르기 위해 **머신글로벌 inbox에 파일로 자동 드롭**한다. 적용이 아니라 **운반** — 탐지 자동의 일부.
- 경로: `~/.claude/harness-retro-inbox/<UTC타임스탬프>__<프로젝트slug>.md`
  - 타임스탬프 = `date -u +%Y%m%dT%H%M%SZ` (실세션이라 Bash `date` 사용 가능).
  - slug = `eval "$(~/.claude/skills/gstack/bin/gstack-slug 2>/dev/null)"`의 `$SLUG`, 없으면 `basename "$PWD"`.
  - `mkdir -p`로 디렉터리 보장.
- 내용 = Step 2 변환 회고 텍스트 그대로(= `/harness-retro` 입력 형식) + 프런트매터(`source_session`/`project`/`date`).
- **중복 방지**: 같은 신호의 pending 파일이 inbox에 이미 있으면 새 파일 만들지 말고 갱신.
- 이 inbox 파일(경로 + 프런트매터)은 이후 `/harness-retro`가 wiki 페이지 `sources`로 참조한다 — 증상/추정원인/제안/근거/관련파일/발생세션이 보존돼야 한다.
- 두 repo(harness-setup·제품 gitlab) 어디도 안 건드린다 — inbox는 중립지대. 후보 0건이면 드롭도 생략.

## Step 3 — /harness-retro에 위임 (또는 inbox 안내)
- **dev clone 세션이면**(판별식 = `wiki/_schema.md` "어디로 가나" SSOT: `basename $(git rev-parse --show-toplevel)` ≠ `.claude`. origin 판별 금지 — 중첩 `.claude`도 origin이 harness-setup이라 오판): 변환 후보로 바로 **harness-retro 절차를 실행**한다(분류·라우팅·bump추론·초안·승인요청 = `skills/harness-retro/SKILL.md` SSOT, 중복 재구현 금지). ⚠ dev clone은 `/harness-retro` 슬래시 미등록(harness가 repo 루트라 `.claude/skills/` 경로 없음) → **파일 절차로 실행**, 슬래시 호출 아님.
- **실작업 세션(소비자)이면**: 적용 불가하니 retro 실행 안 함. Step 2.5 inbox 드롭 + "dev clone에서 inbox 처리"(소비자 세션은 `/harness-retro` 슬래시 등록됨, dev clone은 SKILL.md 절차) 1줄 안내로 끝낸다. inbox에 떨궜으니 dev clone 세션 시작 시 session-check 넛지가 집어준다.
- 후보가 전부 reject(1회성·외부요인)면 inbox 드롭·retro 호출 없이 "개선 후보 없음 — 관찰 N건만 보고"로 종료.

## Step 4 — 승인 노티
`/harness-retro`의 승인 요청을 사용자에게 그대로 띄운다:
```
🔧 하네스 자가 회고 — 이번 실행에서 운영 고통 N건 감지
(각 후보: 신호 / 증상 / 개선 초안 / 대상파일 / bump)
→ 적용 승인할 항목을 골라줘 (거버넌스 영향 항목은 ⚠ 별도 확인)
```

## 경계
- 탐지·초안까지만. 적용은 `/harness-retro` 승인 게이트.
- 외부요인(토큰 한도 등) 1회성은 하네스 수정 후보가 아니라 관찰 — 무리하게 규칙화하지 않는다.
- 벤더 스킬(`~/.claude/skills/gstack/`) 수정 금지(글로벌 의존).
