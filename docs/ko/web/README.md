# 웹 프론트엔드 개요

[Next.js](https://nextjs.org/)로 구축된 프론트엔드입니다.

---

## 시작하기

Node.js / npm 설치: https://docs.npmjs.com/downloading-and-installing-node-js-and-npm

의존성 설치:

```bash
npm i
```

개발 서버 실행:

```bash
npm run dev
```

브라우저에서 [http://localhost:3000](http://localhost:3000)을 열어 결과를 확인하세요.

> **참고:** 위 주소에 접속이 안 되면 `WEB_DOMAIN` 환경 변수를 `http://127.0.0.1:3000`으로 설정하고 해당 주소로 접속해보세요.

> **팁:** `package.json` 변경 후 브랜치를 전환하면 [pre-commit](https://github.com/onyx-dot-app/onyx/blob/main/CONTRIBUTING.md#formatting-and-linting)이 설정된 경우 패키지가 자동으로 설치됩니다.

---

## 클라우드 백엔드 연결

로컬 프론트엔드 개발 서버를 클라우드 백엔드(예: 스테이징 또는 프로덕션)에 연결하여 테스트하려면 `web/` 디렉토리에 `.env.local` 파일을 생성하세요:

```text
# 클라우드 백엔드로 로컬 개발 서버 연결
INTERNAL_URL=https://st-dev.onyx.app/api

# 원격 백엔드 인증을 위한 디버그 auth 쿠키
# 개발 모드에서 API 요청에 자동으로 주입됩니다
# 값을 가져오는 방법:
#   1. https://st-dev.onyx.app (또는 대상 백엔드 URL)에 접속하여 로그인
#   2. DevTools (F12) → Application → Cookies → [백엔드 도메인]
#   3. "fastapiusersauth" 쿠키를 찾아 값을 복사
#   4. 아래에 값을 붙여넣기 (따옴표 없이)
DEBUG_AUTH_COOKIE=your_cookie_value_here
```

**중요 사항:**
- `.env.local` 파일은 `web/` 디렉토리에 생성해야 합니다 (`package.json`과 같은 레벨)
- 생성 또는 수정 후 개발 서버를 재시작해야 합니다
- `DEBUG_AUTH_COOKIE`는 개발 모드(`NODE_ENV=development`)에서만 사용됩니다
- `INTERNAL_URL`이 설정되지 않으면 프론트엔드는 `http://127.0.0.1:8080`의 로컬 백엔드에 연결됩니다
- `.env.local` 파일을 보안적으로 관리하고 버전 관리에 커밋하지 마세요

---

## 테스트 (Playwright)

> **주의:** 이 테스트 프로세스는 앱을 초기 상태로 리셋합니다!

전체 애플리케이션이 실행 중이어야 합니다.

### 1. Playwright 의존성 설치

```bash
npx playwright install
```

### 2. 테스트 실행

```bash
# 모든 테스트 실행
npx playwright test

# 단일 테스트 실행
npx playwright test landing-page.spec.ts

# 대화형 UI로 실행
npx playwright test --ui

# 브라우저 화면 보며 실행
npx playwright test --headed
```

### 3. 결과 확인

기본 출력 위치:

```
web/output/playwright/
```

### 4. 시각적 회귀 스크린샷

스크린샷은 테스트 실행 중 자동으로 캡처되어 `web/output/screenshots/`에 저장됩니다.

CI 실행 간 스크린샷을 비교하려면:

```bash
ods screenshot-diff compare --project admin
```
