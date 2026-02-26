# Onyx Web Frontend — 아키텍처 문서

> 작성일: 2026-02-26
> 대상 버전: Next.js 16.1.6 / React 19.2.4

---

## 목차

1. [기술 스택](#1-기술-스택)
2. [디렉토리 구조](#2-디렉토리-구조)
3. [라우팅 구조](#3-라우팅-구조)
4. [미들웨어](#4-미들웨어)
5. [API 레이어](#5-api-레이어)
6. [인증 흐름](#6-인증-흐름)
7. [Provider 계층 구조](#7-provider-계층-구조)
8. [데이터 패칭 패턴](#8-데이터-패칭-패턴)
9. [컴포넌트 시스템](#9-컴포넌트-시스템)
10. [테마 / 색상 시스템](#10-테마--색상-시스템)
11. [i18n (국제화)](#11-i18n-국제화)
12. [CE / EE 이중 구조](#12-ce--ee-이중-구조)
13. [테스트 전략](#13-테스트-전략)
14. [환경 변수](#14-환경-변수)
15. [빌드 및 배포](#15-빌드-및-배포)

---

## 1. 기술 스택

### 코어 프레임워크
| 기술 | 버전 | 역할 |
|------|------|------|
| Next.js | 16.1.6 | 풀스택 웹 프레임워크 (App Router) |
| React | 19.2.4 | UI 라이브러리 |
| TypeScript | ^5.9.3 | 타입 시스템 (strict mode) |
| Tailwind CSS | ^3.4.17 | 유틸리티 CSS |

### 주요 런타임 의존성
| 분류 | 라이브러리 | 용도 |
|------|-----------|------|
| 데이터 패칭 | `swr ^2.1.5` | 클라이언트 데이터 페칭, 캐싱 |
| 전역 상태 | `zustand ^5.0.8` | 전역 상태 (일부) |
| 폼 관리 | `formik ^2.2.9` + `yup ^1.4.0` | 폼 + 유효성 검사 |
| 애니메이션 | `motion ^12.29.0` | 애니메이션 |
| 드래그앤드롭 | `@dnd-kit/*` | DnD 인터랙션 |
| UI 프리미티브 | `@radix-ui/*` | 접근성 UI 컴포넌트 |
| 테이블 | `@tanstack/react-table ^8.21.3` | 데이터 테이블 |
| 마크다운 | `react-markdown`, `rehype-*`, `remark-*` | 채팅 메시지 렌더링 |
| 수식 | `katex ^0.16.17` | LaTeX 수식 렌더링 |
| 코드 하이라이팅 | `highlight.js`, `lowlight` | 코드 블록 |
| 테마 | `next-themes ^0.4.4` | 다크/라이트 모드 |
| i18n | `next-intl ^4.8.3` | 국제화 (en/ko) |
| 모니터링 | `@sentry/nextjs ^10.27.0` | 에러 추적 |
| 분석 | `posthog-js ^1.176.0` | 제품 분석 |
| 결제 | `stripe ^17.0.0`, `@stripe/stripe-js ^4.4.0` | 결제 처리 (EE) |
| 디자인 시스템 | `@onyx/opal: ./lib/opal` | 로컬 Opal 패키지 |

### 개발 도구
| 도구 | 용도 |
|------|------|
| `@playwright/test ^1.39.0` | E2E 테스트 |
| `jest ^29.7.0` + `@testing-library/react` | 단위/통합 테스트 |
| `@typescript/native-preview (tsgo)` | 빠른 타입 체크 |
| `eslint-plugin-unused-imports` | 미사용 import 제거 |
| `prettier 3.1.0` | 코드 포맷 |
| `babel-plugin-react-compiler` | React Compiler (실험적) |

---

## 2. 디렉토리 구조

```
web/
├── src/
│   ├── app/                    # Next.js App Router (페이지 + API)
│   │   ├── layout.tsx          # 루트 레이아웃
│   │   ├── page.tsx            # 루트 페이지 (/)
│   │   ├── app/                # 메인 앱 (/app/*)
│   │   ├── admin/              # 관리자 (/admin/*)
│   │   ├── auth/               # 인증 (/auth/*)
│   │   ├── ee/                 # Enterprise Edition (/ee/*)
│   │   ├── craft/              # Onyx Craft 빌드 모드
│   │   ├── nrf/                # 비인증 진입 가능 뷰
│   │   ├── anonymous/          # 익명 사용자
│   │   └── api/                # Next.js API Routes
│   │
│   ├── components/             # 레거시/범용 React 컴포넌트
│   ├── refresh-components/     # 새 디자인 시스템 컴포넌트
│   ├── refresh-pages/          # 주요 페이지 컴포넌트 (AppPage 등)
│   ├── sections/               # 기능 단위 섹션 (sidebar, chat, input 등)
│   ├── providers/              # 전역 Context Providers
│   ├── hooks/                  # 커스텀 훅 (hook-per-file 패턴, 40+개)
│   ├── layouts/                # 레이아웃 프리미티브
│   ├── lib/                    # 유틸리티, API 함수, 타입
│   ├── interfaces/             # TypeScript 인터페이스
│   ├── i18n/                   # next-intl 설정
│   │   ├── routing.ts          # 로케일 라우팅 정의
│   │   └── request.ts          # 서버 사이드 locale 감지
│   ├── messages/               # 번역 파일
│   │   ├── en.json             # 영어
│   │   └── ko.json             # 한국어
│   ├── ee/                     # Enterprise Edition 전용 코드
│   └── ce.tsx                  # CE/EE 게이팅 유틸리티 (eeGated)
│
├── tests/
│   └── e2e/                    # Playwright E2E 테스트
│
├── lib/
│   └── opal/                   # @onyx/opal 로컬 디자인 시스템 패키지
│
├── tailwind-themes/
│   └── tailwind.config.js      # 커스텀 색상/폰트 테마 정의
│
├── middleware.ts               # Next.js Edge 미들웨어
├── next.config.js              # Next.js 설정
├── playwright.config.ts        # Playwright 기본 설정
├── playwright.i18n.config.ts   # i18n 전용 Playwright 설정
├── tailwind.config.js          # Tailwind 설정 (테마 로더)
└── package.json
```

### tsconfig.json 경로 별칭
```json
"@/*"         → "src/*"
"@tests/*"    → "tests/*"
"@public/*"   → "public/*"
"@opal/*"     → "lib/opal/src/*"
"@opal/types/*" → "lib/opal/src/types/*"
```

---

## 3. 라우팅 구조

Next.js **App Router** 기반. 모든 라우트는 `src/app/` 하위의 `page.tsx` / `layout.tsx` 파일로 정의.

### 라우트 그룹 개요

```
/                   app/page.tsx              루트 (→ /app 리다이렉트)
/app                app/app/page.tsx          메인 채팅/검색 앱  ← 인증 필요
/app/agents         app/app/agents/page.tsx   에이전트 목록
/app/settings/*     app/app/settings/         설정 페이지들
/admin/*            app/admin/                관리자 패널        ← 인증+관리자 권한
/auth/*             app/auth/                 인증 페이지 (공개)
/ee/admin/*         app/ee/admin/             EE 전용 관리자     ← EE 라이선스 필요
/craft/*            app/craft/                Onyx Craft 빌드 모드
/nrf/*              app/nrf/                  비인증 진입 가능 뷰
/anonymous/[id]     app/anonymous/            익명 사용자 채팅
```

### 전체 페이지 목록

#### `/app/*` — 메인 앱 (인증 필요)
| 경로 | 파일 |
|------|------|
| `/app` | `app/app/page.tsx` → `<AppPage />` |
| `/app/agents` | 에이전트 목록 |
| `/app/agents/create` | 에이전트 생성 |
| `/app/agents/edit/[id]` | 에이전트 편집 |
| `/app/settings` | 설정 홈 |
| `/app/settings/general` | 일반 설정 |
| `/app/settings/connectors` | 커넥터 설정 |
| `/app/settings/chat-preferences` | 채팅 환경설정 |
| `/app/settings/accounts-access` | 계정 접근 설정 |
| `/app/shared/[chatId]` | 공유 채팅 뷰 |

#### `/admin/*` — 관리자 패널
| 경로 | 설명 |
|------|------|
| `/admin/indexing/status` | 인덱싱 상태 (기본 관리자 홈) |
| `/admin/add-connector` | 커넥터 추가 |
| `/admin/connector/[ccPairId]` | 커넥터 상세 |
| `/admin/connectors/[connector]` | 커넥터별 OAuth |
| `/admin/assistants` | 어시스턴트 관리 |
| `/admin/actions/*` | MCP/OpenAPI 액션 |
| `/admin/bots/*` | 슬랙봇 관리 |
| `/admin/discord-bot/*` | Discord 봇 |
| `/admin/configuration/llm` | LLM 설정 |
| `/admin/configuration/search` | 검색 설정 |
| `/admin/configuration/chat-preferences` | 채팅 기본값 |
| `/admin/configuration/image-generation` | 이미지 생성 설정 |
| `/admin/configuration/web-search` | 웹 검색 설정 |
| `/admin/configuration/document-processing` | 문서 처리 설정 |
| `/admin/documents/sets` | 문서 세트 |
| `/admin/documents/explorer` | 문서 탐색기 |
| `/admin/documents/feedback` | 피드백 관리 |
| `/admin/embeddings` | 임베딩 모델 |
| `/admin/users` | 사용자 관리 |
| `/admin/api-key` | API 키 |
| `/admin/token-rate-limits` | 토큰 요청 제한 |
| `/admin/kg` | Knowledge Graph |
| `/admin/federated/[id]` | Federated 커넥터 |
| `/admin/billing` | 청구 |
| `/admin/debug` | 디버그 |
| `/admin/systeminfo` | 시스템 정보 |
| `/admin/document-index-migration` | 인덱스 마이그레이션 |

#### `/ee/admin/*` — EE 전용 (미들웨어에서 `/ee` 접두사 rewrite)
| 경로 | 설명 |
|------|------|
| `/admin/groups` | 그룹 관리 |
| `/admin/performance/usage` | 사용량 통계 |
| `/admin/performance/query-history` | 쿼리 이력 |
| `/admin/performance/custom-analytics` | 커스텀 분석 |
| `/admin/theme` | 테마 커스터마이징 |
| `/admin/standard-answer` | 표준 답변 |
| `/ee/admin/billing` | EE 청구 |
| `/ee/assistants/stats/[id]` | 어시스턴트 통계 |

#### `/auth/*` — 인증 페이지 (공개)
| 경로 | 설명 |
|------|------|
| `/auth/login` | 로그인 |
| `/auth/signup` | 회원가입 |
| `/auth/create-account` | 계정 생성 |
| `/auth/forgot-password` | 비밀번호 분실 |
| `/auth/reset-password` | 비밀번호 재설정 |
| `/auth/verify-email` | 이메일 인증 |
| `/auth/waiting-on-verification` | 인증 대기 |
| `/auth/join` | 초대 참여 |
| `/auth/impersonate` | 관리자 사용자 가장 |

### next.config.js 리다이렉트
```javascript
// 영구 리다이렉트 (308)
/chat        → /app
/chat/:path* → /app/:path*
/app/nrf     → /nrf
```

### next.config.js rewrites (개발 환경 API 프록시)
```javascript
/api/docs/**   → ${INTERNAL_URL}/docs/**
/openapi.json  → ${INTERNAL_URL}/openapi.json
```

---

## 4. 미들웨어

파일: `web/middleware.ts` (Next.js Edge Runtime)

### 처리 순서

```
모든 요청 (정적 자산 제외)
       │
       ▼
┌─────────────────────────────────────┐
│  1. 인증 검사 (Auth Guard)           │
│  보호 경로: /app, /admin,            │
│            /assistants, /connector  │
│  쿠키 없음? → /auth/login?next=...  │
└──────────────┬──────────────────────┘
               │
               ▼
┌─────────────────────────────────────┐
│  2. EE Route Rewrite                │
│  ENABLE_PAID_ENTERPRISE=true 일 때  │
│  /admin/groups → /ee/admin/groups   │
│  (기타 EE_ROUTES도 동일)            │
└──────────────┬──────────────────────┘
               │
               ▼
┌─────────────────────────────────────┐
│  3. i18n Locale 주입                │
│  NEXT_LOCALE 쿠키 읽기              │
│  x-next-intl-locale 헤더 설정      │
│  URL 변경 없음 (cookie-only)        │
└──────────────┬──────────────────────┘
               │
               ▼
            응답 진행
```

### 인증 쿠키
| 쿠키 이름 | 용도 |
|----------|------|
| `fastapiusersauth` | FastAPI Users 세션 쿠키 (기본 인증) |
| `onyx_anonymous_user` | 익명 사용자 식별 |

### EE Route 목록 (미들웨어 rewrite 대상)
```
/admin/groups
/admin/performance/usage
/admin/performance/query-history
/admin/theme
/admin/performance/custom-analytics
/admin/standard-answer
/assistants/stats
```

### i18n 전략
- `createMiddleware()` **미사용** (URL 내부 rewrite 부작용 존재)
- 쿠키(`NEXT_LOCALE`) → `x-next-intl-locale` 헤더 수동 주입
- URL 구조 변경 없음 ("without i18n routing" 모드)

---

## 5. API 레이어

### 아키텍처 다이어그램

```
Browser
  │  fetch("/api/persona")
  ▼
Next.js API Route
  src/app/api/[...path]/route.ts
  │
  │  (개발 환경)        (프로덕션)
  │  프록시 처리         nginx가 처리
  ▼
FastAPI Backend
  localhost:8080
  (INTERNAL_URL)
```

### API Route 파일 목록
| 파일 | 역할 |
|------|------|
| `api/[...path]/route.ts` | **메인 프록시** — 모든 HTTP 메서드 처리 |
| `api/chat/mcp/oauth/callback/route.ts` | MCP OAuth 콜백 |
| `auth/logout/route.ts` | 로그아웃 처리 |
| `auth/oauth/callback/route.ts` | Google OAuth 콜백 |
| `auth/oidc/callback/route.ts` | OIDC 콜백 |
| `auth/saml/callback/route.ts` | SAML 콜백 |
| `mcp/[[...path]]/route.ts` | MCP 서버 프록시 (MCP_INTERNAL_URL:8090) |
| `admin/connectors/[connector]/auth/callback/route.ts` | 커넥터 OAuth 콜백 |

### 메인 프록시 동작 (`api/[...path]/route.ts`)

```typescript
// 개발 환경에서만 활성화 (NODE_ENV === 'development')
// 프로덕션에서는 404 반환 (nginx가 처리)

// 특수 헤더 처리:
// - Transfer-Encoding: chunked → TransformStream으로 스트리밍 통과
// - Set-Cookie → 클라이언트로 전달
// - DEBUG_AUTH_COOKIE → 개발 시 원격 백엔드 인증 주입

// 모든 HTTP 메서드 지원: GET, POST, PUT, PATCH, DELETE, HEAD, OPTIONS
```

### 백엔드 URL 상수
```typescript
INTERNAL_URL     = process.env.INTERNAL_URL || "http://localhost:8080"  // FastAPI
MCP_INTERNAL_URL = process.env.MCP_INTERNAL_URL || "http://127.0.0.1:8090"  // MCP
HOST_URL         = process.env.WEB_DOMAIN || "http://localhost:3000"   // 프론트엔드
```

---

## 6. 인증 흐름

### 인증 타입 (`AuthType` enum)
| 타입 | 설명 |
|------|------|
| `basic` | 이메일/비밀번호 기본 인증 |
| `google_oauth` | Google OAuth |
| `oidc` | OpenID Connect (자동 IdP 리다이렉트) |
| `saml` | SAML SSO (자동 IdP 리다이렉트) |
| `cloud` | 클라우드 모드 (Google OAuth 사용) |

### 서버 사이드 인증 체크 (`lib/auth/requireAuth.ts`)

```
requireAuth()
  ├── getAuthTypeMetadataSS() — /auth/type 엔드포인트 호출
  ├── getCurrentUserSS()      — /me 엔드포인트 호출 (쿠키 전달)
  │
  ├── user == null?           → redirect("/auth/login")
  ├── !user.is_verified &&
  │   requiresVerification?  → redirect("/auth/waiting-on-verification")
  └── 정상                    → { user, authTypeMetadata }

requireAdminAuth()
  ├── requireAuth() 호출
  └── user.role ∉ [ADMIN, CURATOR, GLOBAL_CURATOR]?
      → redirect("/app")
```

### 서버 사이드 쿠키 처리 (`lib/userSS.ts`)
```typescript
// processCookies(): Next.js 요청 쿠키 → 백엔드 요청 헤더 변환
// DEBUG_AUTH_COOKIE 환경변수: 개발 시 fastapiusersauth 쿠키 주입
```

### 토큰 갱신
- `hooks/useTokenRefresh.ts` — 클라이언트 사이드 주기적 토큰 갱신
- `/api/auth/refresh` 엔드포인트 폴링

---

## 7. Provider 계층 구조

`app/layout.tsx` → `AppProvider` → 내부 계층 (바깥→안쪽 순)

```
<NextIntlClientProvider>      ← i18n (루트 레이아웃에서 직접)
  <ThemeProvider>             ← next-themes 다크/라이트 모드
    <TooltipProvider>         ← Radix UI 툴팁 전역 설정
      <PHProvider>            ← PostHog 분석
        <AppProvider>         ← 아래 Provider들 조합
          <SettingsProvider>        앱 설정, 피처 플래그, 모바일 감지
            <UserProvider>          현재 사용자, 인증, 설정 업데이트
              <AppBackgroundProvider>  채팅 배경 이미지 URL
                <ProviderContextProvider>  LLM 프로바이더 설정
                  <ModalProvider>          글로벌 모달 상태
                    <AppSidebarProvider>   사이드바 접힘/펼침 (쿠키 동기화)
                      <AppModeProvider>    search/chat/auto 모드 (EE-gated)
                        <QueryControllerProvider>  검색 쿼리 상태 (EE-gated)
                          <ToastProvider>  전역 알림 Toast
                            {children}
```

### Provider별 훅

| Provider | 훅 | 주요 제공 값 |
|----------|-----|------------|
| `SettingsProvider` | `useSettingsContext()` | `combinedSettings`, `isMobile`, 피처 플래그 |
| `UserProvider` | `useUser()` | `user`, `isAdmin`, `isCurator`, `refreshUser()` |
| `AppBackgroundProvider` | `useAppBackground()` | `backgroundUrl` |
| `ProviderContextProvider` | `useProviderContext()` | LLM 프로바이더 목록 |
| `ModalProvider` | `useModalContext()` | 모달 열기/닫기, `newTenantInfo`, `invitationInfo` |
| `AppSidebarProvider` | `useAppSidebarContext()` | `folded`, `setFolded()` |
| `AppModeProvider` | `useAppMode()` | `appMode`, `setAppMode()` (EE-gated) |
| `QueryControllerProvider` | `useQueryController()` | 검색 쿼리 제어 (EE-gated) |

### 페이지별 추가 Provider
| Provider | 위치 | 역할 |
|----------|------|------|
| `ProjectsProvider` | `app/app/layout.tsx` | 프로젝트 목록/상태 |

---

## 8. 데이터 패칭 패턴

### 패턴 1: 서버 사이드 직접 Fetch (SSR)

레이아웃/페이지 컴포넌트에서 초기 데이터 로드:

```typescript
// lib/userSS.ts 패턴
export const getCurrentUserSS = async (): Promise<User | null> => {
  const cookieString = processCookies(await cookies());
  const response = await fetch(buildUrl("/me"), {
    credentials: "include",
    next: { revalidate: 0 },       // 캐시 무효화
    headers: { cookie: cookieString },
  });
  return response.ok ? response.json() : null;
};

// app/layout.tsx에서 병렬 로드
const [combinedSettings, user, authTypeMetadata, locale, messages] =
  await Promise.all([
    fetchSettingsSS(),
    getCurrentUserSS(),
    getAuthTypeMetadataSS(),
    getLocale(),
    getMessages(),
  ]);
```

### 패턴 2: 클라이언트 SWR (주 패턴)

```typescript
// lib/fetcher.ts
export const errorHandlingFetcher = async <T>(url: string): Promise<T> => {
  const res = await fetch(url);
  if (res.status === 403) throw new RedirectError(res);
  if (!res.ok) throw new FetchError(res.statusText, res.status);
  return res.json();
};

// 컴포넌트에서 사용
const { data, error, isLoading } = useSWR("/api/persona", errorHandlingFetcher);
```

### 패턴 3: 상태 변경 (Mutate)

```typescript
const response = await fetch("/api/user/theme-preference", {
  method: "PATCH",
  headers: { "Content-Type": "application/json" },
  body: JSON.stringify({ theme_preference: themePreference }),
});
if (!response.ok) throw new Error("Failed");
// SWR mutate로 캐시 갱신
await mutate("/api/user");
```

### 패턴 4: 스트리밍 (채팅 응답)

API 프록시가 `TransformStream`으로 스트리밍 응답 통과:
```
Transfer-Encoding: chunked 또는 Content-Type: text/event-stream
→ TransformStream으로 청크 단위 클라이언트 전달
```

### 데이터 로딩 원칙

- **SSR은 인증/설정만**: 레이아웃에서는 인증 체크와 필수 설정만 SSR로 로드
- **클라이언트 SWR이 주**: 나머지 데이터는 컴포넌트에서 SWR로 클라이언트 패칭
- **컴포넌트 내 로드**: 데이터는 필요한 컴포넌트 안에서 로드 (props drilling 최소화)
- **Skeleton 표시**: 로딩 중에는 스켈레톤/플레이스홀더 표시

---

## 9. 컴포넌트 시스템

Onyx 프론트엔드는 **두 개의 컴포넌트 레이어**를 운영:

### A. `refresh-components/` — 새 디자인 시스템 (우선 사용)

Figma 디자인 스펙을 직접 구현한 새 컴포넌트들. 모든 신규 코드에서 이 컴포넌트를 우선 사용.

```
refresh-components/
├── buttons/
│   ├── Button.tsx           # 주 버튼 (prominence: primary/secondary/tertiary)
│   ├── LineItem.tsx         # 사이드바 메뉴 항목
│   ├── IconButton.tsx       # 아이콘 전용 버튼
│   ├── SidebarTab.tsx       # 사이드바 탭 (접힘 지원)
│   ├── SquareButton.tsx     # 정사각형 버튼
│   ├── Tag.tsx, Chip.tsx    # 태그, 칩
│   └── SidebarButton.tsx
├── inputs/
│   ├── InputTypeIn.tsx      # 텍스트 입력
│   ├── InputTextArea.tsx    # 텍스트 에어리어
│   ├── InputSelect.tsx      # 드롭다운 선택
│   ├── InputComboBox/       # 콤보박스
│   ├── InputAvatar.tsx      # 아바타 입력
│   ├── Switch.tsx           # 토글 스위치
│   ├── Checkbox.tsx         # 체크박스
│   └── PasswordInputTypeIn.tsx
├── texts/
│   ├── Text.tsx             # 타이포그래피 (Figma 스타일 플래그)
│   ├── Truncated.tsx        # 말줄임표 (텍스트 두 번 렌더링 — 너비 측정용)
│   └── ExpandableTextDisplay.tsx
├── Modal.tsx                # 모달
├── Popover.tsx              # 팝오버
├── Tabs.tsx                 # 탭
├── Collapsible.tsx          # 접기/펼치기
├── commandmenu/             # 커맨드 메뉴 (cmdk 기반)
├── messages/                # 알림 메시지
├── cards/                   # 카드
├── loaders/, skeletons/     # 로딩 상태
├── layouts/                 # 레이아웃 래퍼
├── modals/, popovers/       # 모달/팝오버
├── avatars/                 # 아바타
└── form/, tiles/, onboarding/
```

#### `Text` 컴포넌트 사용 패턴
```typescript
// Figma 타이포그래피 스펙을 플래그로 표현
<Text text03 mainAction>{name}</Text>
// text01~05: 색상 스케일
// mainAction, secondaryBody, etc.: 폰트 크기/굵기
```

### B. `@onyx/opal` — Opal 디자인 시스템 (로컬 패키지)

`lib/opal/` 에 위치한 로컬 워크스페이스 패키지. `@opal/*` 별칭으로 접근.

```
@opal/components    → Button, IconButton, Input 등 기본 컴포넌트
@opal/icons         → SVG 아이콘 컬렉션 (SvgX, SvgMoreHorizontal 등)
```

**아이콘 규칙**: `@opal/icons` 만 사용. `lucide-react`, `react-icons` 금지.

### C. `components/` — 레거시 컴포넌트

기존 컴포넌트들. 신규 개발 시 `refresh-components/`를 우선 사용하되, 기존 컴포넌트와의 통합이 필요한 경우 사용.

```
components/
├── ui/           Radix UI 기반 원시 컴포넌트 (shadcn 패턴)
├── admin/        관리자 레이아웃, 사이드바
├── settings/     설정 관련
├── icons/        createLogoIcon 유틸리티 (로고 다크모드 처리)
└── ...
```

### D. `sections/` — 기능 단위 섹션

```
sections/
├── sidebar/       AppSidebar, AdminSidebar, UserAvatarPopover 등
├── chat/          ChatScrollContainer, ChatUI
├── knowledge/     AgentKnowledgePane, SourceHierarchyBrowser
├── document-sidebar/
├── input/
└── modals/
```

### 컴포넌트 작성 규칙 요약
```typescript
// ✅ 올바른 패턴
function UserCard({ user }: UserCardProps) {         // 일반 함수 (arrow 함수 금지)
  return <Text text03 mainAction>{user.name}</Text>; // Text 컴포넌트 사용
}

interface UserCardProps {                             // 인터페이스 별도 추출
  user: User;
}

// ✅ 클래스명
<div className={cn("base", isActive && "active")}>  // cn() 유틸리티

// ❌ 금지
const UserCard = () => { ... }   // arrow function 컴포넌트
<h2>텍스트</h2>                  // naked HTML 텍스트
<div className="dark:bg-black">  // dark: Tailwind 수정자 (icons 제외)
<div className="bg-gray-100">    // 표준 Tailwind 색상 (커스텀 색상만 사용)
import { User } from "lucide-react" // 외부 아이콘 라이브러리
```

---

## 10. 테마 / 색상 시스템

### 아키텍처

```
src/app/css/colors.css          ← CSS 변수 정의 (Single Source of Truth)
tailwind-themes/tailwind.config.js  ← Tailwind 커스텀 색상 (CSS 변수 참조)
tailwind.config.js              ← 환경별 테마 로더 (NEXT_PUBLIC_THEME)
```

### CSS 변수 계층

```css
/* colors.css */
:root {
  /* 기반 색상 스케일 */
  --grey-00: #ffffff;
  --grey-10: #f5f5f5;
  /* ... --grey-00 ~ --grey-100 */

  /* 시맨틱 변수 (라이트 모드) */
  --text-01: var(--grey-90);
  --background-neutral-01: var(--grey-05);
  --border-01: var(--grey-15);
  /* ... */
}

.dark {
  /* 시맨틱 변수 (다크 모드 자동 반전) */
  --text-01: var(--grey-05);
  --background-neutral-01: var(--grey-85);
  /* ... */
}
```

### 커스텀 색상 카테고리

| 카테고리 | 클래스 예시 | 용도 |
|----------|-----------|------|
| 텍스트 | `text-text-01` ~ `text-text-05` | 텍스트 명도 스케일 |
| | `text-text-inverted-01` | 반전 텍스트 |
| 배경 | `bg-background-neutral-00` ~ `04` | 중립 배경 |
| | `bg-background-tint-00` ~ `04` | 틴트 배경 |
| 보더 | `border-border-01` ~ `05` | 보더 명도 스케일 |
| 액션 | `bg-action-link-01` ~ `06` | 링크/액션 색상 |
| | `bg-action-danger-01` ~ `06` | 위험/삭제 색상 |
| 상태 | `bg-status-info-01` ~ `05` | 정보 색상 |
| | `bg-status-success-01` ~ `05` | 성공 색상 |
| | `bg-status-warning-01` ~ `05` | 경고 색상 |
| | `bg-status-error-01` ~ `05` | 오류 색상 |
| 테마 | `bg-theme-primary-01` ~ | 브랜드 색상 |
| | `bg-theme-blue-01` ~ | 테마 색상 변형 |

### 다크 모드
- `ThemeProvider`(`next-themes`) → `attribute="class"` → `<html class="dark">`
- CSS 변수가 `.dark` 클래스에서 자동 반전
- **`dark:` Tailwind 수정자 사용 금지** (logo 아이콘의 `createLogoIcon` 내부 한정 허용)

### 커스텀 테마
```javascript
// NEXT_PUBLIC_THEME 환경변수로 커스텀 테마 로드
// tailwind-themes/custom/{themeName}/tailwind.config.js
// lodash merge로 기본 테마와 병합
```

---

## 11. i18n (국제화)

### 지원 언어
- `en` (영어, 기본값)
- `ko` (한국어)

### 아키텍처

```
클라이언트: NEXT_LOCALE 쿠키 설정 (document.cookie)
           ↓
미들웨어:  쿠키 읽기 → x-next-intl-locale 헤더 주입
           ↓
서버:      request.ts → 쿠키 읽기 → locale 결정 → messages 로드
           ↓
레이아웃:  getLocale() + getMessages() → NextIntlClientProvider
           ↓
컴포넌트:  useTranslations("namespace") / getTranslations("namespace")
```

### 핵심 파일

| 파일 | 역할 |
|------|------|
| `src/i18n/routing.ts` | 로케일 목록 + `localePrefix: 'never'` 설정 |
| `src/i18n/request.ts` | 서버 사이드 쿠키 기반 locale 감지 |
| `web/middleware.ts` | `x-next-intl-locale` 헤더 수동 주입 |
| `src/messages/en.json` | 영어 번역 (~200 키) |
| `src/messages/ko.json` | 한국어 번역 (~200 키) |
| `src/components/LanguageSwitcher.tsx` | EN/KO 토글 UI |

### 번역 네임스페이스
```
auth.*           로그인/회원가입
sidebar.*        사이드바 메뉴, 섹션 제목
chat.*           채팅 UI (컨텍스트 메뉴, 삭제/이름 변경 등)
settings.*       설정 페이지
admin.*          관리자 패널 메뉴
common.*         공통 액션 (save, cancel, delete...)
errors.*         에러 메시지
languageSwitcher.*  언어 전환 UI 레이블
```

### 컴포넌트별 사용법
```typescript
// 서버 컴포넌트
import { getTranslations } from "next-intl/server";
const t = await getTranslations("sidebar");
return <div>{t("newSession")}</div>;

// 클라이언트 컴포넌트 ("use client")
import { useTranslations } from "next-intl";
const t = useTranslations("sidebar");
return <div>{t("newSession")}</div>;
```

### 언어 전환 흐름
```
사용자 클릭 LanguageSwitcher
  → document.cookie = "NEXT_LOCALE=ko; max-age=31536000"
  → router.refresh()
  → 서버가 새 locale로 RSC 재페칭
  → 클라이언트 React 트리 업데이트
  → 페이지 새로고침 시 새 locale 유지
```

### 주의사항
- `createMiddleware(routing)` 미사용 — URL 내부 rewrite(`/app` → `/en/app`) 부작용
- `useMemo` 의존성 배열에 `t` 포함 여부 → `router.refresh()` 후 일부 stale 가능 (full reload 시 해결)

---

## 12. CE / EE 이중 구조

### 개념
Onyx는 Community Edition(CE)과 Enterprise Edition(EE)을 동일 코드베이스에서 운영.

### 게이팅 메커니즘

```typescript
// src/ce.tsx
export function eeGated<P extends {}>(EEComponent: ComponentType<P>): ComponentType<P> {
  function EEGatedWrapper(props: P) {
    const isEnterprise = usePaidEnterpriseFeaturesEnabled();
    if (!isEnterprise) return <Invisible>{props.children}</Invisible>;
    return createElement(EEComponent, props);
  }
  return EEGatedWrapper;
}
```

- **Provider로 사용 시**: CE에서 `Invisible`(children 패스스루)로 대체 → 훅은 context 기본값 사용
- **Leaf 컴포넌트로 사용 시**: CE에서 아무것도 렌더링 안 함

### EE 기능 목록
```typescript
// Provider 레벨 게이팅
export const AppModeProvider = eeGated(EEAppModeProvider);
export const QueryControllerProvider = eeGated(EEQueryControllerProvider);

// 라우트 레벨 게이팅 (미들웨어에서 /ee/* rewrite)
/admin/groups → /ee/admin/groups
/admin/performance/* → /ee/admin/performance/*
/admin/theme → /ee/admin/theme
/admin/standard-answer → /ee/admin/standard-answer
/assistants/stats/* → /ee/assistants/stats/*
```

### EE 활성화 환경변수
```bash
ENABLE_PAID_ENTERPRISE_EDITION_FEATURES=true   # 서버 사이드 (미들웨어 포함)
NEXT_PUBLIC_ENABLE_PAID_EE_FEATURES=true        # 클라이언트 사이드 (빌드 타임)
```

### EE 전용 코드 위치
```
src/ee/                    # EE 전용 컴포넌트/로직
src/app/ee/                # EE 전용 페이지 (미들웨어 rewrite로 접근)
```

---

## 13. 테스트 전략

### E2E 테스트 (Playwright) — 주 테스트 방식

```
tests/e2e/
├── admin/          관리자 페이지 테스트
├── auth/           인증 흐름
├── chat/           채팅 기능 (메시지 렌더링, 피드백, 스크롤 등)
├── connectors/     커넥터 관리
├── assistants/     어시스턴트 기능
├── mcp/            MCP 서버/OAuth
├── onboarding/     온보딩 플로우
├── i18n/           언어 전환 (language_switch.spec.ts)
├── global-setup.ts 테스트 전처리 (서버 준비, 유저 생성, 로그인)
├── constants.ts    테스트 상수
└── utils/          공유 유틸리티 (auth, chatActions, visualRegression 등)
```

**실행 명령:**
```bash
npx playwright test <TEST_FILE>
npx playwright test --config=playwright.i18n.config.ts  # i18n 전용
npx playwright test --project admin                     # admin 프로젝트
```

**테스트 프로젝트:**
| 프로젝트 | 특성 |
|---------|------|
| `admin` | 병렬 실행, `@exclusive` 태그 제외 |
| `exclusive` | 직렬 실행, 느린 테스트 |

**인증 패턴:**
- 글로벌 셋업에서 `admin_auth.json` 생성 → 모든 테스트에 주입 (pre-authenticated)
- 다른 사용자가 필요한 경우: `loginAsWorkerUser(page, testInfo.workerIndex)`

### 단위 테스트 (Jest)

```bash
npm test                 # 전체
npm run test:changed     # 변경된 파일만
npm run test:coverage    # 커버리지
npm run types:check      # tsgo 타입 체크
```

주요 단위 테스트 대상:
- `src/lib/utils.test.ts`
- `src/lib/hooks.llmResolver.test.ts`
- `src/refresh-components/inputs/Checkbox.test.tsx`

---

## 14. 환경 변수

### 서버 사이드 전용 (빌드/런타임)
| 변수 | 기본값 | 용도 |
|------|-------|------|
| `INTERNAL_URL` | `http://localhost:8080` | FastAPI 백엔드 URL |
| `MCP_INTERNAL_URL` | `http://127.0.0.1:8090` | MCP 서버 URL |
| `WEB_DOMAIN` | `http://localhost:3000` | 프론트엔드 호스트 |
| `AUTH_TYPE` | `basic` | 인증 타입 |
| `ENABLE_PAID_ENTERPRISE_EDITION_FEATURES` | `false` | EE 활성화 |
| `DEBUG_AUTH_COOKIE` | — | 개발 시 인증 쿠키 주입 |
| `OVERRIDE_API_PRODUCTION` | — | 프로덕션에서 API 프록시 활성화 |
| `CUSTOM_ANALYTICS_SECRET_KEY` | — | 커스텀 분석 활성화 |

### 클라이언트 사이드 (`NEXT_PUBLIC_*`)
| 변수 | 기본값 | 용도 |
|------|-------|------|
| `NEXT_PUBLIC_ENABLE_PAID_EE_FEATURES` | `false` | EE 클라이언트 활성화 |
| `NEXT_PUBLIC_CLOUD_ENABLED` | `false` | 클라우드 모드 |
| `NEXT_PUBLIC_POSTHOG_KEY` | — | PostHog 분석 키 |
| `NEXT_PUBLIC_THEME` | — | 커스텀 테마 이름 |
| `NEXT_PUBLIC_DISABLE_LOGOUT` | `false` | 로그아웃 버튼 숨김 |
| `NEXT_PUBLIC_ENABLE_STATS` | `false` | 성능 통계 오버레이 |

---

## 15. 빌드 및 배포

### 개발 환경
```bash
npm run dev              # Next.js 개발 서버 (Turbopack, localhost:3000)
npm run dev:profile      # 성능 프로파일링 포함

# 백엔드 연결
INTERNAL_URL=http://localhost:8080 npm run dev
```

### 빌드
```bash
npm run build    # Next.js 프로덕션 빌드 (output: "standalone")
npm run start    # 빌드된 서버 실행

npm run lint             # ESLint
npm run format           # Prettier 포맷
npm run format:check     # 포맷 검사
npm run types:check      # tsgo 타입 체크
```

### 프로덕션 아키텍처
```
클라이언트 브라우저
      │
      ▼
nginx (리버스 프록시)
  /api/* → FastAPI backend (localhost:8080)
  /*     → Next.js standalone server (localhost:3000)
      │
      ▼
Next.js (standalone)
  - output: "standalone" 모드
  - API Route는 개발에서만 활성 (프로덕션은 nginx가 /api/* 처리)
```

### next.config.js 주요 설정
```javascript
{
  output: "standalone",           // Docker/서버 배포용
  reactCompiler: true,            // React Compiler (실험적)
  typedRoutes: true,              // 타입 안전 라우팅
  productionBrowserSourceMaps: false,  // 프로덕션 소스맵 비활성
  transpilePackages: ["@onyx/opal"],   // 로컬 패키지 트랜스파일
}
```

### Sentry 통합
```javascript
// next.config.js를 withSentryConfig()로 래핑
// src/instrumentation.ts — 서버 사이드 Sentry
// src/instrumentation-client.ts — 클라이언트 사이드 Sentry
```

---

## 부록: 주요 코딩 규칙 요약

| 규칙 | 내용 |
|------|------|
| Import | `@/` 절대 경로 필수, 상대 경로 금지 |
| 컴포넌트 | `function Foo()` 형태, arrow function 금지 |
| Props | 별도 `interface FooProps {}` 추출 |
| 스타일 | `dark:` Tailwind 수정자 금지 (icons 예외) |
| 색상 | 커스텀 색상 변수만 (`text-text-01`, `bg-background-neutral-01`) |
| 아이콘 | `@opal/icons` 만 사용 |
| 텍스트 | `<Text>` 컴포넌트 사용, 직접 HTML 텍스트 노드 금지 |
| className | `cn()` 유틸리티 사용 |
| 데이터 패칭 | 클라이언트 SWR 기본, SSR은 인증/설정만 |
| 훅 | 파일당 하나의 훅 (`hooks/` 디렉토리) |
| 간격 | margin 대신 padding 우선 |
| 타입 | 엄격한 TypeScript, `any` 금지 |
