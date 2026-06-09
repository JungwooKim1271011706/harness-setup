export const meta = {
  name: 'design-panel',
  description: '설계패널: 페르소나 병렬 리뷰 + critical 적대적 교차검증. findings만 생산하고 게이트 판정은 orchestrator가 한다(가드레일).',
  phases: [
    { title: 'Review', detail: '페르소나 N 병렬 리뷰 (eng는 고복잡도 시 다라운드)' },
    { title: 'Verify', detail: 'critical findings 적대적 교차검증 (refute-default 3 스킵터)' },
  ],
}

// ─────────────────────────────────────────────────────────────
// args (orchestrator가 전달 — D2: 페르소나 선정·보안재스캔은 orchestrator 책임)
//   planText   : planner 산출물 텍스트 (계획서 전문)
//   rulePaths  : ["...rules/package/tocServer/backend.md", ...]  0단계 확정 rule 경로
//   complexity : 'normal' | 'high'
//   personas   : [{ key, skillPath|null }]  skillPath 있으면 C(스킬 Read), null이면 임베드(cso)
// ─────────────────────────────────────────────────────────────
// args는 객체 기대. 일부 호출 경로에서 JSON 문자열로 도착할 수 있어 방어적 파싱.
let _a = args
if (typeof _a === 'string') { try { _a = JSON.parse(_a) } catch (e) { _a = {} } }
_a = _a ?? {}

const planText   = _a.planText   ?? ''
const rulePaths  = _a.rulePaths  ?? []
const complexity = _a.complexity ?? 'normal'
const personas   = _a.personas   ?? []

if (!planText || personas.length === 0) {
  return { error: 'planText 또는 personas 누락 — orchestrator args 확인', confirmedCriticals: [], majors: [], minors: [], perPersona: [] }
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

const VERDICT_SCHEMA = {
  type: 'object',
  properties: {
    refuted: { type: 'boolean' },
    reason:  { type: 'string' },
  },
  required: ['refuted', 'reason'],
}

// cso 계획단계 보안 렌즈 (D1=A 임베드 — plan-cso-review 스킬 부재로 불가피)
// 출처: cso 스킬의 OWASP/STRIDE/trust-boundary를 '계획 비평'용으로 각색.
// TODO: 추후 plan-cso-review 스킬 신규 작성(D) 후 이 임베드를 C(스킬 Read)로 교체.
const CSO_LENS = `[보안 계획 리뷰 렌즈 — 계획 텍스트를 비평한다. 코드 스캔 아님(코드는 아직 없음).]
다음을 계획서에서 점검:
- 인증/인가: 권한 체크 위치가 계획에 명시됐나? UserLevel/세션 검증·LoginCheckInterceptor 우회 경로?
- 입력 검증: 사용자 입력 진입점마다 검증 계획? SQL injection/XSS/경로조작 표면?
- 세션/쿠키: 세션 고정·하이재킹 고려? 민감값 세션 저장 방식?
- 암호화/비밀: 비밀키·PW 평문 위험? 저장·전송 암호화 계획?
- 신뢰 경계: 계획이 trust boundary를 넘나? 경계마다 재검증하나?
- 감사 로깅: 민감 동작에 @Audit 계획? (actionResult/subject 기록)
- STRIDE 매핑(Spoofing/Tampering/Repudiation/Info disclosure/DoS/Elevation) + OWASP Top 10 해당 항목
설계결함 수준 보안 누락 = critical. 강화 권고 수준 = major.`

// ── 페르소나 리뷰 프롬프트 (D1: 스킬 있으면 C[Read], cso는 임베드 A) ──
function reviewPrompt(persona, round) {
  const lensBlock = persona.skillPath
    ? `[렌즈 출처] ${persona.skillPath} 를 Read하라.
  - 사용: 엔지니어링 선호 / 인지 패턴 / 리뷰 섹션 / Confidence Calibration 부분만 렌즈로 써라.
  - 무시: AskUserQuestion·STOP 게이트·plan-mode·office-hours·design-doc 체크·telemetry 등 인터랙티브 머신러리. 너는 사람과 대화하지 않는다. findings JSON만 낸다.`
    : CSO_LENS

  return `너는 설계패널의 '${persona.key}' 페르소나 리뷰어다. planner가 작성한 계획서를 너의 관점으로 비평한다.

${lensBlock}

[준수 규칙] 다음 rule 파일을 Read하고 위반을 findings로 잡아라: ${rulePaths.join(', ') || '(없음)'}

[검토 대상 계획서]
${planText}

[출력] FINDINGS_SCHEMA(JSON). 규칙:
  - severity: critical(설계결함·게이트 차단감) / major(통과허용·승인화면 노출) / minor(기록만)
  - confidence 1~10. quote(계획서/코드의 동기 라인)를 못 달면 confidence를 4 이하로 강등하라.
  - critical 0건이면 passEvidence에 '무엇을 점검했고 왜 critical이 없는지' ≥2 항목을 반드시 채워라.${round > 1 ? `\n  - [다라운드 ${round}] 이전 라운드가 놓친 결함만 새로 찾아라. 중복 금지. 없으면 빈 findings.` : ''}`
}

// ── 페르소나 1명 실행 (C: eng+고복잡도면 loop-until-dry 최대 3라운드) ──
async function runPersona(persona) {
  const maxRounds = (persona.key === 'eng' && complexity === 'high') ? 3 : 1
  const all = []
  const evidence = [] // PASS 근거 누적 (다라운드 병합). orchestrator의 PASS 근거 기계검증 소스
  for (let r = 1; r <= maxRounds; r++) {
    const res = await agent(reviewPrompt(persona, r), {
      label: `review:${persona.key}${maxRounds > 1 ? `:r${r}` : ''}`,
      phase: 'Review',
      schema: FINDINGS_SCHEMA,
      // 토큰 절감: eng만 opus 유지(critical 아키텍처 결함 포착 핵심), 나머지 sonnet.
      model: persona.key === 'eng' ? 'opus' : 'sonnet',
    })
    if (Array.isArray(res?.passEvidence)) evidence.push(...res.passEvidence)
    const found = res?.findings ?? []
    if (found.length === 0) break // dry → 다라운드 중단 (단 passEvidence는 위에서 이미 수집)
    all.push(...found)
  }
  return { persona: persona.key, findings: all, passEvidence: evidence }
}

// ── critical 적대적 교차검증 (D3+D5: critical만, 토큰 가드) ──
// perspective-diverse: 같은 refute 프롬프트 N회(고상관, confidence 안 늚)가 아니라
// 서로 다른 렌즈 3개(비상관)로 검증. 한 critical이 여러 방식으로 틀릴 수 있으니
// 다양성이 중복이 못 잡는 실패모드를 잡는다. (결정적 재실행 N회는 정보 0이라는 원칙)
const VERIFY_LENSES = [
  {
    key: 'existence',
    instruction: `[렌즈: 존재성] 이 지적의 전제가 코드/계획에 실재하나? 근거인용된 라인이 실제로 그러한가, 인용 없이 추정한 것은 아닌가. 전제가 허구거나 인용이 계획을 오독했으면 refuted=true.`,
  },
  {
    key: 'exploitability',
    instruction: `[렌즈: 발현가능성] 전제가 실재해도 실제로 악용/장애로 발현되는 경로가 있나? 이론상 가능하나 현실 트리거가 없거나, 심각도가 과장(critical 아닌 major/minor)이면 refuted=true.`,
  },
  {
    key: 'context',
    instruction: `[렌즈: 맥락/중복] 기존 코드·인터셉터·룰·프레임워크가 이미 이 문제를 막고 있지 않나? 다른 finding과 중복이거나 상위 계층이 이미 차단하면 refuted=true.`,
  },
]

function verifyPrompt(finding, personaKey, lens) {
  return `critical 지적을 ${lens.key} 렌즈로 검증하라. 불확실하면 refuted=true가 기본(거짓 critical 거르기).
${lens.instruction}

페르소나=${personaKey}
지적=${finding.description}
위치=${finding.location}
근거인용=${finding.quote ?? '(없음 — 근거 약함)'}
권고=${finding.recommendation ?? ''}

계획서 맥락:
${planText}

[출력] VERDICT_SCHEMA. 이 렌즈 기준 refuted=true면 왜 틀렸/과장/중복인지, false면 이 렌즈로도 실재 critical인 이유를 reason에.`
}

async function verifyCritical(finding, personaKey) {
  // 3개 서로 다른 렌즈 병렬 (비상관 3표). ≥2 렌즈가 반증하면 폐기.
  const votes = await parallel(VERIFY_LENSES.map(lens => () =>
    agent(verifyPrompt(finding, personaKey, lens), {
      label: `verify:${personaKey}:${lens.key}`,
      phase: 'Verify',
      schema: VERDICT_SCHEMA,
    }).then(v => (v ? { ...v, lens: lens.key } : null))
  ))
  const valid = votes.filter(Boolean)
  const refutes = valid.filter(v => v.refuted).length
  return {
    ...finding, personaKey,
    refutes,
    refutedLenses: valid.filter(v => v.refuted).map(v => v.lens), // 어느 렌즈가 반증했나(감사)
    survived: refutes < 2, // 다수(≥2 렌즈) 반증 시 폐기
  }
}

// ── 파이프라인: 페르소나별 리뷰 → 그 페르소나 critical 즉시 교차검증 ──
// (페르소나 A critical 검증 중 페르소나 B 리뷰 동시 진행 — barrier 없음)
phase('Review')
const results = await pipeline(
  personas,
  (persona) => runPersona(persona),
  (res) =>
    parallel(
      res.findings
        .filter(f => f.severity === 'critical')
        .map(f => () => verifyCritical(f, res.persona))
    ).then(verified => ({ persona: res.persona, findings: res.findings, passEvidence: res.passEvidence, verifiedCriticals: verified.filter(Boolean) }))
)

// ── 집계 (판정 아님 — orchestrator가 기존 게이트 규칙으로 최종 판정) ──
const clean = results.filter(Boolean)
const confirmedCriticals = clean.flatMap(r => (r.verifiedCriticals || []).filter(v => v.survived))
const droppedCriticals   = clean.flatMap(r => (r.verifiedCriticals || []).filter(v => !v.survived))
const majors = clean.flatMap(r => r.findings.filter(f => f.severity === 'major').map(f => ({ ...f, persona: r.persona })))
const minors = clean.flatMap(r => r.findings.filter(f => f.severity === 'minor').map(f => ({ ...f, persona: r.persona })))

return {
  confirmedCriticals, // orchestrator: length>0 → planner 재작업 [LOOP n/3]
  droppedCriticals,   // 교차검증서 폐기된 거짓 critical (감사용)
  majors,             // 통과허용, 승인화면 노출
  minors,             // 기록만
  perPersona: clean.map(r => ({
    persona: r.persona,
    total: r.findings.length,
    criticals: (r.verifiedCriticals || []).length,
    passEvidence: r.passEvidence || [], // orchestrator: critical 0건 시 PASS 근거 ≥2 기계검증 소스
  })),
}
