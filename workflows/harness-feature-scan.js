export const meta = {
  name: 'harness-feature-scan',
  description: '하네스 기능 스캔: CC 신기능(curl) + 웹 모범사례(WebSearch) 조사 → 현 하네스 대비 도입 후보를 백로그에 매핑. 자동적용 금지(보조입력).',
  phases: [
    { title: 'Scan', detail: '레인A CC문서 curl + 레인B 웹 모범사례 병렬 조사' },
    { title: 'Synthesize', detail: '후보 종합·중복제거·백로그 우선순위 매핑' },
  ],
}

// ─────────────────────────────────────────────────────────────
// args (orchestrator가 전달)
//   orchestratorPath : 현 orchestrator.md 절대경로 (하네스 현황 대조 기준)
//   backlogPath      : 개선 백로그 메모리 절대경로 (기존 후보 중복 제거 기준)
//   websearchAvailable : boolean — 레인B(WebSearch/deep-research) 가용 여부.
//                        false면 레인B 스킵(2A만으로도 유효). 미검증 시 false 권장.
// ─────────────────────────────────────────────────────────────
let _a = args
if (typeof _a === 'string') { try { _a = JSON.parse(_a) } catch (e) { _a = {} } }
_a = _a ?? {}

const orchestratorPath   = _a.orchestratorPath   ?? '.claude/agents/orchestrator.md'
const backlogPath        = _a.backlogPath        ?? '.claude/agent-memory/orchestrator/project_harness_improvement_backlog.md'
const websearchAvailable = _a.websearchAvailable === true

const CANDIDATE_SCHEMA = {
  type: 'object',
  properties: {
    lane: { type: 'string' }, // 'cc-feature' | 'web-bestpractice'
    candidates: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          title:        { type: 'string' },
          source:       { type: 'string' },  // URL 또는 출처
          summary:      { type: 'string' },  // 무엇인지 1~2줄
          harnessFit:   { type: 'string' },  // 우리 하네스 어디에 접목 가능한가
          alreadyHave:  { type: 'boolean' }, // 백로그/하네스에 이미 있나
          priority:     { type: 'string', enum: ['high', 'medium', 'low', 'reject'] },
          rationale:    { type: 'string' },  // 우선순위 근거 (YAGNI/거버넌스 위반 시 reject)
        },
        required: ['title', 'source', 'summary', 'harnessFit', 'alreadyHave', 'priority'],
      },
    },
    notes: { type: 'string' }, // 스캔 한계·실패·커버 못한 영역 (no silent caps)
  },
  required: ['lane', 'candidates'],
}

const HARNESS_CONTEXT = `[현 하네스 대조 기준]
- orchestrator 규칙: ${orchestratorPath} 를 Read하라 (3트랙/설계패널/TDD합의/게이트 구조 파악).
- 개선 백로그: ${backlogPath} 를 Read하라 (이미 도입했거나 보류/탈락된 후보 — 중복 제안 금지).
- 거버넌스 불변식(후보가 이것을 깨면 priority=reject): 사람 승인 게이트 유지, research preview 산출은 보조입력(게이트 단독결정 금지), 하네스 자동수정 금지, 사내 products main 직접 push 금지.`

// ── 레인 A: CC 신기능 (curl, WebSearch 불필요) ──
function laneACCPrompt() {
  return `너는 Claude Code 신기능 스카우트다. Bash의 curl로 CC 공식 문서를 조회해 최근 추가/변경된 기능을 찾고, 우리 하네스 도입 후보를 평가한다.

[조사 방법]
- Bash curl로 아래를 받아 파싱(HTML이면 텍스트 추출). 실패 시 다른 경로 시도하고 notes에 기록:
  - https://docs.claude.com/en/release-notes/claude-code (릴리스 노트 — 1순위)
  - https://docs.claude.com/en/docs/claude-code/ (기능 인덱스)
- 최근 항목 위주. 우리가 모를 신기능(hooks 확장, subagent, workflow, MCP, plugins, 권한모델 등) 식별.

${HARNESS_CONTEXT}

[출력] CANDIDATE_SCHEMA, lane='cc-feature'.
- 각 신기능을 우리 하네스에 어떻게 접목할지(harnessFit) 구체적으로.
- 백로그/하네스에 이미 있으면 alreadyHave=true + priority 그에 맞게(보통 low/reject).
- 거버넌스 위반·YAGNI는 priority=reject + rationale 명시.
- curl 실패/접근불가 영역은 notes에 반드시 기록(조용한 누락 금지).`
}

// ── 레인 B: 웹 오케스트레이션/거버넌스 모범사례 (WebSearch 필요) ──
function laneBWebPrompt() {
  return `너는 LLM 에이전트 오케스트레이션 모범사례 리서처다. WebSearch로 Anthropic 블로그/엔지니어링 글 및 에이전트 하네스 설계 패턴을 조사해, 우리 하네스 개선 후보를 평가한다.

[조사 초점] CC 공식문서엔 없는 것 위주:
- Anthropic 블로그/엔지니어링(멀티에이전트, 컨텍스트 관리, 평가, 안전 게이트 패턴)
- 에이전트 오케스트레이션 거버넌스·검증·TDD·코드리뷰 자동화 패턴
- "반복≠신뢰", 적대검증의 함정 등 우리가 이미 겪은 교훈을 보강/반박하는 최신 글

${HARNESS_CONTEXT}

[출력] CANDIDATE_SCHEMA, lane='web-bestpractice'.
- harnessFit: 우리 3트랙/설계패널/TDD합의/게이트 어디에 접목.
- 거버넌스 위반·YAGNI·이미 보유는 reject/low + rationale.
- 커버 못한 영역은 notes에 기록(조용한 누락 금지).`
}

phase('Scan')
const lanes = [() => agent(laneACCPrompt(), { label: 'scan:cc-feature', phase: 'Scan', schema: CANDIDATE_SCHEMA })]
if (websearchAvailable) {
  lanes.push(() => agent(laneBWebPrompt(), { label: 'scan:web-bestpractice', phase: 'Scan', schema: CANDIDATE_SCHEMA }))
} else {
  log('레인B(웹 모범사례) 스킵 — websearchAvailable=false (WebSearch 미프로비저닝). 레인A(CC기능)만 수행.')
}
const scans = (await parallel(lanes)).filter(Boolean)

// ── 종합: 중복제거 + 백로그 우선순위 매핑 (판정은 보조입력, 최종 도입은 사람) ──
phase('Synthesize')
const rawCandidates = scans.flatMap(s => (s.candidates || []).map(c => ({ ...c, lane: s.lane })))
const scanNotes = scans.map(s => ({ lane: s.lane, notes: s.notes || '' }))

if (rawCandidates.length === 0) {
  return {
    websearchAvailable, lanesRun: scans.map(s => s.lane),
    newCandidates: [], alreadyHave: [], rejected: [], scanNotes,
    summary: '신규 후보 0건 (또는 스캔 실패). scanNotes 확인.',
  }
}

const SYNTH_SCHEMA = {
  type: 'object',
  properties: {
    newCandidates: { // 도입 검토 가치 있는 신규 (백로그에 없던 것)
      type: 'array',
      items: {
        type: 'object',
        properties: {
          title:      { type: 'string' },
          lane:       { type: 'string' },
          source:     { type: 'string' },
          summary:    { type: 'string' },
          harnessFit: { type: 'string' },
          priority:   { type: 'string', enum: ['high', 'medium', 'low'] },
          rationale:  { type: 'string' },
        },
        required: ['title', 'priority', 'harnessFit'],
      },
    },
    alreadyHave: { type: 'array', items: { type: 'string' } }, // 이미 보유/백로그 중복 (title만)
    rejected:    { type: 'array', items: { type: 'object', properties: { title: { type: 'string' }, reason: { type: 'string' } }, required: ['title', 'reason'] } },
    backlogPatch: { type: 'string' }, // 백로그 메모리에 append할 마크다운 초안 (사람이 검토 후 반영)
  },
  required: ['newCandidates', 'alreadyHave', 'rejected', 'backlogPatch'],
}

const synth = await agent(
  `너는 하네스 개선 후보 종합자다. 아래 스캔 후보들을 종합한다.

[작업]
1. ${backlogPath} 를 Read해 기존 도입/보류/탈락 항목과 대조.
2. 중복(이미 보유/백로그/탈락) → alreadyHave 또는 rejected로 분류.
3. 신규 가치 후보만 newCandidates로. priority 재산정(거버넌스 위반·YAGNI는 제외).
4. backlogPatch: 백로그 '## 도입 우선순위' 또는 별도 섹션에 append할 마크다운 초안 작성. (실제 파일 수정 금지 — 초안만. 반영은 사람.)

[거버넌스] 후보가 사람승인 게이트/보조입력 원칙/하네스 자동수정 금지/products main push 금지를 깨면 무조건 rejected.

[스캔 후보 JSON]
${JSON.stringify(rawCandidates, null, 2)}

[스캔 한계 노트]
${JSON.stringify(scanNotes, null, 2)}

[출력] SYNTH_SCHEMA.`,
  { label: 'synthesize', phase: 'Synthesize', schema: SYNTH_SCHEMA }
)

return {
  websearchAvailable,
  lanesRun: scans.map(s => s.lane),
  newCandidates: synth?.newCandidates ?? [],
  alreadyHave:   synth?.alreadyHave ?? [],
  rejected:      synth?.rejected ?? [],
  backlogPatch:  synth?.backlogPatch ?? '',
  scanNotes,
}
