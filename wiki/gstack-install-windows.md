---
title: gstack Windows 설치·등록 함정 (브라우저 hang → 스킬 미등록)
type: gotcha
links: [[windows-path-jq]]
updated: 2026-06-16
---

Windows(git-bash)에서 `gstack/setup`을 돌리면 **브라우저(playwright chromium) 추출 단계에서 hang** → 그 뒤의 **스킬 등록 단계가 영영 안 돈다**. 결과: `~/.claude/skills/`에 `gstack/`만 있고 `context-save`·`plan-eng-review`·`office-hours` 등 개별 스킬이 top-level에 안 떠서 **슬래시 호출(`/context-save` 등)·렌즈 Read가 전부 빗나간다.** 하네스는 이 스킬들을 글로벌 gstack에 의존하므로(미러 안 함, v2.1.0~) 등록이 안 되면 codex 리뷰·계획리뷰·컨텍스트 저장이 조용히 미작동.

## 증상
- `./setup --no-prefix`가 `Downloading Chrome for Testing ... 100%`에서 멈춤. 프로세스는 살아있으나 **CPU 거의 0**(예: 29분에 0.0156s), `chrome.exe` 안 풀림, 대상 폴더 mtime 정지.
- 흔한 원인: 이전 설치분 chromium의 `chrome.exe`가 락 → 덮어쓰기 무한대기. (`Removing unused browser at chromium-1208` 직후 재다운로드 정황.)

## 선행 함정 — bun을 못 찾음 (stale PATH)
setup은 `bun`을 요구하는데, **이미 설치돼 있어도**(`~/.bun/bin/bun.exe`) git-bash 세션 PATH에 `~/.bun/bin`이 없으면 "bun is required but not installed"로 죽는다. → 설치 새로 하지 말 것. PATH만 얹어 재실행:
`export PATH="$HOME/.bun/bin:$PATH" && ./setup --no-prefix`
(이건 [[windows-path-jq]]와 **같은 stale-PATH 패턴** — Windows에서 CC/셸이 설치 갱신 이전 환경을 상속.)

## 해법 — 브라우저 건너뛰고 등록만 (setup `link_claude_skill_dirs` 재현)
브라우저(`/browse`·`/qa`·`/design-review` 전용)는 등록과 무관한데 setup이 **브라우저 성공을 등록의 전제로 게이트**해서 인질이 된다. 멈춘 프로세스 죽이고 등록 함수만 수동 재현:

```bash
G="$HOME/.claude/skills/gstack"; S="$HOME/.claude/skills"
for d in "$G"/*/; do
  [ -f "$d/SKILL.md" ] || continue
  dn="$(basename "$d")"; [ "$dn" = "node_modules" ] && continue
  name=$(grep -m1 '^name:' "$d/SKILL.md" | sed 's/^name:[[:space:]]*//' | tr -d '[:space:]')
  [ -z "$name" ] && name="$dn"
  mkdir -p "$S/$name"; cp -f "$d/SKILL.md" "$S/$name/SKILL.md"
  [ -d "$d/sections" ] && { rm -rf "$S/$name/sections"; cp -rf "$d/sections" "$S/$name/sections"; }
done
# /gstack 루트 별칭
mkdir -p "$S/_gstack-command"; cp -f "$G/SKILL.md" "$S/_gstack-command/SKILL.md"
```

`--no-prefix` = top-level 이름이 flat(`/context-save`). 기본 `--prefix`면 `/gstack-context-save`로 등록돼 하네스 호출이 빗나간다 → **하네스는 반드시 `--no-prefix`(=flat)**.

## 교훈
- **Windows는 symlink 대신 copy**(setup `_link_or_copy` 폴백). 그래서 gstack `git pull`/`gstack-upgrade` 후엔 위 등록을 **다시 돌려야** 갱신된다("고쳤다 착각" 회귀 주의).
- 등록은 **세션 시작 시** 발견 → 등록 직후 현재 세션엔 안 보이고 **재시작 후** 슬래시에 뜬다.
- 검증: `~/.claude/skills/`에 `context-save` 등 top-level 존재 + 재시작 후 `/context-save` 자동완성.
- 관련 설계: gstack 의존·미러 안 함 정책은 `../skills/versions.md`(gstack 글로벌 의존 절), `../CHANGELOG.md` v2.1.0.
