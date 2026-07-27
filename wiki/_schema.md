# wiki/ — 하네스 운영 지식 베이스 (schema)

> 이 디렉터리의 **작성 규칙·라우팅 규칙**을 정의한다. 카파시 LLM wiki 패턴의 Layer3(schema)에 해당.
> 새 페이지를 쓰거나 고치기 전에 이 파일의 규칙을 따른다.

## 무엇을 담나
`harness-setup`을 **운영하며 쌓인 지식·gotcha·노하우**. 시간이 갈수록 페이지가 늘고 `[[링크]]`로 촘촘해진다.
설계 전문(why)·용어 정의는 여기가 아니라 `docs/`·`CONTEXT.md`가 담당한다(아래 라우팅 규칙).

## 라우팅 규칙 — 지식을 어디 둘지 (가장 중요)
판단 축은 하나: **"다른 머신의 미래의 나도 알아야 하나?"**

| 조건 | 위치 | 추적 |
|------|------|------|
| 다른 머신에서도 하네스가 알아야 함 + **운영하며 배운 것/노하우/gotcha** | **`wiki/`** (여기) | track |
| 다른 머신에서도 알아야 함 + **설계·용어 정의** | `docs/` (설계·ADR), `CONTEXT.md` (용어) | track |
| **이 머신/세션에서만** 의미 있음 (머신 상태·임시 진행·개인 선호) | auto-memory (`~/.claude/projects/.../memory/`) | ignore(로컬) |

원칙:
- **중복 금지.** 설계 전문이 `docs/`에 있으면 wiki에 다시 쓰지 말고 링크만 한다.
- 머신 한정 사실(예: "이 PC의 jq는 winget user scope 경로에 있다")은 wiki가 아니라 auto-memory.

## 언제 기록하나 (capture 트리거)
> 이 절이 "운영 지식을 wiki에 남기는 시점·기준"의 SSOT다. orchestrator는 여기를 가리키기만 한다(중복금지).

**기록 대상 (= 위 라우팅 표 1행을 통과하는 것):**
운영하다 **비자명하게 알아낸 것**. 다음 중 하나면 후보:
- 디버깅으로 **원인을 규명**했다 (증상 → 진짜 원인). 예: 한글 깨짐 = curl 인자 인코딩.
- **비자명한 회피책/노하우**를 찾았다 (그냥 하면 안 되는 것). 예: jq는 파일 경유.
- 훅·배포·환경(PATH/인코딩/권한)에서 **함정을 밟고 빠져나왔다**.
- 같은 걸 **두 번째로 검색**하고 있다 (= 첫 번째에 기록했어야 함).

**기록 안 함 (오답):**
- 한 번 쓰고 끝나는 머신 상태("이 PC의 jq 경로") → auto-memory (휴대 안 됨).
- 설계 전문(why)·용어 정의 → `docs/`·`CONTEXT.md` 링크만.
- 코드/git이 이미 기록하는 사실(구조·과거 수정) → 아무 데도 안 씀.

**언제 (시점):**
- 변경을 **커밋한 직후**(post-commit) 한 번 자가점검: "이번에 비자명하게 배운 게 있나?" → 있으면 아래 절차.
- 또는 위 후보를 **인지한 즉시** 그 자리에서.

**절차 (advisory — 자동 커밋 금지, repo R1 정책):**
1. 새 페이지(또는 기존 페이지 갱신)를 [아래 형식](#페이지-형식)으로 **스텁까지 준비**한다. 이때 근거(회고·failure·CHANGELOG·docs 경로 중 **최소 하나**)를 `sources`에 남긴다 — 근거 없으면 invent 금지, 제안 시 "근거 부족" 표시.
2. 근거 원문이 **repo 밖**(inbox·failure 등)이면 `wiki/sources/`로 **복사 고정**한다 — 아래 [근거 고정](#근거-고정-layer1) 절. ⚠ 복사 주체 = **페이지를 실제로 커밋하는 쪽**(dev clone). 소비자 세션은 이 단계 해당 없음(아래 "어디로 가나"대로 inbox 드롭까지만 — 복사는 드레인 때 일어난다).
3. `index.md`에 한 줄 등록 + 관련 페이지에 `[[링크]]` 연결. ⚠ 신규 생성 전에 **같은 엔티티 페이지를 먼저 Grep**(3개 이상이면 아래 분기).
   - **같은 근본원인** → 새 페이지 금지. **기존 페이지에 통합·갱신**한다. (예: codex Windows 함정이 shim/tmp/stall/timeout/heredoc/mojibake로 7페이지 파편화 — 조회 시 전부 읽어야 한다.)
   - **같은 표면·다른 근본원인** → 통합하면 구체성이 사라진다. 각자 페이지를 유지하되 **상호 `[[링크]]` + 각 페이지 말미에 "같은 계열" 절 + `index.md` 인접 배치**로 클러스터를 만든다. (예: VTU/jsdom DOM 단언 함정 3종 — 증상 표면은 같으나 원인·회피가 각각 다르다.)
4. 사용자에게 **"wiki에 이거 기록할까?"** 제안한다(자동 저장 X). 승인 시 커밋.

**어디로 가나 (세션 종류 분기 — gotcha의 push 비대칭):**
gotcha는 보통 **소비자 세션**(제품 repo에 vendoring된 `.claude`)에서 발견된다. 거기서 직접 커밋하면 제품 repo에 갇혀 harness-setup SSOT가 못 받는다(개선후보 inbox와 같은 비대칭).

> **판별식 (SSOT — origin으로 판별 금지)**: `basename $(git rev-parse --show-toplevel)`가 `.claude`면 **소비자 세션**(중첩 vendoring), 아니면 **dev clone**(repo 루트가 하네스 자체 = `VERSION`이 루트에 있음).
> ⚠ `origin=harness-setup` 판별은 **틀렸다** — 소비자의 중첩 `.claude/`도 자체가 harness-setup 클론이라 origin이 같아 dev clone으로 **오판**한다(2026-07-15 실사고: finalizer가 소비자 세션서 하네스 직접 커밋 → 폐기·reset). 판별 기준은 origin이 아니라 **worktree가 중첩 `.claude`인가**다.

- **dev clone**(toplevel basename ≠ `.claude`): 위 절차대로 직접 wiki 커밋(승인 시).
- **소비자 세션**: 직접 커밋 금지. 준비한 스텁을 **회고 inbox로 드롭**(`~/.claude/harness-retro-inbox/`, 경로·형식은 `/harness-check` Step2.5 SSOT). content = gotcha 스텁(증상→원인→회피) + sources 후보(failure·CHANGELOG·발생세션). dev clone에서 `/harness-retro`가 드레인 → Step2 "운영 gotcha→wiki" 라우팅으로 페이지 생성. ⚠ 이때 **inbox 원문을 `wiki/sources/`로 복사**하고 그 repo 내부 경로를 `sources`에 쓴다 — inbox 경로를 그대로 인용하면 드레인이 `applied/`로 옮기는 순간 죽는다([근거 고정](#근거-고정-layer1)). SSOT 커밋·push 후 전 세션 git pull로 환원, 이후 읽기 트리거(orchestrator "wiki 참조" 절)가 집어준다.

## 근거 고정 (Layer1)
카파시 패턴의 Layer1(raw sources)은 **불변·상주**여야 한다. 우리 근거는 대부분 회고 inbox(`~/.claude/harness-retro-inbox/`)인데 이건 **머신로컬(gitignore)** 이고 드레인이 `applied/`로 **이동**시킨다 — 인용 경로가 두 겹으로 죽는다(타 머신=전부 dangle, 이동 후=경로 stale). 본문은 자기완결적이라 지식은 안 날아가지만 **출처 검증이 불가능**해진다.

- repo 밖 근거를 인용할 땐 원문을 `wiki/sources/<원본파일명>`으로 **복사**하고, `sources:`는 그 상대경로(`sources/...`)를 가리킨다.
- `wiki/sources/`는 **읽기 전용 사본**이다. 수정 금지(불변). 지식 갱신은 wiki 페이지 쪽에서 한다.
- 이미 repo 안에 있는 근거(`../CHANGELOG.md`, `../docs/...`)는 복사 불요 — 그대로 상대경로 인용.
- 소급 적용 안 함. **신규 인용부터** 적용한다(기존 페이지는 근거 유실 시 아래 표기법).
- 근거가 유실됐으면 지어내지 말고 `sources: (pre-inbox, 근거 유실)`로 **정직하게 표기**한다.

## 페이지 형식
파일명 = `kebab-case.md` (개념 1개당 1파일). frontmatter + 본문:

```markdown
---
title: 사람이 읽는 제목
type: operational | gotcha | reference   # 운영지식 / 함정·교훈 / 외부참조
links: [[다른-페이지-slug]], [[또-다른-slug]]
sources:                                 # 이 지식의 근거. gotcha는 가능한 한 필수
  - sources/<복사한-원문>.md | ../CHANGELOG.md#... | ../docs/...
  #  repo 밖 근거(inbox·failure)는 sources/ 로 복사 후 인용 — "근거 고정" 절
updated: YYYY-MM-DD
---

본문. 핵심부터. 관련 개념은 본문에서도 [[slug]] 로 링크한다.
repo 밖 설계 문서나 코드 경로는 일반 마크다운 링크/경로로 가리킨다.
```

## 링크 규칙
- wiki 내부 페이지끼리는 `[[slug]]` (Obsidian 호환 — vault로 열면 그래프/백링크가 바로 뜬다).
- 새 페이지를 추가하면 **`index.md`에 한 줄 등록**한다(=카탈로그).

## 유지보수 (lint)
**기계 점검 — `bash scripts/wiki-check.sh`** (읽기 전용, 발견 시 exit 1)
- index 미등록 / 깨진 `[[링크]]` / 빈 파일 / `title`·`updated` 누락 / **gotcha인데 `sources` 없음**을 잡는다.
  (operational·reference의 `sources`는 출처 약하면 생략 가능 — invent 금지. 그래서 점검 대상 아님)
- 페이지 추가·갱신 후, 그리고 하네스 회고(`/harness-retro`) 드레인 끝에 1회 돌린다.

**사람 점검 (스크립트가 못 잡는 것)**
- 모순 페이지, stale claim(내용이 낡음), data gap.
- 고아 페이지(들어오는 링크 0) — **Obsidian으로 이 폴더를 열면** 그래프 뷰가 고아/허브를 시각적으로 보여준다.
- ⚠ 그래프 뷰는 링크 구조만 본다. index 미등록·frontmatter 결손은 **안 보인다** — 그건 위 스크립트 몫이다(그래프가 lint를 대신하지 못한다).
