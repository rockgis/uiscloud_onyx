# Onyx MCP 서버

## 개요

Onyx MCP 서버는 [Model Context Protocol (MCP)](https://modelcontextprotocol.io/)를 통해 LLM이 Onyx 인스턴스에 연결하고 지식베이스와 검색 기능에 접근할 수 있게 합니다.

Onyx MCP 서버를 사용하면:
- 지식베이스 검색
- LLM에 웹 검색 제공
- Onyx에서 문서 업로드 및 관리

모든 접근 제어는 메인 Onyx 앱 내에서 관리됩니다.

---

## 인증

모든 요청에서 `Authorization` 헤더에 Onyx 개인 액세스 토큰 또는 API 키를 Bearer 토큰으로 제공하세요. MCP 서버는 모든 요청에서 빠르게 토큰을 검증하고 전달합니다.

---

## 기본 설정

| 항목 | 값 |
|------|-----|
| **전송 방식** | HTTP POST (MCP over HTTP) |
| **포트** | 8090 (API 서버와 도메인 공유) |
| **프레임워크** | FastMCP + FastAPI 래퍼 |
| **데이터베이스** | 없음 (모든 작업을 API 서버에 위임) |

---

## 아키텍처

```
┌─────────────────┐
│  LLM 클라이언트   │
│  (Claude 등)    │
└────────┬────────┘
         │ MCP over HTTP
         │ (POST with bearer)
         ▼
┌─────────────────┐
│  MCP 서버       │
│  포트 8090      │
│  ├─ 인증        │
│  ├─ 도구        │
│  └─ 리소스      │
└────────┬────────┘
         │ 내부 HTTP
         │ (인증됨)
         ▼
┌─────────────────┐
│  API 서버       │
│  포트 8080      │
│  ├─ /me (인증)  │
│  ├─ 검색 API    │
│  └─ ACL 체크    │
└─────────────────┘
```

---

## MCP 클라이언트 설정

### Claude Desktop

macOS의 Claude Desktop 설정 파일(`~/Library/Application Support/Claude/claude_desktop_config.json`)에 추가:

```json
{
  "mcpServers": {
    "onyx": {
      "url": "https://[YOUR_ONYX_DOMAIN]:8090/",
      "transport": "http",
      "headers": {
        "Authorization": "Bearer YOUR_ONYX_TOKEN_HERE"
      }
    }
  }
}
```

### 기타 MCP 클라이언트

대부분의 MCP 클라이언트는 커스텀 헤더와 함께 HTTP 전송을 지원합니다. 설정 방법은 클라이언트 문서를 참고하세요.

---

## 기능

### 도구 (Tools)

3개의 도구를 제공합니다:

| 도구 | 설명 |
|------|------|
| `search_indexed_documents` | Onyx에 인덱싱된 사용자의 개인 지식베이스 검색. 콘텐츠 스니펫, 점수, 메타데이터와 함께 순위가 매겨진 문서 반환 |
| `search_web` | 현재 이벤트 및 일반 지식을 위한 공개 인터넷 검색. 제목, URL, 스니펫이 있는 웹 검색 결과 반환 |
| `open_urls` | 특정 웹 URL에서 전체 텍스트 콘텐츠 가져오기. `search_web`으로 URL을 찾은 후 전체 페이지 콘텐츠를 가져올 때 유용 |

### 리소스 (Resources)

| 리소스 | 설명 |
|--------|------|
| `indexed_sources` | 테넌트에서 현재 인덱싱된 모든 문서 소스 목록 (예: `"confluence"`, `"github"`). `search_indexed_documents` 호출 시 결과 필터링에 사용 |

---

## 로컬 개발

### MCP 서버 실행

MCP 서버는 기본 `launch.json`의 `Run All Onyx Services` 작업으로 자동 실행됩니다. VSCode 디버거에서 독립적으로도 실행할 수 있습니다.

### MCP Inspector로 테스트

[MCP Inspector](https://github.com/modelcontextprotocol/inspector)는 MCP 서버 디버깅 도구입니다:

```bash
npx @modelcontextprotocol/inspector http://localhost:8090/
```

**Inspector 설정:**
1. OAuth 설정 메뉴 무시
2. **Authentication** 탭 열기
3. **Bearer Token** 인증 선택
4. Onyx Bearer 토큰 붙여넣기
5. **Connect** 클릭

연결 후 사용 가능한 것:
- 사용 가능한 도구 탐색
- 다른 파라미터로 도구 호출 테스트
- 요청/응답 페이로드 확인
- 인증 문제 디버깅

### 헬스 체크

서버 실행 확인:

```bash
curl http://localhost:8090/health
```

예상 응답:
```json
{
  "status": "healthy",
  "service": "mcp_server"
}
```

---

## 환경 변수

### MCP 서버 설정

| 변수 | 기본값 | 설명 |
|------|--------|------|
| `MCP_SERVER_ENABLED` | `false` | MCP 서버 활성화 ("true"로 설정) |
| `MCP_SERVER_PORT` | `8090` | MCP 서버 포트 |
| `MCP_SERVER_CORS_ORIGINS` | - | 쉼표로 구분된 CORS 출처 (선택) |

### API 서버 연결

| 변수 | 기본값 | 설명 |
|------|--------|------|
| `API_SERVER_PROTOCOL` | `http` | API 서버 연결 프로토콜 |
| `API_SERVER_HOST` | `127.0.0.1` | API 서버 호스트명 |
| `API_SERVER_URL_OVERRIDE_FOR_HTTP_REQUESTS` | - | 선택적 재정의 URL. 설정 시 protocol/host 변수보다 우선함. Onyx Cloud를 백엔드로 MCP 서버 자체 호스팅 시 사용 |
