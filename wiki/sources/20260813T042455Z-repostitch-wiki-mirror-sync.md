# 회고 inbox — repostitch 위키 미러 동기화 (2026-08-13)

출처: 소비자 세션(repostitch). 커밋 `07af1de`(feat) + `7c4a7f8`(docs).
경로: 7.5 RED 잔여 14건 → 7.6 sanity → 7.7 FAIL(critical 2) → 수정 → 7.7 재게이트 PASS
→ GREEN 3배치 → 변경검증 → /review ∥ /codex review → /cso → 워크스루 → 커밋.
최종 unit 2571 PASS / 0 FAIL, 회귀 0.

---

## A. wiki 후보 (운영지식 gotcha)

### A1. `vi.clearAllMocks()`는 `*Once` 구현 큐를 비우지 않는다 (`mockReset`이 비운다)
Vitest에서 `clearAllMocks`는 `mock.calls`만 지우고 `mockRejectedValueOnce`/`mockResolvedValueOnce`로
큐잉된 **구현**은 남긴다. RED 단계처럼 구현이 미완이라 그 큐가 **자기 테스트 안에서 소비되지 않으면**
다음 테스트로 누출돼 무관한 케이스가 엉뚱한 에러(EBUSY 등)로 **단언 도달 전 크래시**한다.
실측: `E11`의 `readdir.mockRejectedValueOnce(EBUSY)`가 소비 안 된 채 뒤의 `G-LEGACYb`(overlay 회귀 가드)를
깨뜨렸다. 같은 파일에 `cp.mockRejectedValueOnce`도 동일 위험으로 대기 중이었다.
→ 해소: `beforeEach`에서 공용 fs mock 8종을 `mockReset()` + base 재설정으로 통일.
→ 판별 신호: "테스트 단독 실행은 통과, 전체 실행에선 무관한 에러로 실패".

### A2. codex 백그라운드 오펀 — 래퍼 sh가 죽어도 codex.exe는 산다
`nohup sh -c "codex exec ...; echo sentinel"` 패턴에서 세션 teardown이 **래퍼 sh만** 죽이면
codex.exe는 살아남아 리다이렉트된 fd로 **로그를 계속 쓰지만 sentinel은 영원히 안 찍힌다**.
→ sentinel 부재를 "죽었다"로 읽지 마라. `tasklist`로 프로세스 생존 + 로그 size 증가를 함께 봐라.
→ **workspace-write 오펀은 kill 금지**(파일 편집 중 산출 손상). bounded 폴링으로 완주 대기 후 `git diff` 재리뷰.
→ 실측: 이 세션 batch A2가 정확히 이 상태였고, 폴링으로 완주 회수했다(exit 0, 산출 온전).

### A3. 경로 **부분문자열** 매칭 mock은 의도보다 훨씬 넓게 덮친다 — 구현을 완화하지 말고 목을 좁혀라
`fsPromises.rm.mockImplementation(p => { if (String(p).includes('wiki-tmp')) throw ... })`가
"push 이후 tmp 정리 실패"만 노린 목이었는데, `mkdtemp` 목이 **디렉터리명 자체에 `wiki-tmp`를 박아서**
그 하위 **모든 경로**가 걸렸다 → 훨씬 앞 단계인 워킹트리 비우기(`_clearWorkTree`)까지 실패.
developer가 이걸 통과시키려 **설계 원안(fail-closed)을 best-effort로 완화**했고, 사실관계는 맞았지만
결과는 **삭제 미전파 미러**(안 지워진 파일을 `git add -A`가 "변경 없음"으로 보고, D4 백업 게이트의
삭제 집계마저 줄어 백업조차 안 걸림)였다.
→ 해소: 목을 `/wiki-tmp-\d+$/`(tmp 루트 정확매칭)로 좁히고, 원안 복원 + `S-CLEARFAIL` RED로 하드게이트를 잠금.
→ 일반화: **파괴적 연산에서 "정리 실패를 삼킨다"는 완화는 조용한 under-deletion을 만든다.**

### A4. vitest 전체 실행 시 실 `git.exe` 대량 spawn 통합테스트가 부하로 크래시한다
`migrate-builder-diskintegration.test.js` 53케이스가 전체 548초 중 **533초**를 먹고,
전체 동시실행에선 `STATUS_DLL_INIT_FAILED(0xC0000142)`로 **16건 크래시**. standalone은 53/53 PASS.
→ 회귀 아님(환경/부하). 개발 루프는 `--exclude '**/migrate-builder-diskintegration.test.js'`로 **32초**.
→ 단 **전체회귀 때는 이 파일을 별도 순차/격리 실행**해야 커버리지가 빈다. 제외 사실은 항상 명시 기록.

### A5. codex probe 60s 예산이 플러그인 preamble에 먹힌다
`codex exec` 1회가 superpowers 플러그인 preamble(PowerShell `Get-Content`)로 시간을 먼저 쓴다.
이 세션 1차 probe가 그 때문에 **exit 124**로 죽었고, 180s로 재시도하니 exit 0(정상 추론).
→ orchestrator.md의 "probe 타임아웃(exit124)도 codex 불가로 간주"를 그대로 적용했다면
**멀쩡한 codex를 버리고 단일소스로 격하**했을 것(교차검증 손실).

---

## B. 하네스 규칙 보강 후보 (orchestrator 결함)

### B1. [핵심] 체크포인트/메모의 계약 문구를 **레이어 소유자 확인 없이** 하위 에이전트에 주입했다
직전 체크포인트 표에 `E4 → humanSummary에 '(타겟 위키 무변경)' 유지`라고 적혀 있었고,
그대로 codex의 RED 작성 지시에 넣었다. 그런데 실제로는:
- `importWiki`는 **중립 reason만** 반환(`src/main/wiki-migrator.js`에 humanSummary 0건)
- 그 문구의 소유자는 **migrate-builder의 `WIKI_REASON_TEXT`**
→ `result.humanSummary`를 단언하는 **GREEN 불가능한 RED**가 작성됐다. 7.7이 critical로 잡아서 회수.
**보강 제안**: 계약 문구(필드명·메시지·shape)를 하위 에이전트에 주입하기 전,
**"그 필드를 어느 레이어가 소유하나"를 1회 grep**한다. 비용 grep 1회 << 7.7 라운드 1회.
기존 `§0④ 데이터 전제 검증`의 **레이어 축** 확장으로 볼 수 있다(외부 데이터뿐 아니라 **내부 소유권**도 전제다).

### B2. 대상 에이전트 도구셋 미확인 — tester-design에 실행검증을 요구했다
`tester-design` 도구 = Read/Glob/Grep/Write/Edit. **Bash 없다.**
그런데 프롬프트에 `node --check` + `npx vitest run` 자가검증을 요구했다.
에이전트가 정직하게 "실행 불가"를 보고해 grep 자가증명으로 대체했고, 실행검증은 별도 tester-backend로 갔다.
**보강 제안**: `playbook-delegation.md`에 이미 도구셋 확인 룰이 있는데 **Read 트리거가 "계약 freeze / 사망"뿐**이라
평상시 위임엔 안 걸린다. → **"에이전트에 실행·검증을 요구하기 직전"을 트리거에 추가**.
현재 룰의 developer-* 예외 서술(`developer-frontend는 Bash 자체가 없다`)을 **tester-design까지 확장**.

### B3. `general-purpose` 서브에이전트 타입이 실제로는 없다
Agent 도구 설명은 "subagent_type 생략 시 general-purpose"라고 하지만, 이 프로젝트 레지스트리엔 없다
(가용: code-reviewer / design-reviewer / developer-* / finalizer / planner-* / tester-*).
워크스루 브리핑(read-only 신선 컨텍스트)을 general-purpose로 발사했다가 실패 → code-reviewer로 재발사.
**보강 제안**: orchestrator.md 워크스루 6단계의 "fresh read-only 서브에이전트" 서술에
**실제 사용할 타입을 명시**(read-only 용도 = `code-reviewer`, 단 "리뷰 아님·지도 그리기"를 프롬프트에 명시).

---

## C. 잘 작동한 것 (유지 근거 — 축소 금지)

- **7.7 품질게이트가 orchestrator 자신의 프롬프트 결함(B1)을 잡았다.** 게이트가 없었으면 GREEN 불가 단언이 남았다.
- **모델 실측(사후 transcript)** 2회 수행, 둘 다 `claude-fable-5` 확인. 자기보고(`perPersona[].model`)에 안 기댐.
- **교차검증 2소스**: code-reviewer blocking 0 ↔ codex blocking 1 + major 2. 3건 전부 코드대조로 기각/백로그했지만
  **한쪽만 돌렸으면 검토 자체가 없었다.** 특히 codex는 지시받은 `p3` 스코프아웃 grep을 안 하고 지적했다
  (설계 인지 항목을 결함으로 올림) → **findings 타당성 1차 게이트가 필수임을 재확인**.
- **워크스루 3.5 RED 기준선 대조**가 "삭제단언 0 / skip마커 0"으로 **약화 vs 정당한 교정**을 정확히 갈랐다.
  이번엔 `S-CLEARFAIL` 신설로 커버리지가 **증가**한 케이스였고, 개수만 봤으면 오차단했을 것.
- **codex 대량작성 분할**: 단일파일 45케이스는 사망, 9건/5건 분할은 둘 다 완주(exit 0).
- **developer의 out-of-scope 신고를 신고자 우위로 다루되, 판정은 orchestrator가 직접 코드대조**(A3가 그 사례 —
  developer 사실관계는 맞았고 판정만 뒤집혔다).
