# Playbook — TDD 합의 구간 (신규기능·고복잡도 트랙 전용)

> **분리 문서** — `orchestrator.md`에서 추출(v3.2.0). 신규기능·고복잡도 트랙에서 사용자 승인 후, developer 호출 전 구간 상세. 해당 트랙 진입 후 orchestrator가 이 파일을 Read한다.
> **버전 동기 대상**: 7a~7.7 시퀀스·게이트·codex 폴백 연동 변경 시 이 파일도 갱신한다. finalizer bump 의식의 "분리 문서 정합성 점검"이 강제. (codex 실패 신호·타임아웃·백스톱은 orchestrator.md `## codex 호출 가드`가 SSOT — 여기서 재서술 안 함.)

---

사용자 승인 후, developer 호출 전에 아래 순서로 TDD 합의를 진행한다.

## 7a∥7b — 테스트 케이스 병렬 산출
- **7a**: tester-design → 케이스A 산출
- **7b**: codex → 케이스B 산출 (rule 경로 주입 필수)
  - codex 실패 시 claude(tester-design) 폴백 (실패 신호 정의·재시도 상한·무한대기 백스톱은 orchestrator.md `## codex 호출 가드`)
- 7a와 7b는 병렬 호출한다.

> codex 미가용 폴백 시 7a∥7b 교차검증은 불성립한다. 산출물에 `⚠ 교차검증 없음 (codex 미사용, 단일 소스)`를 명시하고, 7.7 tester-quality 호출 시 '단일 소스' 컨텍스트를 전달해 더 엄격히 판정하도록 한다.

## 7c — diff 합의
| 구분 | 처리 |
|------|------|
| A∩B (양쪽 동일) | 자동 채택 |
| 차집합 (한쪽에만 존재) | 합집합 기본 채택. 상충하지 않으면 토론 없이 통과. |
| 상호배타 (논리적 충돌) | 사용자에게 판단 위임 |

차집합 토론 상한: 최대 2왕복. 초과 시 합집합 채택.

## 7c.1 — 승인된 패널 major 잠금 (RED 케이스 필수 매핑)

사용자 승인 화면에 노출돼 **승인된** 설계패널 major 항목(비차단이나 완료정의의 일부)을 7c 합의 케이스에 **필수 잠금**한다.
- orchestrator가 승인 major 목록을 추출해 7c 케이스 체크리스트에 주입 — **각 major → 최소 1 RED 케이스** 매핑 강제.
- 7a∥7b 산출이 흐름 diff만 보고 major refinement를 놓치는 누락 방지(major가 RED로 안 실리면 GREEN 통과 후 /review가 blocking 적발 → 재작업).
- **major 유형 분기 (단위검증 가능성)**: 'major→RED 1개' 강제는 **단위테스트로 행위 검증 가능한 major**에만 적용한다.
  - **단위검증 가능 major** → RED 케이스 필수 잠금(위 규칙 그대로). 7.7이 RED 부재를 critical 취급.
  - **config/배선/통합 major**(단위 RED로 행위 커버 불가 — 예: allowedDeployRoot 전사, bean wiring, 외부설정 전달): RED 락 대신 **① 구현 위치 명시(어느 파일·메서드에 배선) + ② /review 체크리스트 항목**으로 추적한다. 7.7은 이 유형에 RED 부재를 critical로 치지 않는다 — '주석-대신-구현' 갭은 /review가 본다.
  - 근거: config major를 단위RED로 락하면 '미설정시 차단'만 검증돼 developer가 값 전사를 주석만 달고 미구현해도 RED PASS → GREEN 후 /review P1 적발 → 재작업(2026-06-22 M7 allowedDeployRoot).
- 7.7 품질게이트가 이 매핑 커버리지 확인(승인 **단위검증 가능** major 중 대응 RED 없는 항목 = critical 취급, 작성자 반환. config/배선 유형은 구현위치+/review 추적 여부로 확인).

## 7c.2 — 스키마·계약 변경 시 영향 테스트 인벤토리

7c 합의에 **기존 함수의 반환 shape·동작계약을 바꾸는** 항목이 있으면, 7.5 RED 작성 전에 **영향 테스트 전수 인벤토리 1회**를 강제한다(stale 테스트 사전 식별 — GREEN/변경검증/리뷰서 라운드마다 발견되는 루프 낭비 차단).

> **이건 단순 grep이 아니라 "계약 파급 분석"이다.** stale 인벤토리 불완전이 6회 재발한 공통 뿌리 = **한 축(바뀐 값 문자열·단언)만 보고 계약 파급 전체를 안 봄**. 변경된 값은 **양면**으로 테스트에 박혀 있다 — ① 그 값을 **단언(assert)**하는 테스트 + ② 그 값을 **생성/유발하는 입력(픽스처·mock seam·호출 edge)**을 쓰는 테스트. 아래 부류는 그 양면의 구체 사례지 닫힌 목록이 아니다 — 새 계약변경마다 "이 값을 단언하는 곳은? 이 값을 만드는 입력을 쓰는 곳은?" 둘 다 grep한다.

인벤토리 대상 네 부류 (변경이 기존 테스트를 깨뜨리는 축 — 양면: 단언측 + 생성/입력측):
- **가산 변경**(반환에 필드 추가): 변경 함수 반환값을 **exact matcher**로 잠근 **모든 기존 테스트**를 grep 전수. ⚠ **matcher 시맨틱 정확 인지**(planner/tester-design이 "subset이라 안 깸"으로 6회 오판한 뿌리): `toEqual`·`toContainEqual`·객체리터럴 직접대조 = **exact key-count**(가산필드 시 전부 깸), `toMatchObject`·`objectContaining` = **subset**(가산 안 깸). 특히 `toContainEqual({...})`는 배열요소 **exact deep equality**라 가산필드에 깨진다(`toContain`과 다름). 예: `grep -rn "toEqual\|toContainEqual" test/` + 변경 함수 호출처.
- **동작계약 변경**(severity/status 산출규칙·타임아웃 등 상수값·early-return/skip 조건): 그 **동작·값을 단언하는 기존 테스트**를 전수 grep. 예: 상수 `600`→`900`이면 `600`을 단언한 테스트, "error→warn" severity 격상이면 옛 severity를 단언한 테스트.
- **신규 의존 edge**(변경 모듈이 **새로운 외부 함수/모듈을 호출**하게 됨): 그 변경 모듈을 로드하면서 해당 의존을 `vi.mock`/`vi.doMock`(또는 Mockito) 팩토리로 가짜화한 **모든 기존 테스트**를 grep → 팩토리에 신규 함수 stub(`vi.fn().mockResolvedValue(기본값)` 등) 추가를 일괄 마이그레이션. 안 하면 mock 팩토리가 신규 함수 미정의 → `undefined` 호출 TypeError로 무관 테스트가 무더기 FAIL. grep 예: 신규로 `api.X()` 호출 추가 시 → `grep -rln "vi\.\(do\)\?mock.*api" test/` + 그 파일이 변경 모듈을 로드하는지 확인. (반환 shape도 값도 안 바뀌고 **호출 edge만 추가**돼 위 두 부류 grep엔 안 걸리는 별개 축.) ⚠ **신규 함수뿐 아니라 기존 공유 mock(`makeRunner` 등)이 응답 안 하는 새 서브명령/argv도 같은 축**: 신규 헬퍼가 공유 runner mock의 **미stub 하위명령**(`merge-base`·`rev-parse`·`for-each-ref` 등 특정 argv·`.code` 분기)을 호출하면, 그 mock 쓰는 **전 케이스가 조용히 오판**(undefined→기본분기 오염)된다. → 공유 mock 쓰는 케이스 grep해 새 argv 응답 stub을 **단일 passthrough 헬퍼**(dir prefix 분리)로 1회 일괄 보강. 근거: PR-F3 메타 시드가 `judgeFf`(merge-base `.code` 판정) 신규 호출 → `makeRunner` 미stub → 48 케이스 전부 'diverged' 오판 한 라운드 통째 FAIL.
- **값-생성 픽스처/트리거**(enum·상태플래그 산출규칙이 바뀜 — ②생성측): 바뀐 값을 단언하진 않지만 그 값을 **유발하는 입력 픽스처/조건**을 써서 결과를 **간접 단언**(충돌 카운트·UI 존재·분기 동작 등)하는 테스트를 전수 grep. 위 부류들이 ①단언측(바뀐 값 문자열)을 잡는다면 이건 ②생성측이다 — 변경 분기를 트리거하는 **입력 필드값**으로 grep. 예: detect enum `BRANCH_EXISTS`→`FF_PENDING` 변경 시, `'BRANCH_EXISTS'` 단언 grep만으론 `branchExists: true` 픽스처로 충돌을 유발하고 `conflicts` 카운트/rename 입력만 단언한 테스트를 놓침 → 입력측 `grep -rn "branchExists:\s*true" test/`도 전수. (값 문자열이 단언에 안 보여 ①측 grep에 안 걸리는 별개 축.)
- **시그니처/위임 전환**(호출처 + 사라지는 책임): ① **생성자/메서드 시그니처 변경**(필드·파라미터 추가/DI 변경) → 그 생성자·메서드를 호출하는 **모든 기존 테스트** grep(컴파일 깨짐·stale setup 사전식별). ② **기존 호출경로를 다른 컴포넌트로 위임/대체 전환** 시, 대체되는 메서드가 수행하던 **부가책임**(예: `resolveTargetFiles`의 JAR 다중배포 확장)을 신경로가 보존하는지 인벤토리 — 위임이 "주 동작"만 옮기고 부가책임을 빠뜨리는 회귀를 RED로 선잠금(안 하면 변경검증 GREEN 후 review서야 blocking 적발). 근거: AutoPatchCommands 생성자 2필드 추가 stale 마이그레이션 라운드 + resolveTargetFiles JAR확장 책임소실 codex review blocking(2차 수정). ⚠ **grep 카운트는 하한이다** — ripgrep이 비-UTF8 바이트 섞인 파일을 binary 오탐해 **무음 제외**할 수 있다([[grep-binary-misdetect-touch-surface]], WI-C 11≠12파일 실측). 인벤토리 후 `mvn test-compile` 1회로 실컴파일 에러 유무를 봉인한다(컴파일이 진실).
- **교차파일 + multi-entry**(grep 스코프 함정 — 격상 후 재재발 축): ① **변경 테스트 파일에 국한 금지** — 같은 계약(반환 shape/store path/mappings)을 단언하는 테스트는 **다른 spec 파일**에 산다. grep 스코프는 항상 `test/`·`unit/` **전체 트리**(변경한 그 테스트 파일 내부만 보면 놓침). 예: `import-mapping.js` 계약변경이 `import-mapping.test.js` **밖** 다른 spec의 `toEqual(mappings)` 5필드 고정을 깸(PR-S2). ② **multi-entry 케이스**: 거동변경이 **여러 항목 중 일부만** 트리거하는 테스트(예: multi-sub — subA는 `BRANCH_EXISTS→DIVERGED` 거부, subB는 ff push)는 단일 케이스 grep에 안 보인다 — 한 테스트가 여러 입력을 루프할 때 그중 변경분기를 타는 항목을 본다(PR-F2 D3-19, 7c.2 격상 후 누락 재발).
- **출력 위치/경로 이동**(산출 파일을 만드는 디렉터리·경로 변경 — read-side 축): 단언측·생성입력측 외에 **그 산출물을 읽는 기존 테스트**(헬퍼의 read 경로 포함)를 전수 grep한다. 파일 출력 위치가 parentDir→subDir로 바뀌면, 옛 경로를 read하던 테스트 헬퍼(`readExcludedReport()` 등)가 stale로 늦게 터진다(값 단언이 아니라 **파일 경로 read**라 위 단언측 grep에 안 걸리는 별개 seam). 예: `grep -rn "_excluded_files\|_error_files" test/` + 그 경로를 조립하는 헬퍼. 근거: flow2 리포트 경로 이동 → `GitExportOrchestratorIgnoreTest` read 헬퍼 stale → 변경검증 14 FAIL 한 라운드(2026-06-30).
- **신규 리셋/클리어/상태-게이트 헬퍼 ↔ 인접 조건부 부수효과 (side-effect 상호작용 축 — 값 변경 아님)**: 새 리셋/클리어/게이트 헬퍼(`_resetXState`·onChange `if(changed)` 게이트 등)를 도입하면, 그것이 건드리는 **모든 상태 키·DOM 셀렉터**를 나열하고 **그 각각에 이미 작용하는 다른 조건부 코드**(prefill·소유권 clear·다른 게이트)를 grep 열거한다. 신규 헬퍼의 게이팅이 그것들과 **일관**한지(순서·조건 동일) 확인 — 3결함 클래스 차단: (a) **순서 의존**(리셋이 prefill 이후 실행돼 방금 채운 값 wipe), (b) **이중 효과**(무조건 clear가 이미 소유권 조건 `!isCrossLike`로 처리하는 블록과 겹쳐 보존 계약 위반), (c) **partial no-op**(일부 필드만 `if(changed)` 게이트 안, 나머지는 밖 → 같은-그룹 재선택에 절반만 실행). 위 부류들이 '값/shape 변경이 기존 테스트를 깸'이면 이건 '신규 부수효과가 인접 부수효과와 충돌'하는 별개 축(값 불변, 상호작용 결함). 근거: repostitch STEP3 mode-reset 한 세션 3회(A 순서·C 이중=tester FAIL 22 / cbTargetMeta partial=codex review critical, tester-GREEN 이후).
- 영향 테스트는 tester-design이 **일괄 마이그레이션**(신계약 기대값, 검증의도·exact 보존). piecemeal(라운드마다 1건씩 발견) 금지. developer는 테스트 못 고침(hook) → 마이그레이션 주체 = tester-design(작성자≠구현자 유지).
> 근거: exact-match 단언은 가산 스키마에, 값/규칙 단언은 동작계약 변경에 깨진다. 사전 인벤토리 없이 구현하면 라운드마다 stale 발견돼 루프 낭비. failure_2026-06-15·PR-D1 stale 14건·2026-06-21 E7-04(severity 격상)·git-runner 600s(상수변경)·PR-S1 mock 팩토리·PR-F1 branchExists 픽스처 3건·PR-S2 cross-file `toContainEqual`·PR-F2 D3-19 multi-sub 재발(stale-인벤토리 불완전 9~10회 — 단언측만·변경파일 내부만·matcher 시맨틱 오판이 공통 뿌리).

## 7c.3 — 경계 반환 shape 계약 (mock이 양끝을 끊는 거짓 GREEN 차단)

7c 합의에 **IPC/RPC/모듈 경계의 반환 shape를 신설·변경하는** 항목(예: Electron `ipc:*` 핸들러, preload 브리지, api 래퍼), 또는 ① **백엔드 DTO→프론트 소비 필드 계약**(`toDto()`가 소비자 읽는 필드를 채우나) ② **신규 정책/설정 객체가 런타임 실행 경로에 실배선되나**(`empty()`/no-op 고정 아님) 항목이 있으면, 7.5 RED 작성 전에 **양끝 단언 일치**를 1회 강제한다. 7c.2가 보는 "stale 기존 테스트"·"mock 팩토리 함수목록 완전성"과 **다른 축**(이건 신규 계약의 producer↔consumer shape 일치).

- 문제 메커니즘: IPC 반환 shape는 **핸들러 → preload → api 래퍼 → 소비부** 여러 홉이 일치해야 한다. 각 단위테스트가 자기 옆 경계를 mock으로 끊어(예: api를 `string[]`로 직접 mock) 검증 → producer가 `{ok:true, branches}` wrapper를 줘도 consumer가 raw array를 기대하는 **shape 불일치가 단위에 안 잡히고 GREEN 통과** → 리뷰/E2E·실배선에서야 적발(라운드 낭비).
- 강제 체크 (둘 중 하나 이상):
  - **양끝 동일 단언**: 신규/변경 경계의 반환 shape를, **producer 측(핸들러 반환)과 consumer 측(소비부 기대) 양쪽에서 동일 shape로 단언**하는 RED가 있는지 확인. consumer 테스트가 mock으로 producer와 **다른 shape**를 주입하면 그 mock이 실 핸들러 반환과 일치하는지 1줄 대조. **반환 shape뿐 아니라 입력 형태도 동일**: consumer 테스트는 producer가 실제 생산하는 형태(production 입력) **그대로** 주입한다(테스트 편의형 금지). producer 계약 테스트(예: renderer가 `shortName` 생산)가 있으면 consumer 테스트도 **같은 형태**(shortName)로 최소 1 e2e 케이스 — 편의상 다른 형태(fullRef) 주입하면 consumer의 재조립 분기가 미실행돼 production 버그가 GREEN으로 가린다. 근거: PR-F3 renderer `metaPushBranches=shortName`('main') 생산 ↔ metaFfPush 테스트 전부 `fullRef`('refs/heads/feat') 주입 → shortName 미처리 = 모든 branch선택 import 실패 production 버그를 /review가 적발(TDD 미탐, 회귀가드 F3-M16 사후).
  - **신규 필드/핸들러 추가 시 전 홉 운반 + deps 실주입 e2e**: IPC payload·DTO에 신규 필드를 더하면 producer 화이트리스트(`_updateMappings`류 payload 출력)·매핑이 그 필드를 실제 운반하는지, 신규 핸들러가 main.js `registerHandlers` deps에 실주입됐는지 end-to-end 1케이스로 검증한다. consumer 테스트가 payload를 우회해 runImport 직접호출하거나 deps를 직접 mock하면 배선 seam이 가려져 dead-feature가 GREEN 통과 → /review 교차파일 추적에서야 적발. config/배선 major는 7c.1대로 구현위치 명시+grep 병행. 근거: repostitch WS1(renderer payload 화이트리스트가 gitlinkCarried/Sha drop→carrier push 死)·WS2(main.js previewFf deps 미주입→ipc 항상 미구현). ⚠ **store/전역 상태 필드도 동일**: 테스트가 `store.X`를 직접 주입하면 그 필드를 채우는 producer 배선(빌더·업데이트 경로)의 공백이 GREEN에 숨는다 — 필드 직접주입 케이스는 그 필드 producer 배선 존재를 별도 케이스로 잠근다. 근거: repostitch CC-2 `store.importCfg.targetMeta` 직접주입→_buildCfg 직독→메타타겟 UI 배선 공백.
  - **기본 UI 상태가 만드는 미검증 조합(단일→다중) probe**: default all-checked/selected 등 기본 UI 상태가 픽스처보다 넓은 입력을 만들면(단일-db `['main']` 픽스처 ↔ 기본 다중브랜치 전체선택), 그 넓은 조합이 트리거하는 분기(비-db 브랜치 .gitmodules/gitlink 재작성 등)를 케이스 열거서 명시 probe한다. 단일값 픽스처만 쓰면 기본상태 조합이 TDD 전단계(7a/7b 열거·7.6·7.7·변경검증) 미탐→/review adversarial만 적발. 근거: repostitch B1 default all-checked 다중브랜치 CB-MULTI-BRANCH 사후 회귀잠금.
  - **프론트-백 REST 계약 (URL·DTO 필드 동결 spec 단일출처)**: 프론트/백을 각자 mock한 단위 GREEN은 실 HTTP 계약(REST 라우트 URL·DTO 필드명·JSON key) 미검증(양쪽이 경계를 각자 가짜화). 신규/변경 REST 표면은 ① 컨트롤러 라우트 URL ↔ 프론트 api 호출 URL 문자열 대조 1케이스 ② DTO 필드명·JSON key를 **동결 feature 문서 단일출처**에서 양쪽 동일하게 잠근다(백엔드가 spec 위반 필드명 못 내게). 변경검증에 경량 대조(라우트↔api URL, DTO 필드↔프론트 타입) 1스텝. 근거: web-export 백30/프론트90 단위 GREEN인데 /codex review·code-reviewer 계약불일치 blocking 3건(status URL·CommitDto 필드·IDOR).
  - **계약 테스트 1건**: 경계마다 mock이 아닌 **실 핸들러 반환값 1건을 고정**(contract test)해 wrapper vs raw를 못 갈리게 잠근다.
  - **DTO→소비자 필드**: 백엔드 `toDto()`/응답 매핑이 **프론트가 소비하는 필드(목록 `.length`·렌더 키 등)를 non-null로 채우는지** 단언 1건. (`rules` 미설정 → DTO=null → 프론트 `.length` 크래시·항목 전멸이 단위 GREEN을 우회.)
  - **정책/설정 런타임 배선 + 스프링 통합계약**: 신규 정책/설정(예: IgnorePolicy)이 **실행 모듈에 실주입돼 동작에 반영되는지** 통합 케이스 1건. 모듈이 `Policy.empty()`/no-op 고정이면 등록 규칙이 무력화(단위는 정책 객체만 보고 GREEN). 혼합(백+프론트) 트랙서 특히 강제. **변경 표면이 스프링 빈 배선(@Component/@Service 등록)·외부 설정값 바인딩(@Value/@ConfigurationProperties)·auth 헤더 전달·컨트롤러↔서비스 계약을 건드리면 동급**: ApplicationContext 로드 + 해당 빈 등록/설정 non-null 주입/auth 전달을 **L1 통합 케이스 1건**으로 잠근다. ⚠ 이건 config를 단위RED로 잠그는 게 아니다(7c.1이 금지하는 축 — '미설정시 차단'만 검증돼 주석-대신-구현 거짓GREEN) — **기동·실주입 자체를 통합레벨로 단언**하는 별개 축. 모듈이 no-op 고정이거나 빈 미등록이면 단위 GREEN을 우회하고 변경검증 통합 단계에서야 터진다(LOOP 낭비). 근거: DEVUNIT-authpatch extdep-phase1 단위RED 스켈레톤 GREEN 후 변경검증서 @Component누락·settings빈값·auth·계약불일치 다수 LOOP 다회전(2026-07-02).
- 산출: planner-*(IPC 계약 명세)가 신규/변경 채널의 반환 shape를 producer↔consumer 양끝 표기 → tester-design RED가 그 shape를 양끝 단언. (mock 우회로 한쪽만 통과시키는 거짓 GREEN을 TDD 단계서 차단.)
> 근거: repostitch PR-S1(`ipc:searchBranches` wrapper vs raw array, mock 우회 GREEN→리뷰 적발), PR-D2/D4 payload 필드누락(mock 우회), 실버그 bc303a7(renderer→IPC `submodules` 필드 누락, mock 직접주입 통과→실배선만 적발). DEVUNIT-authpatch F1(ExportModule `PatchIgnorePolicy.empty()` 고정→DB ignore 규칙 export 런타임 미적용)·F2(`toDto()` rules 미설정→DTO null→프론트 크래시) codex+code-reviewer 2소스 적발, 회귀잠금 EM-POLICY-01/02·TPL-DTO-RULES-01/02. applied/20260622T063542Z(mock 팩토리 함수목록 완전성)와 다른 축.

## 7c.4 — plan 신규/변경 헬퍼 시그니처 = 픽스처 단언 SSOT (mock seam이 plan 계약과 갈리는 거짓 수렴 차단)

7c 합의/plan에 **신규·변경 헬퍼·함수 시그니처**가 있으면(예: 신규 `judgeFf` 도입, 기존 호출의 인증경로 전환), 그 **정확 계약을 픽스처가 SSOT로 잠근다**. 계약 = ① **어느 메서드로 호출**되나(예: `runner.run`=PAT 인증 vs `runner.runPlain`=비인증) ② **인자 순서·필수 플래그**(`-C dir`·subcommand 순서) ③ **인자 값 출처**(remoteUrl=`repo.httpUrl` vs `sub.oldUrl`) ④ **반환 shape**. 7c.2(stale 단언)·7c.3(producer↔consumer shape)과 **다른 축**: 이건 **tester-design이 고를 mock 캡처 seam(어느 메서드를 가로챌지)이 plan 계약과 일치하는가**.

- 문제 메커니즘: tester-design이 mock 캡처 경로를 **자기 멘탈모델로** 선택(fetch를 `runPlain`서 캡처) → plan 계약(`run`=PAT)과 갈림. developer 목표는 "RED 픽스처를 GREEN으로" → plan 아닌 **틀린 픽스처에 수렴** → 프로덕션서 PAT 미주입 등 **런타임 버그**. 작성자(tester)≠구현자(developer) 분리는 지켜도 **둘 다 plan을 SSOT로 안 보면** 같은 오류로 수렴 가능.
- 강제 규칙:
  - **plan이 SSOT**: 픽스처 mock seam·인자·반환이 plan 시그니처와 다르면 **plan이 이긴다**(픽스처를 plan에 맞춰 재작업, 추측 금지). orchestrator가 7.5 위임 시 plan의 신규/변경 시그니처(메서드 종류·인자순서·플래그·URL·반환shape)를 **명시 주입**한다.
  - **보안·런타임 임팩트 메서드 선택 특히 고정**: 인증 경로(`run`=PAT vs `runPlain`=비인증)·권한·트랜잭션 경계처럼 메서드 선택이 프로덕션 거동을 가르는 경우, 픽스처가 plan이 지정한 정확한 메서드를 캡처하는지 1줄 대조(틀린 seam = 프로덕션 인증/권한 버그).
  - **mock이 실 producer를 대신하면 계약테스트 1건 필수**: 코어가 소비하는 값을 mock(정형 `{id,name}` 등)으로 고정하는 곳마다, **그 mock shape ↔ 실 매퍼/어댑터 출력을 잠그는 계약 테스트**를 둔다. mock 정의만 freeze하는 건 불충분 — 실 producer가 `raw.id`를 버리거나 `{username}`만 반환해도 mock은 정형이라 게이트가 못 본다. ⚠ 계약테스트는 **실 producer를 구동**해야 한다 — mock 하드코딩 값을 자기 자신과 비교하면 tautological(공허). `R2` absence-pair의 계약테스트판.
  - 게이트 연결: 7.6 RED sanity / 7.7 품질게이트서 "픽스처가 호출·캡처하는 헬퍼 시그니처가 plan과 일치하나 + mock 대체 경계에 실물 계약테스트가 있나" 1줄 확인. 불일치면 작성자(tester-design)에게 반환.
  - 근거: tracker-migration blocking 4건 공통뿌리(매퍼가 id 버림→코어 최소-id 무효, lookupUser가 username만→GitLab 400). 방어책 TM-SEAM-1조차 실 어댑터 안 부르고 자기참조 비교=tautological로 나와 tester가 재작성.
> 근거: repostitch PR-F2(`judgeFf` fetch를 plan은 `run`(PAT)·`-C dir`·`repo.httpUrl`로 명시했으나 픽스처가 `runPlain`(비인증)·`sub.oldUrl`로 캡처→기존 branch 서브모듈 전부 거짓거부 잠재버그. 변경검증 9-FAIL + 2소스 리뷰 + orchestrator src diff Read(receiving-code-review) 3중 적발). recurring-test-lessons #2(mock/real divergence), PR-S1 IPC shape 불일치와 같은 뿌리(mock이 실 계약 우회).

## 7.5 — RED 테스트 작성 (codex, public 행위 기준)

codex가 7c 합의 케이스를 기반으로 RED 테스트를 작성한다.
- 테스트는 **public 행위 기준** (내부 구현 검증 금지)
- **작성자(codex/tester) ≠ 구현자(developer)** 원칙 엄수
- codex 실패 시 tester-design 폴백 (실패 신호 정의·무한대기 백스톱은 orchestrator.md `## codex 호출 가드`)
- codex 호출 시 rule 경로 주입 필수
- **RED 보안/negative 규칙(R1~R8) + 외부 API DTO JSON round-trip 규칙 주입 필수** — codex가 작성자일 때도 `tester-design.md`의 `## RED 보안/negative 테스트 규칙`을 컨텍스트로 전달한다(공허 단언 방어).
- **테스트 인프라 임의 신규 도입 금지 — 기존 통과 테스트 부트스트랩 복제.** 빌드 부트스트랩·테스트 컨텍스트(예: 인메모리 DB H2·테스트 프로파일)를 임의로 새로 들이지 말고, 기존 통과 테스트의 부트스트랩을 복제한다. 새 인프라 임의 도입은 7.6 sanity 불통과를 유발한다. 근거: web-export H2 임의도입 7.6 LOOP 2회.

## 7.6 — RED sanity (컴파일 + RED 실행 검증)

7.5 완료 후, 7.7 품질게이트 전에 반드시 실행한다. **tester-design은 Bash가 없어 "구성상 RED"만 만들 수 있으므로**, 실제 컴파일·실행을 한 단계 앞에서 확인해 컴파일 깨진 스위트가 7.7을 통과해 8/tester-backend에서야 터지는 것을 막는다.

- 실행 주체: **tester-backend**(Bash 보유 + 테스트 파일 미편집 — 작성자≠검증자 유지). `mvn test-compile` + RED 1회 실행.
- 통과 기준: **① 컴파일 OK** + **② RED가 "올바른 이유로" FAIL**(미구현 도메인 동작에 의한 단언 실패/도메인 예외). 컴파일 에러, 매처 오용(primitive에 `any()`), `@BeforeEach` 팩토리 seam 미사용, `UnsupportedOperationException` 같은 "잘못된 이유"의 FAIL은 **불통과**.
- ⚠ **(A)류 컴파일에러가 (B)류를 가린다**: 미구현 심볼 부재(A류, greenfield 정상)가 **module-wide test-compile을 멈추면**, 같은 파일의 테스트 자체 결함(B류: `throws` 누락·잘못된 import·문법)이 **애초에 리포트되지 않는다**. A류로 컴파일이 멈추면 → **신규 테스트 파일을 미구현 심볼 미참조 부분부터 단독/부분 컴파일**하거나 **javac 문법검사(체크예외·import)를 별도 수행**해 B류를 노출한다. 정적 검토만으론 놓친다. 근거: trackA LOOP2 `throws Exception` 누락이 A류에 가려져 GREEN 단계서야 발견(test-compile 전체 차단).
- 처리:
  - 통과 → 7.7 진행.
  - 불통과 → **작성자(codex/tester-design)에게 반환해 재작성** [LOOP n/3, 7.7과 루프 카운트 공유]. 컴파일/셋업 결함 종류를 명시해 반환.
- codex 미가용 폴백(claude 단일 소스)이어도 7.6은 동일 수행(오히려 단일 소스라 더 필요).
- **greenfield(신설 클래스 — prod 미존재) 처리**: 신설 클래스는 prod stub이 없어 RED가 GREEN 전 컴파일 불가 → 7.6 선검증이 구조적으로 막힌다. 이때 **developer가 GREEN 전 최소 prod stub(public 시그니처만, 미구현)을 먼저 생성**한다(2단계: stub → 7.6 → GREEN). ⚠ **엔티티 @Column 추가(스키마 변경)가 있으면 stub 단계에 DDL(신규설치 스키마 + 증분 마이그레이션)도 함께 반영** — `ddl-auto=validate` 환경서 @SpringBootTest RED가 context 로드하려면 컬럼 선존 필요(stub=시그니처+DDL). 미반영 시 `Schema-validation: missing column`으로 "잘못된 이유" FAIL 1왕복. 근거: CI joblog 세션 7.6 백엔드 DDL 갭(2026-07-21).
  - stub은 **benign 기본값 반환**(null/빈 컬렉션/false 등). `UnsupportedOperationException`·throw 금지 — 그건 7.6 ②의 "잘못된 이유 FAIL"이 된다. RED가 stub의 benign 반환에 대해 **단언 실패(올바른 이유)**로 FAIL해야 7.6 통과.
  - 경계 유지: stub=prod라 developer 소유(작성자≠구현자 불변 — 테스트는 여전히 codex/tester-design). developer는 7.6 통과용 시그니처만 만들고 실제 로직은 8(GREEN)에서 채운다.
  - 7c 합의서 freeze된 public 시그니처를 그대로 stub에 쓴다(추측 금지). prod가 일부 존재하면 그 시그니처를 Grep해 정합(시그니처 불일치 컴파일에러 사전차단).
  - 근거: greenfield서 7.6 생략 시 setup 결함(시그니처·픽스처·stub)이 병합 후 tester-backend서 라운드당 1건씩 노출(2026-06-22 authpatch 6+회전 × run 3~13분). stub 선생성으로 컴파일·구조 결함을 GREEN 전 1회에 수렴.
- **프론트(vitest) RED sanity는 backend 대칭 게이트 단계다** — 프론트 spec 변경/신설이 있으면 **tester-frontend가 vitest RED 1회 실행**(컴파일 + "올바른 이유" FAIL 확인)을 backend `mvn test-compile`+RED와 동일하게 수행한다. 생략하고 7.7→GREEN→변경검증 직행 금지(컴포넌트 의존 mock 누락이 늦게 터짐). 실행은 **파일 전체를 describe 순서대로**(단일 describe·`-t` 격리 단독 금지) — cross-describe 누출(`vi.doMock`·모듈 내부상태·DOM 잔존)은 순서 실행서만 FAIL. 상세는 `tester-frontend.md`.
  - **모달/오버레이 spec 선점검 체크리스트**(greenfield 모달 공통 재발): ① 마운트 대상이 `<Teleport>`/BaseModal 래핑이면 `mount(..., { global: { stubs: { teleport: true } } })` — 아니면 `wrapper.find()`가 empty. ② 자식 컴포넌트가 `onMounted`에 실 API 호출하면 그 api를 mock — 아니면 loadError alert 충돌로 RED가 "잘못된 이유" FAIL. 근거: BaseModal teleport·IgnoreRuleSection ignoreApi 변경검증 2라운드(2026-06-30).

## 7.7 — 테스트 품질 게이트 (tester-quality)

7.6 통과 후, developer GREEN 구현 전에 반드시 실행한다.

| 작성자 | 검증자 | 교차 원칙 |
|--------|--------|---------|
| codex (7.5 정상) | tester-quality(claude — **fable 1순위**, 미가용 시 opus 폴백·orchestrator `## TDD 합의 구간` "7.7 모델" 참조) 호출 | 작성자≠검증자 |
| claude (codex 폴백) | 오케스트레이터가 `codex` 스킬로 교차 판정 | 작성자≠검증자 |

**rule 경로 주입 필수** (📋 0단계 확정 경로). tester-quality 호출 시 아래 컨텍스트를 전달한다:
- 7c 합의 테스트 케이스 목록
- 7.5 RED 테스트 코드 파일 경로
- 승인된 설계 문서 경로
- rule 경로
- **codex 교차판정 경로(claude 폴백분)일 때**: "trailing `// 설명` 주석(예 `// RED: 미구현`)과 주석처리된 실행라인을 혼동 말 것 — '주석처리되어 실행 안 됨' 주장 시 그 라인을 정확히 인용하고 그 라인이 `//`로 시작하는지 확인하라" 경고 주입. ⚠ **CJK 파일에서 codex의 "구문오류/미종료 리터럴/주석처리" 계열 critical은 인코딩 거짓양성 클래스** — Read 코드대조로 판정 애매(렌더 아티팩트 충돌)하면 `od -c` 바이트검사 + vitest/mvn 재파싱을 ground-truth로 판정(orchestrator `### CJK 소스 프로젝트 제약` 참조). 근거: codex가 설명주석 많은 RED 파일에서 인접 live 단언을 'commented out'으로 오인해 거짓 critical 양산(repostitch 2026-06-30, 코드대조로 전부 기각됐으나 호출·검증 비용). 게이트(코드대조)가 2차로 잡으므로 안전망은 유지.

**게이트 처리**:
- critical 0건 + 근거 명시 → 통과 → 8 진행
- critical 1건 이상 → **작성자(codex 또는 tester-design)에게 반환해 재작성** [LOOP n/3]
  - 루프 상한: 최대 3회. 초과 시 사용자에게 에스컬레이션.
  - **반환 시 동일 결함 클래스 전수 sweep 지시(첫 루프부터)**: 인용된 케이스만 고치지 말고 **모든 테스트 파일에서 같은 결함 클래스**(예: 공허 예외단언·strict stub 겹침·primitive 매처)를 한 번에 sweep하게 한다. 케이스별로 고치면 검증자가 un-scrutinized 케이스에서 같은 패턴을 재발견해 루프가 낭비된다.
  - **codex 작성분의 소규모 critical 수정(소수 라인)은 codex 재호출로 "전체 파일 재출력"을 요청하지 않는다**: codex가 직전 합의 설계를 자기 기억으로 재생성하며 회귀시킨 사례 관측(2026-06-20: `findAllByAccountId`(목록)→`findByAccountId`(단건), 빈값/모호성 가드·R1(`.isNotInstanceOf`)·바이트동일 메시지 단언 전부 소실). 대신 ① 직전 통과분(또는 첫 산출)을 베이스로 작성자측(tester-design)이 **검증자 지목 라인만 받아쓰기로 직접 적용**(작성자≠검증자 유지 — 검증자는 tester-quality), 또는 ② 재작성 불가피 시 **전체파일 아닌 unified patch-diff만** 요청하고 orchestrator가 직전 합의본과 대조해 회귀 차단. (cross-ref: orchestrator `## codex 호출 가드`.)
- 사용자는 테스트를 승인하지 않는다 — 테스트 품질은 이 게이트가 책임진다(6단계 사용자 승인은 설계 한정).

## 8 — developer GREEN 구현

- **GREEN 위임은 파일-disjoint 단위로 쪼갠다**: 한 developer 태스크에 코어 알고리즘 + kit 함수 + 다수 어댑터 함수 + 훅을 몰아넣지 마라 — 대형 단일 태스크는 탐색만으로 토큰 소진해 산출 0으로 죽는다. 파일이 겹치지 않는 배치로 나눠 위임하면 각 태스크가 완주한다. 근거: trackA developer-backend가 9함수 코어 + 2 kit + 22 어댑터 + 2 훅을 한 태스크로 받아 243k 소진·산출 0으로 사망 → 4개 파일-disjoint 배치로 쪼개니 전부 완주(재작업 0).
- developer가 7.5 RED 테스트를 통과시키는 구현 작성
- **테스트 파일 편집 금지 (기계강제)**: developer는 `<module>/src/test/**`를 수정·삭제할 수 없다. PreToolUse 훅 `block-developer-test-edit.sh`가 agent_type=developer-* + 테스트경로 Edit/Write/MultiEdit를 차단(exit 2). 테스트 약화=reward-hacking 방어(백로그 #8, 근거 ImpossibleBench GPT-5 76%). 테스트가 틀렸다고 판단되면 구현 멈추고 **설계결함(DESIGN_MISMATCH)으로 보고** → FAIL 3분기의 설계결함 경로. (알려진 구멍: Bash sed -i 우회는 v1 미차단 — 백로그 #13)
- **public 계약 준수** (co-plan/7c에서 freeze된 시그니처 변경 불가)
- **public 계약 소변경** (파라미터명·반환타입 등 마이너 조정): planner 경량 갱신 후 설계패널 스킵하고 진행
- **구조 변경** (역할·책임 재분배): planner 단계 풀 회귀 (설계패널 재실행 포함)
