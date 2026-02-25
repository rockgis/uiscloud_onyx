# Onyx 채팅 위젯

어떤 웹사이트에도 AI 기반 대화를 제공하는 임베드 가능한 경량 채팅 위젯입니다. 최대 호환성과 최소 번들 크기를 위해 [Lit](https://lit.dev/) 웹 컴포넌트로 구축되었습니다.

---

## 보안 주의사항

> **항상 범위가 제한된 API 키를 위젯에 사용하세요.** API 키는 클라이언트 사이드 코드에 노출되므로 제한된 권한과 속도 제한이 있어야 합니다. 관리자 또는 전체 접근 키를 절대 사용하지 마세요.

---

## 주요 기능

| 기능 | 설명 |
|------|------|
| **경량** | ~100-150kb gzip 번들 |
| **완전 커스터마이즈 가능** | 색상, 브랜딩, 스타일링 |
| **반응형** | 데스크탑 팝업, 모바일 전체화면 |
| **Shadow DOM 격리** | 사이트와 스타일 충돌 없음 |
| **실시간 스트리밍** | SSE를 사용한 빠른 응답 |
| **두 가지 배포 모드** | 클라우드 CDN 또는 자체 호스팅 |
| **마크다운 지원** | 응답의 리치 텍스트 포매팅 |
| **세션 유지** | 페이지 리로드 후에도 대화 유지 |
| **두 가지 표시 모드** | 플로팅 런처 또는 인라인 임베드 |

---

## 빠른 시작

### 클라우드 배포 (권장)

웹사이트에 두 줄 추가:

```html
<!-- 위젯 로드 -->
<script type="module" src="https://cdn.onyx.app/widget/1.0/dist/onyx-widget.js"></script>

<!-- 설정 및 표시 -->
<onyx-chat-widget
  backend-url="https://cloud.onyx.app/api"
  api-key="your_api_key_here"
  mode="launcher"
>
</onyx-chat-widget>
```

위젯이 오른쪽 하단 모서리에 플로팅 버튼으로 나타납니다.

---

## 설정 옵션

### 필수 속성

| 속성 | 타입 | 설명 |
|------|------|------|
| `backend-url` | string | Onyx 백엔드 API URL |
| `api-key` | string | 인증을 위한 API 키 |

### 선택적 속성

| 속성 | 타입 | 기본값 | 설명 |
|------|------|--------|------|
| `agent-id` | number | `undefined` | 사용할 특정 에이전트/페르소나 |
| `agent-name` | string | `"Assistant"` | 헤더에 표시할 이름 |
| `logo` | string | Onyx 로고 | 커스텀 로고 이미지 URL |
| `primary-color` | string | `#1c1c1c` | 기본 브랜드 색상 (버튼, 강조) |
| `background-color` | string | `#e9e9e9` | 위젯 배경 색상 |
| `text-color` | string | `#000000bf` | 텍스트 색상 |
| `mode` | string | `"launcher"` | 표시 모드: `"launcher"` 또는 `"inline"` |
| `include-citations` | boolean | `false` | 응답에 인용 표시 포함 |

---

## 설정 예시

### 기본 설정

```html
<onyx-chat-widget
  backend-url="https://cloud.onyx.app/api"
  api-key="on_abc123"
>
</onyx-chat-widget>
```

### 전체 커스터마이징

```html
<onyx-chat-widget
  backend-url="https://cloud.onyx.app/api"
  api-key="on_abc123"
  agent-id="42"
  agent-name="지원 봇"
  logo="https://yoursite.com/logo.png"
  primary-color="#FF6B35"
  background-color="#FFFFFF"
  text-color="#1A1A1A"
  mode="launcher"
>
</onyx-chat-widget>
```

### 인라인 모드 (임베드)

```html
<div style="width: 400px; height: 600px;">
  <onyx-chat-widget
    backend-url="https://cloud.onyx.app/api"
    api-key="on_abc123"
    mode="inline"
  >
  </onyx-chat-widget>
</div>
```

---

## 표시 모드

### 런처 모드 (기본값)

오른쪽 하단 모서리에 플로팅 버튼이 나타납니다. 클릭하면 채팅 팝업이 열립니다.

- **데스크탑**: 버튼 위 400x600px 팝업
- **모바일 (<768px)**: 전체 화면 오버레이

### 인라인 모드

위젯이 페이지 레이아웃에 직접 임베드됩니다. 전용 지원 페이지에 적합합니다.

> **CSS 팁**: 위젯은 인라인 모드에서 컨테이너 크기를 채웁니다.

---

## 개발

### 사전 요구사항

- Node.js 18+ 및 npm
- Onyx 백엔드 API 접근 권한

### 설정

```bash
cd widget/
npm install

# 자체 호스팅 빌드용 예시 env 파일 복사
cp .env.example .env
```

### 개발 서버

```bash
npm run dev
# http://localhost:5173에서 핫 모듈 교체와 함께 열림
```

### 빌드 명령어

```bash
# 클라우드 배포 (설정 미포함)
npm run build:cloud

# 자체 호스팅 배포 (.env에서 설정 포함)
npm run build:self-hosted

# 표준 빌드 (cloud와 동일)
npm run build
```

---

## 프로젝트 구조

```
widget/
├── src/
│   ├── index.ts                 # 진입점
│   ├── widget.ts                # 메인 컴포넌트
│   ├── config/
│   │   ├── config.ts            # 설정 리졸버
│   │   └── build-config.ts      # 빌드 타임 설정 주입
│   ├── services/
│   │   ├── api-service.ts       # API 클라이언트 (SSE 스트리밍)
│   │   └── stream-parser.ts     # SSE 패킷 프로세서
│   ├── types/
│   │   ├── api-types.ts         # 백엔드 패킷 타입
│   │   └── widget-types.ts      # 위젯 설정 타입
│   └── styles/
│       ├── theme.ts             # 디자인 토큰
│       ├── colors.ts            # 색상 시스템
│       └── widget-styles.ts     # 컴포넌트 스타일
├── dist/                        # 빌드 출력
└── vite.config.ts
```

---

## API 통합

위젯이 사용하는 백엔드 엔드포인트:

### 1. 채팅 세션 생성

```
POST /chat/create-chat-session
Authorization: Bearer YOUR_API_KEY

{"persona_id": 42}

응답: {"chat_session_id": "uuid-here"}
```

### 2. 메시지 전송 (SSE 스트리밍)

```
POST /chat/send-chat-message
Authorization: Bearer YOUR_API_KEY

{
  "message": "사용자 질문",
  "chat_session_id": "uuid-here",
  "parent_message_id": 123,
  "origin": "widget",
  "include_citations": false
}

응답: Server-Sent Events 스트림
{"type": "message_start"}
{"type": "message_delta", "content": "안녕하세요"}
{"type": "stop"}
```

---

## 자체 호스팅 배포

```bash
# 1. .env 파일 생성
VITE_WIDGET_BACKEND_URL=https://your-backend.com
VITE_WIDGET_API_KEY=your_api_key

# 2. 설정이 포함된 빌드
npm run build:self-hosted

# 3. dist/onyx-widget.js를 서버에 배포
```

고객 임베드:

```html
<script type="module" src="https://your-cdn.com/onyx-widget.js"></script>
<onyx-chat-widget
  agent-id="1"
  agent-name="지원"
  logo="https://path-to-your-logo.com/"
>
</onyx-chat-widget>
```

---

## 브라우저 지원

| 브라우저 | 지원 버전 |
|---------|----------|
| Chrome/Edge (Chromium) | 90+ |
| Firefox | 90+ |
| Safari | 15+ |
| Mobile Safari (iOS) | 15+ |
| Mobile Chrome (Android) | 지원 |

---

## 성능

| 항목 | 값 |
|------|-----|
| **번들 크기** | ~100-150kb gzipped |
| **초기 로드** | Shadow DOM 즉시 렌더링 |
| **메시지 지연** | 실시간 SSE 스트리밍 (<100ms 첫 토큰) |
| **세션 유지** | sessionStorage (각 메시지마다 자동 저장) |
