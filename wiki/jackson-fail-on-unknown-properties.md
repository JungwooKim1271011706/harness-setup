---
title: Jackson FAIL_ON_UNKNOWN_PROPERTIES 기본 활성 — 설정 XML에 POJO 없는 요소가 있으면 기동 실패
type: gotcha
links: [[spring-profile-bean-eval-timing]], [[hibernate-naming-strategy-explicit-name]]
sources:
  - sources/20260824T073311Z__khnp-cme-9.3.1.md (ConfigUtil XmlMapper 실측)
updated: 2026-08-24
---

**증상:** 설정 XML에 요소를 하나 추가했을 뿐인데 **애플리케이션이 기동조차 안 된다.** 반대로 POJO에 필드를 추가하고 XML을 안 고치면 조용히 기본값이 된다 — 두 방향의 증상이 비대칭이라 원인이 헷갈린다.

**진짜 원인:** Jackson의 `FAIL_ON_UNKNOWN_PROPERTIES`는 **기본 활성**이다. `XmlMapper`/`ObjectMapper`를 만들 때 이 옵션을 끄지 않으면, 설정 POJO에 **대응 필드가 없는 요소**가 XML에 존재하는 순간 역직렬화가 예외로 죽는다. 기동 경로에서 터지므로 스택트레이스가 설정 파싱이 아니라 컨텍스트 초기화로 보인다.

**회피:**
- **POJO ↔ XML 쌍은 같은 커밋에서 동시에 바꾼다.** 한쪽만 바꾸면 ① XML만 추가 → **기동 실패** ② POJO만 추가 → 무음 기본값.
- 관용적으로 받고 싶으면 명시적으로 끈다: `mapper.configure(DeserializationFeature.FAIL_ON_UNKNOWN_PROPERTIES, false)` 또는 POJO에 `@JsonIgnoreProperties(ignoreUnknown = true)`. **끄는 선택도 트레이드오프다** — 오타난 설정 키가 조용히 무시된다.
- 설정 스키마 변경은 **기동 스모크 1회**로 봉인한다(단위테스트는 매퍼를 따로 만들어 이 경로를 안 탈 수 있다).

**교훈:** "설정 파일에 한 줄 추가"는 무해해 보이지만 **역직렬화 계약 변경**이다. 계약 변경이면 양끝(POJO·XML)을 같이 본다 — `playbook-tdd.md` 7c.2의 양면(단언측 + 생성/입력측) 원칙과 같은 축.
