export const meta = {
  name: 'design-panel',
  description: '설계패널: 페르소나 병렬 리뷰. findings만 생산하고 dedup·게이트 판정은 orchestrator가 한다(가드레일).',
  phases: [
    { title: 'Review', detail: '페르소나 N 병렬 리뷰 (eng는 고복잡도 시 다라운드)' },
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
  return { error: 'planText 또는 personas 누락 — orchestrator args 확인', criticals: [], majors: [], minors: [], perPersona: [] }
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
      // 토큰 절감: eng(깊은 아키텍처 추론)+cso(보안 놓침=최악)만 opus, 나머지(design/devex/ceo) sonnet.
      model: (persona.key === 'eng' || persona.key === 'cso') ? 'opus' : 'sonnet',
    })
    if (Array.isArray(res?.passEvidence)) evidence.push(...res.passEvidence)
    const found = res?.findings ?? []
    if (found.length === 0) break // dry → 다라운드 중단 (단 passEvidence는 위에서 이미 수집)
    all.push(...found)
  }
  return { persona: persona.key, findings: all, passEvidence: evidence }
}

// ── 페르소나 병렬 리뷰만 (적대검증 제거 — orchestrator가 dedup+코드대조 판정) ──
phase('Review')
const results = (await parallel(personas.map(p => () => runPersona(p)))).filter(Boolean)

// 집계 (dedup·판정 없음 — orchestrator 책임). 페르소나 태그만 부착해 raw 반환.
const tag = (sev) => results.flatMap(r =>
  r.findings.filter(f => f.severity === sev).map(f => ({ ...f, persona: r.persona })))

return {
  criticals: tag('critical'), // orchestrator: dedup by root → 인용라인 코드대조 → 생존>0면 차단
  majors:    tag('major'),    // 통과허용, 승인화면 노출
  minors:    tag('minor'),    // 기록만
  perPersona: results.map(r => ({
    persona: r.persona,
    total: r.findings.length,
    criticals: r.findings.filter(f => f.severity === 'critical').length,
    passEvidence: r.passEvidence || [], // critical 0건 시 PASS 근거 ≥2 기계검증 소스
  })),
}
