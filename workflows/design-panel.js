export const meta = {
  name: 'design-panel',
  description: '설계패널: 페르소나 병렬 리뷰. findings만 생산하고 dedup·게이트 판정은 orchestrator가 한다(가드레일).',
  phases: [
    { title: 'Review', detail: '페르소나 N 병렬 리뷰 (eng는 고복잡도 시 다라운드)' },
  ],
}

// ─────────────────────────────────────────────────────────────
// args (orchestrator가 전달 — D2: 페르소나 선정·보안재스캔은 orchestrator 책임)
//   planPath   : 계획서 파일 경로 (docs/features 기능 문서, repo 상대) — 우선. 페르소나가 자기 컨텍스트에서 Read(메인 무복제)
//   planText   : planner 산출물 텍스트 (계획서 전문) — planPath 부재 시 폴백
//   repoRoot   : 작업 repo 절대경로 (선택). **세션 cwd ≠ 작업 repo면 필수** — 아래 ⚠ 참조
//   rulePaths  : ["...rules/package/tocServer/backend.md", ...]  0단계 확정 rule 경로
//   complexity : 'normal' | 'high'
//   personas   : [{ key, skillPath|null }]  skillPath 있으면 C(스킬 Read), null이면 임베드(cso)
//   topModel   : 최고위험 슬롯(eng·cso) 모델. 생략 시 'fable'.
//                ⚠ orchestrator가 직전 라운드 transcript 실측으로 fable 무음강등을 확인했으면
//                'opus'를 명시 주입한다 — 스크립트는 강등을 스스로 감지할 수 없다(아래 주석).
//   priorCriticals : [{persona, location, description}]  직전 라운드 생존 critical (재게이트 시)
//   reworkDiff     : planner가 이번에 고친 내용(diff 또는 변경 요약 텍스트)
//
// ⚠ **재게이트 초점 (v4.6.0 신설 — 그 전까지 규칙만 있고 메커니즘이 없었다)**:
//   `orchestrator.md ## 설계 패널 게이트`가 *"재실행 프롬프트에 직전 critical + rework diff를
//   넣어 ①해소됐나 ②새 결함 유발했나에 집중하게 한다"* 로 **명시**하는데, 종전 args에는
//   그 둘을 받는 자리가 **없었다**. 즉 LOOP 2가 LOOP 1과 **글자 그대로 동일한 프롬프트**로
//   돌았다(초점 0). 게다가 아래 `round > 1` 분기는 eng 내부 loop-until-dry 전용이라
//   재게이트(워크플로 재호출 → round 리셋)에는 붙지도 않았다.
//   → 규칙은 있는데 실행 경로가 없는 상태. (같은 클래스: wiki/gates-verify-present-code-only.md)
//
//   **커버리지는 불변이다** — 재게이트에도 페르소나 전원이 돈다. 줄이는 건 '무엇을 볼지'지
//   '누가 볼지'가 아니다. 페르소나 축소(직전 critical을 찾은 렌즈만 재실행)는 **기각된 설계**다:
//   1라운드 수정이 *다른 렌즈* 영역에 결함을 만든 사례가 관측됐다(백로그 2026-07-01).
//
// ⚠ **`repoRoot` — 페르소나는 소스를 cwd 기준으로 읽는다 (v4.9.0 신설)**:
//   종전 args에는 소스 읽기의 **기준점이 없었다**. orchestrator가 planPath·rulePaths를 절대경로로
//   줘도 페르소나가 *소스*(계획서가 인용하는 코드)를 읽을 땐 기준이 없어 각자 cwd로 떨어진다.
//   워크플로 서브에이전트의 cwd = 세션 cwd이므로, **세션 cwd가 stale 워크트리**면 페르소나가
//   2커밋 뒤진 소스를 읽고 "계획이 실제 코드와 불일치"라는 **confidence 10 critical을 오진**한다.
//   실사고(2026-07-27): eng critical 1건 + minor 2건이 전부 오독 산물 → orchestrator가 코드대조
//   5회로 전면 기각. 반증 못 했으면 계획서를 틀린 baseline으로 되돌리는 재작업 1라운드였다.
//   orchestrator.md가 "모든 위임에 절대경로 명시"를 요구하는데 Workflow 경유엔 **명시할 필드가
//   없던** 상태 — 규칙은 있고 배선이 없는 클래스(wiki/gates-verify-present-code-only.md).
// ─────────────────────────────────────────────────────────────
// args는 객체 기대. 일부 호출 경로에서 JSON 문자열로 도착할 수 있어 방어적 파싱.
let _a = args
if (typeof _a === 'string') { try { _a = JSON.parse(_a) } catch (e) { _a = {} } }
_a = _a ?? {}

const planPath   = _a.planPath   ?? ''
const planText   = _a.planText   ?? ''
const repoRoot   = _a.repoRoot   ?? ''
const rulePaths  = _a.rulePaths  ?? []
const complexity = _a.complexity ?? 'normal'
const personas   = _a.personas   ?? []
const topModel   = _a.topModel   ?? 'fable'
const priorCriticals = Array.isArray(_a.priorCriticals) ? _a.priorCriticals : []
const reworkDiff     = _a.reworkDiff ?? ''
// 재게이트 판정 = 직전 critical이 하나라도 주어짐. (rework diff만 있고 critical이 없으면
// 차단 사유가 없었다는 뜻이므로 재게이트가 아니다 — 초점 블록을 붙이지 않는다.)
const isReGate = priorCriticals.length > 0

if ((!planPath && !planText) || personas.length === 0) {
  return { error: 'planPath/planText 또는 personas 누락 — orchestrator args 확인', criticals: [], majors: [], minors: [], perPersona: [] }
}

const FINDINGS_SCHEMA = {
  type: 'object',
  properties: {
    persona: { type: 'string' },
    passEvidence: { type: 'array', items: { type: 'string' } }, // PASS 시 점검근거 ≥2 (lazy PASS 차단)
    findings: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          severity:       { type: 'string', enum: ['critical', 'major', 'minor'] },
          confidence:     { type: 'integer', minimum: 1, maximum: 10 },
          location:       { type: 'string' },  // plan 섹션 or file:line
          quote:          { type: 'string' },  // 동기 라인 인용 (못 하면 confidence 강등)
          description:    { type: 'string' },
          recommendation: { type: 'string' },
        },
        required: ['severity', 'confidence', 'location', 'description'],
      },
    },
  },
  required: ['persona', 'passEvidence', 'findings'],
}

// cso 계획단계 보안 렌즈 (D1=A 임베드 — plan-cso-review 스킬 부재로 불가피)
// 보안룰 SSOT(.claude/claude-security-guidance.md)를 Read해 프로젝트인지 계획비평.
// 백로그 #7a: 하드코딩 제너릭 → 프로젝트 보안룰 문서 참조로 교체(계획·코드 단계 보안기준 통일).
// 파일 부재 시 인라인 폴백 체크리스트 사용(견고성).
const CSO_LENS = `[보안 계획 리뷰 렌즈 — 계획 텍스트를 비평한다. 코드 스캔 아님(코드는 아직 없음).]
먼저 \`.claude/claude-security-guidance.md\`(프로젝트 보안 SSOT)를 Read하라. 그 1~9 카테고리 + 심각도 기준을 이 계획서 비평의 렌즈로 사용한다.
파일을 못 읽으면(미현지화·부재) 제너릭 OWASP 폴백 체크리스트로 진행:
- 인증/인가: 권한 체크 위치 명시? 인증경계(인터셉터·미들웨어·필터) 우회? 권한상승·IDOR(수평권한)?
- 입력 검증 / Injection(파라미터 바인딩 vs 문자열 조립) / XSS(출력 이스케이프·raw DOM 주입) / 경로조작 표면?
- 역직렬화: URL/외부소스 직접 역직렬화 위험? 세션/비밀 평문 노출?
- 신뢰 경계 재검증 + 감사로깅 + STRIDE/OWASP 매핑.
설계결함 수준 보안 누락 = critical. 강화 권고 = major.`

// ── 페르소나 리뷰 프롬프트 (D1: 스킬 있으면 C[Read], cso는 임베드 A) ──
function reviewPrompt(persona, round) {
  const lensBlock = persona.skillPath
    ? `[렌즈 출처] ${persona.skillPath} 를 Read하라.
  - 사용: 엔지니어링 선호 / 인지 패턴 / 리뷰 섹션 / Confidence Calibration 부분만 렌즈로 써라.
  - 무시: AskUserQuestion·STOP 게이트·plan-mode·office-hours·design-doc 체크·telemetry 등 인터랙티브 머신러리. 너는 사람과 대화하지 않는다. findings JSON만 낸다.`
    : CSO_LENS

  // 재게이트 초점 블록 — 커버리지가 아니라 '무엇을 먼저 볼지'를 지시한다.
  //   mine  = 이 페르소나가 직전에 잡은 critical → 실제 해소됐는지 검증
  //   others= 다른 렌즈가 잡은 critical → 그 수정이 **내 렌즈 영역**에 부작용을 냈는지
  // 후자가 핵심이다. 기각된 '페르소나 축소'가 놓치는 게 정확히 이 축이다.
  const mine   = priorCriticals.filter(c => c.persona === persona.key)
  const others = priorCriticals.filter(c => c.persona !== persona.key)
  const fmt = (c) => `- [${c.persona ?? '?'}] ${c.location ?? '(위치미상)'} — ${c.description ?? ''}`
  const reGateBlock = !isReGate ? '' : `

[⚠ 재게이트 — 이건 재작업된 계획서다. 아래 두 축을 **먼저** 보라]
① **직전 critical 해소 검증**${mine.length ? `(네가 잡은 것)\n${mine.map(fmt).join('\n')}` : ' — 네가 잡은 critical은 없다.'}
   각 항목이 **실제로** 해소됐는지 계획서에서 확인한다. 말로만 반영됐고 설계가 그대로면 여전히 critical이다.
② **수정의 부작용 (네 렌즈로)**${others.length ? `\n다른 렌즈가 잡아 이번에 고쳐진 것:\n${others.map(fmt).join('\n')}` : ''}
   이 수정들이 **네 관점에서** 새 결함을 만들지 않았는지 본다. 다른 렌즈의 수정이 네 영역을 깨는 건 흔하다
   (예: 동기→비동기 전환이 인증 경계를 우회시킴). 이 축이 네가 도는 이유다.
${reworkDiff ? `\n[이번 rework 내용]\n${reworkDiff}` : ''}
> 직전 라운드에 네가 이미 PASS 판정한 부분은 **재검토하지 않는다** — 위 수정의 영향권만 본다.
> 단, 수정이 그 부분의 전제를 바꿨다면 그건 영향권이다(파급을 보라).
> 이미 해소된 critical을 다시 보고하지 마라(중복 dedup 비용).`

  // 소스 읽기 기준점. 미전달 시 종전 동작(하위호환) — 단 그 경우 cwd 오독 위험은 남는다.
  const rootBlock = !repoRoot ? '' : `
[⚠ repo 절대경로 — 소스를 읽기 전 필독]
이 계획서가 인용하는 **모든 파일 경로는 \`${repoRoot}\` 기준**이다.
소스·테스트·룰을 Read/Grep할 때 반드시 이 절대경로를 prefix하라. **cwd 기준 상대경로로 읽지 마라** —
네 cwd는 stale 워크트리일 수 있고, 그러면 뒤진 소스를 근거로 "계획이 실제 코드와 불일치"를 오진한다.
경로 확인 없이 낸 불일치 지적은 confidence 4 이하로 강등하라.
`

  return `너는 설계패널의 '${persona.key}' 페르소나 리뷰어다. planner가 작성한 계획서를 너의 관점으로 비평한다.

${lensBlock}
${rootBlock}
[준수 규칙] 다음 rule 파일을 Read하고 위반을 findings로 잡아라: ${rulePaths.join(', ') || '(없음)'}

[검토 대상 계획서]
${planPath ? `${planPath} 를 Read하라(전문 필독 — 안 읽고 비평 금지).` : planText}${reGateBlock}

[출력] FINDINGS_SCHEMA(JSON). 규칙:
  - severity: critical(설계결함·게이트 차단감) / major(통과허용·승인화면 노출) / minor(기록만)
  - confidence 1~10. quote(계획서/코드의 동기 라인)를 못 달면 confidence를 4 이하로 강등하라.
  - critical 0건이면 passEvidence에 '무엇을 점검했고 왜 critical이 없는지' ≥2 항목을 반드시 채워라.${round > 1 ? `\n  - [다라운드 ${round}] 이전 라운드가 놓친 결함만 새로 찾아라. 중복 금지. 없으면 빈 findings.` : ''}`
}

// ── 계정 고갈 서킷브레이커 (v4.9.0 신설) ──
//   문제: 사망 원인이 **계정 세션 한도**면 폴백 재호출은 100% 재실패가 예정된 호출이다.
//   같은 계정이라 모델을 바꿔도 안 산다. 실사고(2026-07-27): eng·cso·devex가 한도로 죽고
//   워크플로가 재시도해 **5 failure 누적**(agent_count 6 / done 1 / error 5) — 재시도분이
//   한도를 더 태워 리셋 대기를 앞당겼다.
//   ⚠ 사유 문자열로는 판정할 수 없다: `agent()`는 실패 시 **null만** 반환하고 사유를 안 준다.
//     (회고 원안의 "failures 문자열에 한도 패턴 매칭"은 이 계약상 스크립트 층에서 불가능.)
//     → 사유 대신 **패턴**으로 판정한다: 서로 다른 페르소나 2명이 폴백까지 전멸 = 계정 층 고갈.
//     transient(단발 API 5xx)는 2명 연속 전멸로 잘 나타나지 않는다.
//   사유 기반 판정(한도 vs transient)은 journal 문자열이 보이는 **orchestrator 몫**
//   (orchestrator.md `### 패널 실행` 반환 후 0번).
let systemicDown = 0

// ── 페르소나 1명 실행 (C: eng+고복잡도면 loop-until-dry 최대 3라운드) ──
async function runPersona(persona) {
  const maxRounds = (persona.key === 'eng' && complexity === 'high') ? 3 : 1
  // 최고위험 게이트 claude측 슬롯 = fable 1순위 (fable∥codex 2소스 — opus·fable 동계열이라 fable 제3소스 병렬은 비상관 증가 없음).
  // eng(깊은 아키텍처 추론)+cso(보안 놓침=최악)만 topModel(기본 fable), 나머지(design/devex) sonnet(토큰 절감).
  //
  // ⚠ **이 스크립트는 모델 강등을 감지할 수 없다** (2026-07-26 실측):
  //   미가용 모델 요청은 실패하지 않는다. `Agent(model:'fable')`이 미가용 계정에서 에러·null이 아니라
  //   **정상 산출 + 실제 모델 claude-sonnet-5** 로 조용히 강등된다. 따라서 종전의
  //   `if (res === null) fableDown = true` 는 영영 false인 죽은 코드였고, 최고위험 게이트가
  //   무음으로 sonnet(폴백 기준 opus보다 아래)까지 내려가도 아무 신호가 없었다.
  //   워크플로 스크립트는 파일시스템 접근이 없어 transcript 실측도 불가 →
  //   **탐지 책임은 orchestrator**(게이트 산출 수령 시 transcript `"model"` 대조. orchestrator.md §모델 실측).
  //   여기서는 (a) orchestrator가 주입한 topModel을 그대로 쓰고 (b) 아래 model 필드를
  //   **요청값·미검증**으로 정직하게 표기한다(자기보고를 가용성 근거로 쓰지 않게).
  //   res === null 은 fable 미가용 신호가 아니라 진짜 사망(터미널 API 에러·사용자 skip)이다.
  const isTop = persona.key === 'eng' || persona.key === 'cso'
  let died = false
  let everRan = false // 한 번이라도 산출을 받았나 (전무 = 사망 → failures[] 대상)
  const all = []
  const evidence = [] // PASS 근거 누적 (다라운드 병합). orchestrator의 PASS 근거 기계검증 소스
  for (let r = 1; r <= maxRounds; r++) {
    const opts = (m) => ({
      label: `review:${persona.key}${maxRounds > 1 ? `:r${r}` : ''}`,
      phase: 'Review',
      schema: FINDINGS_SCHEMA,
      model: m,
    })
    let res = null
    if (isTop && !died) {
      res = await agent(reviewPrompt(persona, r), opts(topModel))
      if (res === null) died = true   // 진짜 사망만 여기 걸린다(강등은 안 걸림 — 위 주석)
    }
    // 서킷브레이커: 계정 층이 이미 고갈로 보이면 폴백을 쏘지 않는다(재실패 예정 호출 = 한도 낭비).
    // 미실행 페르소나는 아래 everRan=false로 failures[]에 실려 orchestrator가 재런치 판정한다.
    if (res === null && systemicDown >= 2) break
    if (res === null) res = await agent(reviewPrompt(persona, r), opts(isTop ? 'opus' : 'sonnet'))
    if (res === null) { systemicDown++; break }  // 폴백까지 전멸 = 이 페르소나 사망
    everRan = true
    if (Array.isArray(res?.passEvidence)) evidence.push(...res.passEvidence)
    const found = res?.findings ?? []
    if (found.length === 0) break // dry → 다라운드 중단 (단 passEvidence는 위에서 이미 수집)
    all.push(...found)
  }
  // ⚠ **산출 전무 = null 반환** (v4.9.0 — 종전 failures[] 탐지가 죽어 있었다):
  //   종전엔 두 agent 호출이 모두 null이어도 `{findings: [], passEvidence: []}` **객체**를 반환했다.
  //   아래 failures 계산은 `raw[i] ? null : p.key`라 truthy 객체는 실패로 안 잡힌다 →
  //   **사망 페르소나가 "findings 0건 정상완주"로 둔갑**하고 failures[]는 빈 채로 왔다.
  //   v4.6.0이 필드를 만들었지만 채우는 경로가 없던 셈. 이제 진짜 사망은 null로 내려보낸다.
  //   (passEvidence<2 완전성 검사가 2차 그물이었으나 부재를 통과로 읽지 않는 원칙상 1차가 필요하다.)
  if (!everRan) return null
  // model = **요청값**이지 실행값이 아니다. orchestrator가 transcript로 대조하기 전엔 신뢰 금지.
  return { persona: persona.key, findings: all, passEvidence: evidence,
           model: isTop ? (died ? 'opus(사망 폴백)' : `${topModel}(요청·미검증)`) : 'sonnet' }
}

// ── 페르소나 병렬 리뷰만 (적대검증 제거 — orchestrator가 dedup+코드대조 판정) ──
phase('Review')
// ⚠ **`failures[]`는 orchestrator 완전성 검사의 입력이다** (v4.6.0 신설 — 그 전까지 없었다).
//   `orchestrator.md` 패널 반환 후 절차 0번이 *"반환의 `failures[]`가 非空이면 그 페르소나만
//   1회 자동 재런치"* 를 지시하는데 종전 반환에 그 필드가 **없었다**. 게다가 종전 코드는
//   `.filter(Boolean)`으로 죽은 페르소나를 **조용히 버렸다** — eng가 터미널 API 에러로
//   죽으면 그 findings가 통째로 사라진 채 `criticals: []`가 반환되고, 완전성 검사는
//   근거 필드가 없어 못 잡는다 → **빈 criticals가 권위있게 게이트를 통과**한다.
//   이건 비용 문제가 아니라 안전 문제다(무음 실패 — wiki/gates-verify-present-code-only.md).
const raw = await parallel(personas.map(p => () => runPersona(p)))
const results  = raw.filter(Boolean)
const failures = personas
  .map((p, i) => (raw[i] ? null : p.key))
  .filter(Boolean)

// 집계 (dedup·판정 없음 — orchestrator 책임). 페르소나 태그만 부착해 raw 반환.
const tag = (sev) => results.flatMap(r =>
  r.findings.filter(f => f.severity === sev).map(f => ({ ...f, persona: r.persona })))

const perPersonaOut = results.map(r => ({
  persona: r.persona,
  model: r.model, // 'fable' | 'opus(fable 폴백)' | 'sonnet' — 폴백 시 orchestrator가 승인화면 정보 태그
  total: r.findings.length,
  criticals: r.findings.filter(f => f.severity === 'critical').length,
  passEvidence: r.passEvidence || [], // critical 0건 시 PASS 근거 ≥2 기계검증 소스
}))

// ── 계측 기록 (비차단·자동) ──────────────────────────────────────────────
// ⚠ **여기서 찍는 이유 = 산문 규칙이 졌기 때문이다.** v4.7.0은 이 기록을
//   `orchestrator.md`의 산문 절차(패널 반환 후 0-a)로 뒀는데, 7일간 **전 프로젝트
//   8곳 전수 0건**이었다(패널은 그 사이 4라운드 돌았다). 스크립트는 정상 동작했고
//   호출하는 쪽이 빠졌다 — "메커니즘은 있고 호출이 없는" 무음 실패다.
//   Workflow 스크립트는 JS 샌드박스라 Bash를 직접 못 쓴다 → agent 1개로 대행한다.
//   비용 ≈ 2~3k 토큰(패널 1회의 1% 미만). 어떤 실패도 게이트 판정에 영향 없다.
// round는 워크플로가 모른다(재게이트 = 재호출이라 리셋된다) → orchestrator가 args로 주면 쓰고,
// 없으면 스크립트 기본값 1. 핵심 파생지표 `ripplePersonas`는 priorPersonas ↔ perPersona 대조라
// round 없이도 성립한다. priorPersonas는 priorCriticals에서 직접 유도한다(별도 args 불요).
//
// ⚠ **payload에 자유 텍스트를 넣지 않는다 (셸 주입·손상 차단 — 3중).**
//   ① **필드 최소화**: `panel-metrics.sh`가 실제 소비하는 건 round/reGate/priorPersonas/
//      perPersona{persona,model,criticals}/failures **뿐이다**(passEvidence·total 소비 0건).
//      passEvidence는 **페르소나가 쓴 자유 텍스트**고 코드 리뷰 근거라 백틱 인용이 사실상 확실하다
//      → 셸에 닿으면 악의 없이도 명령치환으로 터지고 계측 JSON이 깨진다. 반환값에는 그대로 두고
//      **계측 payload에서만 뺀다**(orchestrator PASS 증거 기계검증은 반환을 쓴다).
//   ② **식별자 sanitize**: 남는 값도 페르소나 키·모델명이라 짧은 화이트리스트로 강제한다.
//   ③ **single-quote 인용**: bash 작은따옴표는 `$`·백틱을 통째로 무력화한다(큰따옴표는 아니다 —
//      `JSON.stringify`가 만드는 게 큰따옴표라 그 자체로는 방어가 안 됐다).
const sane = (v) => String(v ?? '').replace(/[^\w.\-()가-힣 ]/g, '_').slice(0, 60)
const metricsPayload = JSON.stringify({
  round: Number.isFinite(_a.round) ? _a.round : (isReGate ? 2 : 1),
  reGate: isReGate,
  priorPersonas: [...new Set(priorCriticals.map(c => sane(c.persona)).filter(Boolean))],
  perPersona: perPersonaOut.map(p => ({
    persona: sane(p.persona), model: sane(p.model), criticals: p.criticals,
  })),
  failures: failures.map(sane),
})
const metricsArg = `'${metricsPayload.replace(/'/g, `'\\''`)}'`
try {
  await agent(
    `아래 명령을 **그대로 1회** 실행하고 종료 코드만 보고하라. 다른 작업·파일 편집 금지.\n` +
    `⚠ 명령의 작은따옴표 인용을 **변형하지 마라**(payload를 큰따옴표로 바꾸거나 재조립 금지).\n\n` +
    "```bash\n" +
    `printf '%s\\n' ${metricsArg} | bash .claude/scripts/panel-metrics.sh log\n` +
    "```\n\n" +
    `이 스크립트는 어떤 실패에서도 exit 0이고 stdout을 쓰지 않는다. ` +
    `실패해도 재시도하지 마라 — 계측은 비차단이다. 반환은 "logged" 또는 "failed: <사유 1줄>" 한 줄.`,
    { label: 'panel-metrics', phase: 'Review', model: 'haiku' }
  )
} catch (e) {
  // 계측 실패가 게이트를 막지 않는다 — 기록만이 목적이다.
}

return {
  criticals: tag('critical'), // orchestrator: dedup by root → 인용라인 코드대조 → 생존>0면 차단
  majors:    tag('major'),    // 통과허용, 승인화면 노출
  minors:    tag('minor'),    // 기록만
  failures,                   // 스폰 실패·사망 페르소나 key[]. 非空이면 orchestrator가 그 페르소나만 1회 재런치
  reGate: isReGate,           // 이번 실행이 재게이트였나(초점 블록 적용 여부 — 산출 해석용)
  perPersona: perPersonaOut,
}
