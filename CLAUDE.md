# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 프로젝트 개요

**습관 잔디**: 매일 할 습관을 체크하고 최근 12주 기록을 GitHub 잔디 형태로 보여주는 웹앱. `index.html` 한 파일에 HTML·CSS·JS가 모두 들어 있고, 서버·빌드·외부 라이브러리 없이 브라우저 `localStorage`에만 저장한다.

## 실행과 검증

- 실행: `index.html`을 브라우저로 직접 연다. 빌드 단계는 없다.
- 린트·빌드·테스트 명령은 아직 없다. npm 패키지나 빌드 도구를 새로 들이는 것은 사용자가 원하지 않았으므로, 필요하면 먼저 물어본다.
- 커밋 전 검사: `.claude/settings.json`의 `PreToolUse` 훅이 Claude가 실행하는 `git commit`을 가로채 `.claude/hooks/pre-commit.sh`를 돌린다. 스크립트 위쪽 `LINT_CMD`·`BUILD_CMD`·`TEST_CMD`(비어 있으면 `package.json`의 같은 이름 스크립트)를 lint → build → test 순으로 실행하고, 실패하면 exit 2로 커밋을 막는다. 지금은 명령이 없어서 경고만 띄우고 통과시킨다.
- 코드 리뷰: `review-code` 스킬(`.claude/skills/review-code/`)에 이 프로젝트용 체크리스트가 있고, `code-reviewer` 서브에이전트(`.claude/agents/`)가 이 스킬을 미리 로드해 읽기 전용으로 리뷰한다.

## 구조 (index.html)

- `<head>`의 작은 인라인 스크립트가 저장된 테마를 첫 렌더링 전에 `data-theme`으로 적용한다. 화면 깜빡임을 막기 위해서라 본문 스크립트로 옮기면 안 된다.
- 마크업에는 고정 골격, 추가/수정 모달(`<dialog id="habitDialog">`), 습관 카드 템플릿(`<template id="cardTpl">`)이 있다. 카드는 JS가 템플릿을 복제해 만든다.
- 본문 `<script>`는 `// ---- 이름` 주석으로 구역을 나눈다: 날짜 유틸 → streak → 데이터 검증과 저장소 → DOM → 렌더링 → 액션 → 테마 → 이벤트 연결.

### 상태와 렌더링

- 전역 상태: `habits`(습관 배열), `today`(캐시된 오늘 날짜 키), `storageOk`, `themePref`(`null`이면 시스템 테마), `editingId`.
- `render()`는 목록 전체를 다시 그린다. 체크를 토글할 때는 `toggle()`이 해당 카드 하나만 `renderCard()`로 교체하고, 선택자로 포커스를 원래 요소에 돌려놓는다.
- 클릭은 `#list`에 건 리스너 하나로 처리한다(`.cell`, `.check-today`, `[data-action]` 순으로 확인). 카드마다 리스너를 달지 않는다.
- 히트맵은 월요일 시작 12주 × 7행이고, `grid-auto-flow: column`으로 날짜 순서대로 칸을 채운다. 오늘 이후 칸은 `disabled`다.

### 데이터

- 저장 키 `habit-tracker:v1`의 형식은 `{ version: 1, habits: [{ id, name, emoji, color, createdAt, checks: { "YYYY-MM-DD": true } }] }`이다. 테마는 `habit-tracker:theme`에 따로 저장한다.
- 내보내기·가져오기도 같은 형식을 쓴다. 저장소나 파일에서 읽은 데이터는 모두 `normalize()`를 거친다. 형식이 틀리면 `null`을 돌려주므로, 가져오기에 실패해도 기존 데이터는 그대로 남는다. 습관에 필드를 추가할 때는 `normalize()`에도 검증과 기본값을 넣어야 한다.
- `localStorage` 접근은 모두 `try/catch`로 감싼다. 실패하면 `storageOk = false`가 되고 경고 배너가 뜬다.

### 날짜

- 날짜 키는 항상 로컬 기준 `toKey`/`parseKey`/`addDays`로 만든다. `toISOString()`은 UTC라 한국 시간 오전 9시 전에는 하루가 밀리므로 날짜 키에 쓰지 않는다.
- `key > today` 같은 문자열 비교는 0으로 채운 고정 길이 형식이라 성립한다.
- `today`는 캐시된 값이다. `visibilitychange`·`focus`·60초 타이머로 날짜가 바뀌었는지 확인해 다시 그리고, `toggle()`도 실행 전에 확인한다.

### 테마와 색

- 색은 `:root`의 CSS 변수로만 쓴다. 다크 값은 `@media (prefers-color-scheme: dark)` 블록과 `:root[data-theme="dark"]` 블록 두 곳에 똑같이 있으니 함께 고친다.
- 습관 색(`COLORS`)은 두 테마의 빈 칸 색과 3:1 이상 대비가 나오는 것만 쓴다. 카드에는 `--habit` 변수로 넘긴다.

## 관례

- 사용자 입력(습관 이름·이모지·가져온 JSON)은 `textContent`/`setAttribute`로만 DOM에 넣는다. `innerHTML`은 쓰지 않는다.
- 주석과 화면 문구는 한국어로 쓴다. 주석에는 "무엇"이 아니라 "왜"를 적는다.
- 이모지는 `firstGrapheme()`으로 첫 글자(그래핌) 하나만 남긴다. 이름은 30자 제한이다(입력창 `maxlength`와 `normalize()` 두 곳).
