---
title: Vue immediate watch가 mount 전 실행돼 template ref가 null — 첫 렌더는 onMounted로
type: gotcha
links: [[vite-stale-served-source-windows]]
sources:
  - ~/.claude/harness-retro-inbox/20260622T070635Z__DEVUNIT-authpatch_draft__wiki-vue-watch-onmounted.md
  - 발생세션 bugfix-autopatch-dashboard (커밋 f80cdacb→a3ef329)
updated: 2026-06-24
---

## 증상
Chart.js 차트가 안 그려짐. canvas는 DOM에 있는데(`v-if` 통과) 크기가 디폴트 300x150 + inline style 없음 = `new Chart()`가 실행 안 됨. **콘솔 에러 없음**(조용한 실패).

## 진짜 원인
`watch(() => props.data, renderChart, { immediate: true })`에서 immediate 콜백이 컴포넌트 **setup 단계(DOM mount 전)에 동기 실행**된다. 그 시점 `canvasRef.value === null` → renderChart가 guard에서 early-return. 부모가 데이터 로드 후에야 이 컴포넌트를 mount하므로 props가 mount 시점에 이미 채워져 있고 그 뒤 안 바뀜 → watch 재실행 없음 → 차트 영영 안 그려짐.

**함정**: `{ immediate: true, flush: 'post' }`로 줘도 **안 고쳐진다**. flush:'post'는 후속 반응 콜백 타이밍만 미루지, immediate 첫 실행을 mount 뒤로 확실히 보장하지 않음(실측으로 캔버스 여전히 미렌더).

## 회피
template ref에 의존하는 **첫 렌더는 watch immediate가 아니라 `onMounted(renderChart)`**로 보장. watch는 immediate 빼고 후속 데이터 변경 갱신만 담당:
```
watch(() => props.data, renderChart, { deep: true })
onMounted(renderChart)
```

## 관련
- 이 버그는 정적/유닛 검사로 안 잡히고 **실브라우저 렌더로만** 드러남 → tester-frontend 렌더검증 의무화 근거(`agents/tester/tester-frontend.md` 영역1 렌더 검증).
- dev server가 stale 서빙하면 수정해도 옛 동작 → [[vite-stale-served-source-windows]]로 서빙 소스 확인.
- 관련 파일: autopatch-dashboard/src/components/dashboard/DailyExportChart.vue, ProjectRatioChart.vue
