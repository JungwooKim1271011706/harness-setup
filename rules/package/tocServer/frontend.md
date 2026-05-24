# tocServer 프론트엔드 규칙

## 기술 스택

- **템플릿**: JSP + JSTL (`c`, `fmt`, `fn`, `spring`)
- **커스텀 태그**: `crlib.tld` (`cr:` prefix) — 사내 UI 컴포넌트 라이브러리
- **i18n**: Spring `<spring:message>` 태그
- **JavaScript**: 페이지별 전역 객체 패턴 (`var _filter = {}`)
- **CSS**: 커스텀 클래스 (BEM 유사, 컴포넌트 기반)

---

## JSP 파일 헤더 (필수)

```jsp
<%@ page language="java" contentType="text/html; charset=UTF-8" %>
<%@ taglib prefix="c"      uri="http://java.sun.com/jsp/jstl/core" %>
<%@ taglib prefix="fmt"    uri="http://java.sun.com/jsp/jstl/fmt" %>
<%@ taglib prefix="spring" uri="http://www.springframework.org/tags" %>
<%@ taglib prefix="cr"     uri="/WEB-INF/tlds/crlib.tld" %>
<%-- 필요 시 추가 --%>
<%@ taglib prefix="fn"     uri="http://java.sun.com/jsp/jstl/functions" %>
```

---

## 페이지 레이아웃 구조

### mainframe.jsp (전체 레이아웃 페이지)
```jsp
<cr:head>
    <link type="text/css" rel="stylesheet" href="${_ctx}/resources/pages/common/css/mainframe.css${_dc}"/>
    <script type="text/javascript" src="${_ctx}/resources/pages/common/js/filter.js${_dc}"></script>
    <script type="text/javascript">
        cr.onLoad(function () {
            _common.init('${pageContext.session.maxInactiveInterval}', 'filter', '${exportFailFlag}');
            onReady();
        });
    </script>
</cr:head>

<cr:body>
    <%@include file="../common/_top.jsp"%>

    <div id="container">
        <div class="bct">
            <div class="wrap">
                <div class="bd">
                    <cr:splitpane id="mainPane" mode="vertical" ...>
                        <cr:splitview>
                            <%@include file="./_filter_meun_list.jsp"%>
                        </cr:splitview>
                        <cr:splitview>
                            <cr:tab id="tabPanel" cssClass="tabPanel" ...>
                                <cr:tab-group>
                                    <cr:tab-header>
                                        <cr:tab-menu id="m-list" title="" />
                                    </cr:tab-header>
                                    <cr:tab-wrapper>
                                        <cr:tab-content mode="html">
                                            <%@include file="./_smtp_list.jsp"%>
                                        </cr:tab-content>
                                    </cr:tab-wrapper>
                                </cr:tab-group>
                            </cr:tab>
                        </cr:splitview>
                    </cr:splitpane>
                </div>
            </div>
        </div>
    </div>
</cr:body>
```

### 서브 페이지 (`_xxx.jsp`) — include 대상
```jsp
<div class="page-wrap">
    <div class="contents-wrap bg-gray">
        <div class="contents-header">
            <div class="header-subject non-select">
                <spring:message code="Top.menu.filter" />
            </div>
        </div>
        <div class="contents-body">
            <div class="contents-form">
                <form class="form short-label" id="aptForm">
                    <!-- 폼 내용 -->
                </form>
            </div>
        </div>
    </div>
</div>
```

---

## 커스텀 태그 사용법 (`cr:` 접두사)

| 태그 | 용도 | 예시 |
|------|------|------|
| `<cr:head>` | 페이지 헤더 래퍼 (CSS/JS 포함) | `<cr:head> ... </cr:head>` |
| `<cr:body>` | 페이지 바디 래퍼 | `<cr:body> ... </cr:body>` |
| `<cr:input>` | 커스텀 input (radio, checkbox 등) | `<cr:input type="radio" id="x" name="y" checked="${val == 1}" value="1" />` |
| `<cr:splitpane>` | 분할 레이아웃 컨테이너 | mode="vertical", mainViewSize="308px" |
| `<cr:splitview>` | 분할 레이아웃 영역 | |
| `<cr:tab>` | 탭 컨테이너 | |
| `<cr:tab-group>` | 탭 그룹 | |
| `<cr:tab-header>` | 탭 헤더 영역 | |
| `<cr:tab-menu>` | 탭 메뉴 항목 | `<cr:tab-menu id="m-list" title="" />` |
| `<cr:tab-wrapper>` | 탭 컨텐츠 래퍼 | |
| `<cr:tab-content>` | 탭 컨텐츠 | mode="html" |

---

## i18n (다국어 처리)

- **모든 UI 텍스트**는 `<spring:message>` 사용 (하드코딩 금지)

```jsp
<spring:message code="Top.menu.filter" />
<spring:message code="Common.usability" />
<spring:message code="APTFilter.info.desc" />
```

---

## JavaScript 네이밍 컨벤션

- 도메인별 전역 객체: `var _도메인 = {};`
- 메서드명: `_도메인.동사+목적어()` camelCase

```javascript
var _filter = {};

_filter.doChangeSearchInput = function (el) { ... }
_filter.doFilterSearch = function (e, gridName) { ... }
_filter.changeAPTProductType = function (el) { ... }
_filter.aptsvrConTest = function (el) { ... }
```

- JSP에서 호출:
  ```jsp
  onClick="_filter.changeAPTProductType(this)"
  onclick="_filter.aptsvrConTest(this)"
  ```

- 페이지 초기화:
  ```javascript
  cr.onLoad(function () {
      _common.init('${pageContext.session.maxInactiveInterval}', '도메인명', '${exportFailFlag}');
      _maillog.init();  // 도메인 초기화
  });
  ```

---

## CSS 클래스 컨벤션

| 클래스 | 용도 |
|--------|------|
| `.page-wrap` | 서브 페이지 최상위 래퍼 |
| `.contents-wrap` | 컨텐츠 전체 래퍼 |
| `.contents-wrap.bg-gray` | 회색 배경 컨텐츠 |
| `.contents-header` | 컨텐츠 제목 영역 |
| `.header-subject` | 제목 텍스트 |
| `.contents-body` | 컨텐츠 본문 |
| `.contents-form` | 폼 영역 |
| `.form.short-label` | 짧은 라벨 폼 |
| `.row` | 폼 행 |
| `.label` | 라벨 셀 |
| `.field` | 입력 셀 |
| `.non-select` | 텍스트 선택 불가 |
| `.x-hidden` | 숨김 처리 (`display: none`) |

---

## 권한별 조건 렌더링

```jsp
<%-- 사용자 레벨에 따른 분기 --%>
<c:if test="${_level == 4}">  <%-- 슈퍼관리자 --%>
    ...
</c:if>

<%-- 동적 include --%>
<c:if test="${include eq 0}">
    <%@include file="./_smtp_list.jsp" %>
</c:if>
<c:if test="${include eq 1}">
    <%@include file="./_message_list.jsp" %>
</c:if>
```

---

## 반복 목록 패턴

```jsp
<c:forEach var="item" items="${list}">
    <c:choose>
        <c:when test="${item.vendor eq 'SECULETTER'}">Seculetter</c:when>
        <c:when test="${item.vendor eq 'FIREEYE'}">FireEye</c:when>
        <c:otherwise>${item.vendor}</c:otherwise>
    </c:choose>
</c:forEach>
```

---

## 데이터 바인딩 패턴

```jsp
<%-- 서버 데이터 → HTML 속성 --%>
<cr:input type="radio" name="productType" checked="${productType == 1}" value="1" />
<input type="text" name="host" value="${aptInfo.host}" placeholder="HOST" data-regex="Host" />
<input type="hidden" name="vendor" value="${aptInfo.vendor}" />
```

- `data-regex` 속성으로 클라이언트 유효성 검증 지정
- `data-minvalue`, `data-maxvalue` 로 범위 제한
