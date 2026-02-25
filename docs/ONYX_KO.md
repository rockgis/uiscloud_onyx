# Onyx 프로젝트 한글 문서

> **Onyx** (구 Danswer) — 오픈소스 제네레이티브 AI 및 엔터프라이즈 검색 플랫폼

---

## 목차

1. [프로젝트 개요](#1-프로젝트-개요)
2. [주요 기능](#2-주요-기능)
3. [기술 스택](#3-기술-스택)
4. [아키텍처](#4-아키텍처)
5. [디렉토리 구조](#5-디렉토리-구조)
6. [지원 커넥터](#6-지원-커넥터-40)
7. [LLM 통합](#7-llm-통합)
8. [API 엔드포인트](#8-api-엔드포인트)
9. [배포 옵션](#9-배포-옵션)
10. [백그라운드 워커 (Celery)](#10-백그라운드-워커-celery)
11. [인증 및 권한](#11-인증-및-권한)
12. [데이터베이스](#12-데이터베이스)
13. [개발 환경 설정](#13-개발-환경-설정)
14. [테스트 전략](#14-테스트-전략)
15. [코드 품질 표준](#15-코드-품질-표준)
16. [보안 고려사항](#16-보안-고려사항)
17. [모니터링 및 로깅](#17-모니터링-및-로깅)
18. [확장 가이드](#18-확장-가이드)

---

## 1. 프로젝트 개요

Onyx는 기업의 문서, 애플리케이션, 구성원 정보를 하나로 연결하는 **자가 호스팅 가능한 AI 검색 및 채팅 플랫폼**입니다.

### 핵심 특징

| 항목 | 내용 |
|------|------|
| **라이선스** | MIT (Community Edition) |
| **자가 호스팅** | 완전한 에어갭(air-gapped) 환경 지원 |
| **LLM 호환성** | OpenAI, Anthropic, Gemini, Ollama, vLLM 등 모든 LLM |
| **엔터프라이즈** | SSO, RBAC, 멀티 테넌트 지원 |
| **검색 방식** | 하이브리드 검색 (벡터 + 키워드) + 지식 그래프 |

### 버전

- **Community Edition**: MIT 라이선스, `backend/onyx/`
- **Enterprise Edition**: 추가 기능, `backend/ee/`

---

## 2. 주요 기능

### AI 기능

| 기능 | 설명 |
|------|------|
| **커스텀 에이전트 (Persona)** | 고유한 지시사항, 지식베이스, 도구를 갖춘 AI 에이전트 구성 |
| **Deep Research** | 에이전틱 다단계 검색으로 심층 분석 수행 |
| **웹 검색** | Google PSE, Exa, Serper, Firecrawl 등 실시간 검색 |
| **RAG** | 하이브리드 검색 + 지식 그래프 기반 검색 증강 생성 |
| **Code Interpreter** | 코드 실행, 데이터 분석, 그래프 생성, 파일 처리 |
| **이미지 생성** | 프롬프트 기반 이미지 생성 |
| **Actions & MCP** | Model Context Protocol로 외부 시스템과 상호작용 |

### 데이터 연결

- 40개 이상의 외부 데이터 소스 커넥터
- 실시간 문서 동기화 및 권한 미러링
- 문서 간 관계를 추적하는 지식 그래프

### 협업 및 관리

- 채팅 세션 공유 및 피드백 수집
- 사용자 역할 관리 (기본 / 큐레이터 / 관리자)
- 사용 통계 및 분석

---

## 3. 기술 스택

### 백엔드

| 기술 | 용도 |
|------|------|
| Python 3.11 | 주 언어 |
| FastAPI | REST API 프레임워크 |
| SQLAlchemy | ORM |
| Alembic | DB 마이그레이션 |
| Celery | 비동기 작업 처리 |
| PostgreSQL | 관계형 DB |
| Redis | 캐싱 및 메시지 브로커 |
| Vespa | 벡터 검색 DB |
| LangChain | LLM 통합 프레임워크 |
| LiteLLM | 다중 LLM 제공자 추상화 |

### 프론트엔드

| 기술 | 용도 |
|------|------|
| Next.js 15+ | React 프레임워크 |
| React 18 | UI 라이브러리 |
| TypeScript | 타입 안전성 |
| Tailwind CSS | 스타일링 |
| SWR | 데이터 페칭 |
| @radix-ui | 접근성 UI 컴포넌트 |
| Playwright | E2E 테스팅 |

### 인프라

| 기술 | 용도 |
|------|------|
| Docker / Docker Compose | 컨테이너화 |
| Kubernetes / Helm | 오케스트레이션 |
| MinIO | S3 호환 파일 스토리지 |
| Sentry | 에러 추적 |
| PostHog | 사용자 분석 |

---

## 4. 아키텍처

```
┌─────────────────────────────────────────────────────────────────┐
│                          사용자 (브라우저)                        │
└──────────────────────────────┬──────────────────────────────────┘
                               │ HTTPS
                               ▼
┌─────────────────────────────────────────────────────────────────┐
│                        Nginx (리버스 프록시)                      │
└──────────────┬──────────────────────────────┬───────────────────┘
               │ /                            │ /api/
               ▼                              ▼
┌──────────────────────────┐  ┌───────────────────────────────────┐
│   Web Server (Next.js)   │  │   API Server (FastAPI, 포트 8080) │
│       포트 3000           │  │                                   │
│  - 페이지 렌더링           │  │  - REST API 엔드포인트             │
│  - 클라이언트 사이드 SWR   │  │  - 인증 / 권한 검증               │
│  - 라우팅                 │  │  - 채팅 스트리밍                   │
└──────────────────────────┘  └──────────────────┬────────────────┘
                                                  │
                    ┌─────────────────────────────┼────────────────────────────┐
                    │                             │                            │
                    ▼                             ▼                            ▼
┌───────────────────────┐  ┌──────────────────────────┐  ┌───────────────────────┐
│   PostgreSQL          │  │   Vespa (벡터 DB)         │  │   Redis               │
│   - 사용자/채팅 데이터  │  │   - 문서 청크 인덱스      │  │   - 세션 캐시          │
│   - 커넥터 설정        │  │   - 시맨틱 검색           │  │   - Celery 브로커      │
│   - 인덱싱 기록        │  │   - 키워드 검색           │  │   - 작업 결과          │
└───────────────────────┘  └──────────────────────────┘  └───────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                     Background Worker (Celery)                  │
│                                                                 │
│  Beat → Docfetching → Docprocessing → Light → Heavy → KG       │
│         (문서 수집)    (인덱싱 파이프라인)  (빠른 작업) (프루닝)  │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                      외부 데이터 소스 (40+)                      │
│  Slack, GitHub, Google Drive, Confluence, Jira, Notion, ...    │
└─────────────────────────────────────────────────────────────────┘
```

### 문서 인덱싱 파이프라인

```
외부 소스 → Docfetching Worker → Docprocessing Worker
                                      │
                    ┌─────────────────┼─────────────────────┐
                    ▼                 ▼                       ▼
             PostgreSQL          청킹 + 임베딩          Vespa 인덱스
            (메타데이터)        (임베딩 모델 서버)       (벡터 + BM25)
```

---

## 5. 디렉토리 구조

### 백엔드

```
backend/
├── onyx/                       # 커뮤니티 에디션 코어
│   ├── auth/                   # 인증 (OAuth2, SAML, OIDC, Basic)
│   ├── background/             # Celery 비동기 작업
│   │   └── celery/
│   │       └── tasks/
│   │           ├── periodic/   # 주기적 유지보수 작업
│   │           ├── docfetching/# 문서 수집
│   │           └── vespa/      # 검색 인덱싱
│   ├── chat/                   # 채팅 로직 (LLM 루프, 스트리밍)
│   ├── configs/                # 앱 설정 및 상수
│   ├── connectors/             # 40+ 외부 소스 커넥터
│   ├── db/                     # DB 모델 및 데이터 접근 계층
│   ├── document_index/         # Vespa / OpenSearch 통합
│   ├── file_processing/        # 파일 처리 파이프라인
│   ├── file_store/             # S3 / PostgreSQL / 로컬 저장소
│   ├── image_gen/              # 이미지 생성 통합
│   ├── indexing/               # 인덱싱 파이프라인
│   ├── kg/                     # 지식 그래프
│   ├── llm/                    # LLM 제공자 통합
│   ├── mcp_server/             # Model Context Protocol 서버
│   ├── natural_language_processing/
│   ├── server/                 # FastAPI 라우터 및 API
│   │   ├── api_key/            # API 키 관리
│   │   ├── documents/          # 커넥터, 문서, 자격증명 API
│   │   ├── features/           # 기능별 API (에이전트, MCP, 도구...)
│   │   ├── manage/             # 관리 API (LLM, 사용자, 임베딩...)
│   │   ├── query_and_chat/     # 채팅 및 검색 엔드포인트
│   │   └── settings/           # 설정 API
│   └── main.py                 # FastAPI 앱 진입점
│
├── ee/                         # 엔터프라이즈 에디션 확장
│   └── onyx/
│       ├── background/
│       ├── chat/
│       ├── db/
│       └── server/
│
├── alembic/                    # DB 마이그레이션
└── tests/                      # 테스트 스위트
    ├── unit/
    ├── external_dependency_unit/
    └── integration/
```

### 프론트엔드

```
web/src/
├── app/                        # Next.js App Router 페이지
│   ├── (auth)/                 # 인증 페이지 (로그인, 회원가입...)
│   ├── admin/                  # 관리자 인터페이스
│   ├── craft/                  # Craft AI 기능
│   ├── connector/              # 커넥터 설정
│   ├── mcp/                    # MCP 설정
│   └── api/                    # Next.js API 라우트
│
├── components/                 # 재사용 컴포넌트 (63개)
├── hooks/                      # React 훅 (46개)
├── icons/                      # SVG 아이콘 라이브러리
├── lib/                        # 유틸리티 및 비즈니스 로직
├── refresh-components/         # 디자인 시스템 컴포넌트
│   ├── buttons/
│   ├── inputs/
│   ├── texts/
│   └── ...
└── sections/                   # 페이지 섹션 컴포넌트
```

---

## 6. 지원 커넥터 (40+)

### 협업 도구
| 커넥터 | 설명 |
|--------|------|
| Slack | 채널 메시지 및 DM |
| Discord | 서버 메시지 |
| Microsoft Teams | 팀 채널 메시지 |
| Zulip | 스트림 메시지 |
| Asana | 작업 및 프로젝트 |
| ClickUp | 작업 관리 |
| Jira | 이슈 트래커 |
| Linear | 이슈 및 사이클 |

### 문서 및 위키
| 커넥터 | 설명 |
|--------|------|
| Confluence | 위키 페이지 |
| Notion | 노션 페이지 및 데이터베이스 |
| Gitbook | 기술 문서 |
| Outline | 팀 위키 |
| BookStack | 문서 관리 |
| Google Sites | 구글 사이트 |
| Wikipedia | 위키피디아 문서 |

### 개발 플랫폼
| 커넥터 | 설명 |
|--------|------|
| GitHub | 이슈, PR, 코드 |
| GitLab | 이슈, MR, 코드 |
| Bitbucket | 이슈, PR |

### 클라우드 스토리지
| 커넥터 | 설명 |
|--------|------|
| Google Drive | 문서, 스프레드시트 |
| SharePoint | 사이트 파일 |
| Dropbox | 파일 |
| S3 / R2 / GCS / OCI | 클라우드 스토리지 |
| Egnyte | 기업 파일 공유 |

### 이메일
| 커넥터 | 설명 |
|--------|------|
| Gmail | 이메일 |
| IMAP | 일반 이메일 서버 |

### CRM 및 영업
| 커넥터 | 설명 |
|--------|------|
| Salesforce | CRM 데이터 |
| HubSpot | 마케팅 및 CRM |
| Gong | 영업 통화 |

### 고객 지원
| 커넥터 | 설명 |
|--------|------|
| Zendesk | 지원 티켓 |
| Freshdesk | 고객 지원 |
| Document360 | 지식베이스 |

---

## 7. LLM 통합

### 지원 제공자

| 제공자 | 모델 예시 |
|--------|----------|
| **OpenAI** | GPT-4o, GPT-4 Turbo, GPT-3.5 |
| **Anthropic** | Claude 3.5 Sonnet, Claude 3 Opus |
| **Google Vertex AI** | Gemini 1.5 Pro, Gemini Flash |
| **Azure OpenAI** | GPT-4, GPT-3.5 (Azure 엔드포인트) |
| **AWS Bedrock** | Claude, Titan, Llama |
| **Ollama** | Llama, Mistral, Phi (자체 호스팅) |
| **OpenRouter** | 100+ 모델 통합 접근 |

### LLM 설정 위치

```
backend/onyx/llm/
├── well_known_providers/
│   ├── llm_provider_options.py     # 제공자 옵션 정의
│   ├── recommended-models.json     # 추천 모델 목록 (자동 업데이트)
│   └── auto_update_service.py      # GitHub에서 모델 목록 동기화
├── litellm_singleton/              # LiteLLM 싱글톤 관리
├── interfaces.py                   # LLM 인터페이스 정의
├── factory.py                      # LLM 인스턴스 생성
└── utils.py                        # 토큰 계산, 비용 추적
```

### 특징

- 동적 모델 목록 (GitHub 기반 자동 업데이트)
- 폐기 모델 자동 필터링 (2+ 주요 버전 뒤처진 모델 제외)
- 모델별 기능 감지 (이미지 입력, 스트리밍 등)
- 토큰 계산 및 비용 추적
- 다중 임베딩 모델 지원

---

## 8. API 엔드포인트

### 주요 API 구조

```
/api/
├── /auth/                      # 인증 (로그인, 회원가입, OAuth)
├── /user/                      # 사용자 정보 및 설정
├── /api-key/                   # API 키 CRUD
├── /documents/
│   ├── /connector/             # 커넥터 관리
│   ├── /document/              # 문서 조회/삭제
│   ├── /credential/            # 자격증명 관리
│   └── /cc-pair/               # 커넥터-자격증명 연결
├── /chat/                      # 채팅 (SSE 스트리밍)
├── /query/                     # 검색 API
├── /persona/                   # 에이전트 관리
├── /features/
│   ├── /build/                 # Craft 빌드 기능
│   ├── /mcp/                   # MCP 서버 설정
│   ├── /tool/                  # 도구 관리
│   ├── /web-search/            # 웹 검색 설정
│   ├── /document-set/          # 문서 세트
│   └── /notifications/         # 알림
├── /manage/
│   ├── /llm/                   # LLM 제공자 설정
│   ├── /embedding/             # 임베딩 모델 설정
│   ├── /admin/                 # 관리자 설정
│   └── /users/                 # 사용자 관리
├── /kg/                        # 지식 그래프 API
├── /federated/                 # 연합 검색
└── /public/                    # 공개 API
```

### 주요 엔드포인트

| 메서드 | 경로 | 설명 |
|--------|------|------|
| `POST` | `/api/chat/send-message` | 채팅 메시지 전송 (SSE 스트리밍) |
| `POST` | `/api/query/search` | 문서 검색 |
| `GET` | `/api/user` | 현재 사용자 정보 |
| `GET` | `/api/persona` | 에이전트 목록 |
| `POST` | `/api/persona` | 에이전트 생성 |
| `PUT` | `/api/persona/{id}` | 에이전트 수정 |
| `GET` | `/api/manage/connector` | 커넥터 목록 |
| `POST` | `/api/manage/connector` | 커넥터 생성 |
| `GET` | `/api/manage/llm/provider` | LLM 제공자 목록 |

> **주의**: 백엔드에 직접 접근하지 말고 항상 프론트엔드를 통해 API를 호출하세요.
> - 올바른 방법: `http://localhost:3000/api/persona`
> - 잘못된 방법: `http://localhost:8080/api/persona`

---

## 9. 배포 옵션

### 9.1 Docker Compose (권장 - 빠른 시작)

```bash
# 설치 스크립트 실행
curl -fsSL https://raw.githubusercontent.com/onyx-dot-app/onyx/main/deployment/docker_compose/install.sh \
  > install.sh && chmod +x install.sh && ./install.sh
```

**서비스 구성:**

| 서비스 | 역할 | 포트 |
|--------|------|------|
| `nginx` | 리버스 프록시 | 80, 443 |
| `web_server` | Next.js 프론트엔드 | 3000 |
| `api_server` | FastAPI 백엔드 | 8080 |
| `background` | Celery 워커 | - |
| `relational_db` | PostgreSQL | 5432 |
| `index` | Vespa 벡터 DB | 8081 |
| `cache` | Redis | 6379 |
| `minio` | S3 파일 스토리지 (선택) | 9000 |
| `inference_model_server` | 임베딩 추론 | - |

**배포 프로필:**

```bash
# 기본 (MinIO S3 저장소)
COMPOSE_PROFILES=s3-filestore

# OpenSearch 추가
COMPOSE_PROFILES=s3-filestore,opensearch-enabled

# PostgreSQL 파일 저장소 (외부 서비스 불필요)
# COMPOSE_PROFILES 제거 후 FILE_STORE_BACKEND=postgres 설정
```

### 9.2 Kubernetes (Helm)

```bash
# Helm 차트 위치
deployment/helm/

# 배포
helm install onyx ./deployment/helm/
```

### 9.3 Terraform (AWS ECS Fargate)

```bash
# Terraform 파일 위치
deployment/terraform/
```

### 9.4 배포 모드

**경량 모드** (기본값, 소규모 배포):
```env
USE_LIGHTWEIGHT_BACKGROUND_WORKER=true
```
- 단일 백그라운드 워커가 모든 작업 처리
- 자원 효율적, 개발 환경에 적합

**표준 모드** (대규모 배포):
```env
USE_LIGHTWEIGHT_BACKGROUND_WORKER=false
```
- 전문화된 워커 분리 (8종류)
- 워커별 독립적 확장 가능
- 프로덕션 환경에 적합

---

## 10. 백그라운드 워커 (Celery)

### 워커 종류

| 워커 | 역할 | 동시성 |
|------|------|--------|
| **Beat** | 주기적 작업 스케줄러 | 단일 스레드 |
| **Primary** | 핵심 작업 조정 | 4 스레드 |
| **Docfetching** | 외부 소스 문서 수집 | 설정 가능 |
| **Docprocessing** | 문서 인덱싱 파이프라인 | 설정 가능 |
| **Light** | 빠른 작업 (Vespa, 권한 동기화) | 높은 동시성 |
| **Heavy** | 문서 프루닝 | 4 스레드 |
| **KG Processing** | 지식 그래프 처리 | 설정 가능 |
| **Monitoring** | 시스템 모니터링 | 단일 스레드 |
| **User File Processing** | 사용자 업로드 파일 처리 | 설정 가능 |

### Docprocessing 파이프라인

```
문서 배치 수신
    │
    ▼
PostgreSQL에 문서 upsert
    │
    ▼
문서 청킹 (chunk)
    │
    ▼
컨텍스트 정보 추가
    │
    ▼
임베딩 생성 (임베딩 모델 서버 호출)
    │
    ▼
Vespa에 청크 쓰기
    │
    ▼
문서 메타데이터 업데이트
```

### 주기적 작업 스케줄

| 작업 | 주기 |
|------|------|
| 인덱싱 확인 | 15초 |
| 커넥터 삭제 확인 | 20초 |
| Vespa 동기화 | 20초 |
| 프루닝 | 20초 |
| KG 처리 | 60초 |
| 모니터링 | 5분 |
| 정리 작업 | 1시간 |

> **중요**: Celery 작업 수정 후에는 워커를 재시작해야 변경 사항이 적용됩니다.

---

## 11. 인증 및 권한

### 인증 방식

| 방식 | 설정값 | 설명 |
|------|--------|------|
| **Disabled** | `AUTH_TYPE=disabled` | 개발 환경용 (인증 없음) |
| **Basic** | `AUTH_TYPE=basic` | 사용자명/비밀번호 |
| **OIDC** | `AUTH_TYPE=oidc` | OpenID Connect (Okta, Auth0 등) |
| **SAML** | `AUTH_TYPE=saml` | SAML 2.0 (기업 SSO) |
| **OAuth2** | `AUTH_TYPE=oauth2` | Google, GitHub 소셜 로그인 |

### 사용자 역할

| 역할 | 권한 |
|------|------|
| **기본 (Basic)** | 채팅, 검색, 자신의 설정 관리 |
| **큐레이터 (Curator)** | + 에이전트, 문서 세트 관리 |
| **관리자 (Admin)** | + 커넥터, LLM, 사용자, 시스템 설정 |

### 접근 제어

- **RBAC**: 역할 기반 접근 제어
- **문서 권한 미러링**: 외부 소스의 권한을 그대로 반영
- **API 키**: 프로그래밍 방식 접근을 위한 키 발급

---

## 12. 데이터베이스

### 주요 엔티티

| 엔티티 | 설명 |
|--------|------|
| `User` | 사용자 계정 및 역할 |
| `ChatSession` | 대화 세션 |
| `ChatMessage` | 채팅 메시지 (질문/답변) |
| `Document` | 인덱싱된 문서 메타데이터 |
| `DocumentChunk` | 검색 단위 청크 |
| `Connector` | 데이터 소스 커넥터 설정 |
| `Credential` | 커넥터 자격증명 (암호화) |
| `ConnectorCredentialPair` | 커넥터-자격증명 연결 |
| `DocumentSet` | 문서 그룹 |
| `Persona` | AI 에이전트 설정 |
| `ChatFeedback` | 사용자 피드백 |
| `IndexAttempt` | 인덱싱 시도 기록 |

### 마이그레이션

```bash
# 가상환경 활성화
source .venv/bin/activate

# 마이그레이션 적용
alembic upgrade head

# 새 마이그레이션 생성
alembic revision -m "description"

# 멀티 테넌트 (엔터프라이즈)
alembic -n schema_private upgrade head
alembic -n schema_private revision -m "description"
```

### PostgreSQL 접속

```bash
docker exec -it onyx-relational_db-1 psql -U postgres -c "SELECT * FROM user;"
```

---

## 13. 개발 환경 설정

### 사전 요구사항

- Python 3.11+
- Node.js 18+
- Docker & Docker Compose
- uv (Python 패키지 관리자)

### 백엔드 설정

```bash
# 가상환경 활성화
source .venv/bin/activate

# 의존성 설치
uv pip install -e backend/

# 개발 서버 실행 (모든 서비스 필요)
cd backend
uvicorn onyx.main:app --reload --port 8080
```

### 프론트엔드 설정

```bash
cd web
npm install
npm run dev    # http://localhost:3000
```

### 환경 변수

주요 환경 변수 (`.env` 파일 또는 Docker Compose):

```env
# 인증
AUTH_TYPE=disabled                    # 개발 시

# 데이터베이스
POSTGRES_USER=postgres
POSTGRES_PASSWORD=password
POSTGRES_HOST=relational_db
POSTGRES_DB=onyx

# 검색 (Vespa)
VESPA_HOST=index
VESPA_PORT=8081

# 캐시 및 메시지 브로커
REDIS_HOST=cache
REDIS_PORT=6379

# 파일 저장소
FILE_STORE_BACKEND=s3
S3_ENDPOINT_URL=http://minio:9000
S3_AWS_ACCESS_KEY_ID=minioadmin
S3_AWS_SECRET_ACCESS_KEY=minioadmin

# LLM (OpenAI 예시)
OPENAI_API_KEY=sk-...

# Craft 기능
ENABLE_CRAFT=true

# 배포 모드
USE_LIGHTWEIGHT_BACKGROUND_WORKER=true
```

### 테스트 계정

- **이메일**: `a@example.com`
- **비밀번호**: `a`
- **접속 URL**: `http://localhost:3000`

---

## 14. 테스트 전략

### 테스트 종류

#### 1. 단위 테스트 (Unit Tests)

외부 서비스 의존성 없음. 모킹 사용.

```bash
source .venv/bin/activate
pytest -xv backend/tests/unit
```

#### 2. 외부 의존성 단위 테스트

PostgreSQL, Redis, Vespa 등 인프라는 실행 중이어야 함. Onyx 컨테이너는 불필요.

```bash
python -m dotenv -f .vscode/.env run -- pytest backend/tests/external_dependency_unit
```

#### 3. 통합 테스트

실제 Onyx 배포 환경 필요. 모킹 불가.

```bash
python -m dotenv -f .vscode/.env run -- pytest backend/tests/integration
```

#### 4. E2E 테스트 (Playwright)

모든 Onyx 서비스 + 웹 서버 실행 필요.

```bash
npx playwright test <TEST_NAME>
# 테스트 위치: web/tests/e2e/
```

### 테스트 작성 지침

- 복잡한 독립 모듈 → **단위 테스트**
- 인프라 연동 확인 → **외부 의존성 단위 테스트**
- 기능 전체 플로우 검증 → **통합 테스트** (우선)
- 프론트엔드-백엔드 연동 → **E2E 테스트**
- 통합 테스트의 `conftest.py` 및 `common_utils/`의 유틸리티 활용

---

## 15. 코드 품질 표준

### Python

```bash
# pre-commit 훅 설치 및 실행
pre-commit install
pre-commit run --all-files
```

- **타입 힌트**: 모든 함수에 엄격한 타입 힌트 필수
- **API 정의**: `response_model` 사용 금지, 함수 반환 타입으로만 명시
- **Celery 작업**: `@shared_task` 사용 (절대 `@celery_app` 사용 금지)
- **DB 작업**: `backend/onyx/db/` 또는 `backend/ee/onyx/db/` 내에서만 수행

### TypeScript/React

| 규칙 | 올바른 방법 | 잘못된 방법 |
|------|------------|------------|
| **Import** | `import { X } from "@/components/X"` | `import { X } from "../../X"` |
| **컴포넌트** | `function MyComp() {}` | `const MyComp = () => {}` |
| **Props** | `interface MyProps { ... }` | 인라인 타입 |
| **className** | `cn("base", cond && "extra")` | `` `base ${cond ? "extra" : ""}` `` |
| **색상** | `bg-background-neutral-01` | `bg-white`, `bg-gray-100` |
| **다크모드** | 금지 (`dark:` 클래스) | `dark:bg-black` |
| **텍스트** | `<Text mainAction>...</Text>` | `<h2>...</h2>`, `<p>...` |
| **버튼/입력** | `<Button>`, `<InputTypeIn>` | `<button>`, `<input>` |
| **아이콘** | `import SvgX from "@/icons/x"` | `import { X } from "lucide-react"` |
| **데이터 페칭** | `useSWR(...)` | `useEffect + fetch` |

---

## 16. 보안 고려사항

### 필수 보안 규칙

1. API 키, 시크릿은 절대 저장소에 커밋하지 않음
2. 자격증명은 암호화된 저장소에만 보관
3. 모든 입력은 Pydantic 모델로 검증
4. SQL 쿼리는 매개변수화된 방식으로 작성
5. HTTPS/TLS 반드시 활성화

### 프로덕션 배포 체크리스트

- [ ] SSL/TLS 인증서 설정
- [ ] 인증 방식 선택 (OIDC/SAML 권장)
- [ ] API 서버, DB, 인덱스, 캐시 포트 외부 노출 차단
- [ ] 환경 변수로 모든 시크릿 관리
- [ ] 도메인 및 DNS 설정
- [ ] 로그 회전 설정
- [ ] 정기적인 보안 업데이트 적용

### 보안 기능

- **자격증명 암호화**: 커넥터 자격증명 AES 암호화 저장
- **문서 권한 동기화**: 외부 소스 권한 실시간 반영
- **CORS 설정**: 허용된 출처만 접근 허용
- **Rate Limiting**: API 요청 속도 제한

---

## 17. 모니터링 및 로깅

### 로그 위치

```bash
backend/log/
├── api_server_debug.log        # FastAPI 서버 로그
├── background_debug.log        # Celery 워커 로그
├── web_server_debug.log        # Next.js 서버 로그
└── [service_name]_debug.log    # 기타 서비스 로그
```

### 헬스 체크

```bash
# 서비스 상태 확인
curl http://localhost:3000/api/health

# Celery 워커 확인
curl http://localhost:3000/api/manage/admin/celery/task-queue-status
```

### 모니터링 스택

| 도구 | 역할 |
|------|------|
| **Prometheus** | 메트릭 수집 |
| **Celery 모니터링** | 큐 상태, 워커 상태 |
| **Sentry** | 에러 추적 및 알림 |
| **PostHog** | 사용자 행동 분석 |

---

## 18. 확장 가이드

### 새로운 커넥터 추가

```python
# 1. backend/onyx/connectors/ 에 새 파일 생성

from onyx.connectors.interfaces import LoadConnector, PollConnector
from onyx.connectors.models import Document

class MyConnector(LoadConnector, PollConnector):
    def __init__(self, config: dict):
        self.config = config

    def load_credentials(self, credentials: dict) -> None:
        self.api_key = credentials["api_key"]

    def load_from_state(self) -> GenerateDocumentsOutput:
        # 초기 전체 로드
        ...

    def poll_source(self, start: datetime, end: datetime) -> GenerateDocumentsOutput:
        # 증분 업데이트
        ...
```

```python
# 2. backend/onyx/configs/constants.py 의 DocumentSource enum에 추가
class DocumentSource(str, Enum):
    MY_SOURCE = "my_source"
```

```python
# 3. backend/onyx/connectors/registry.py 에 매핑 추가
SOURCE_TO_CONNECTOR_MAP = {
    DocumentSource.MY_SOURCE: MyConnector,
    ...
}
```

### 새로운 API 엔드포인트 추가

```python
# backend/onyx/server/features/my_feature/api.py

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from onyx.auth.users import current_user
from onyx.db.engine import get_session

router = APIRouter(prefix="/my-feature", tags=["My Feature"])

@router.get("/")
def get_my_feature(
    user: User = Depends(current_user),
    db_session: Session = Depends(get_session),
) -> list[MyFeatureResponse]:    # response_model 사용 금지!
    ...
```

```python
# backend/onyx/main.py 에 라우터 등록
from onyx.server.features.my_feature.api import router as my_feature_router
app.include_router(my_feature_router)
```

### 새로운 Celery 작업 추가

```python
# backend/onyx/background/celery/tasks/my_tasks.py

from celery import shared_task  # @celery_app 사용 금지!

@shared_task(
    name="onyx.background.celery.tasks.my_tasks.my_task",
    queue="light",
)
def my_task(tenant_id: str, param: str) -> None:
    ...
```

---

## 부록

### 자주 사용하는 명령어

```bash
# 가상환경 활성화
source .venv/bin/activate

# 프론트엔드 개발 서버
cd web && npm run dev

# 백엔드 로그 모니터링
tail -f backend/log/api_server_debug.log

# PostgreSQL 쿼리
docker exec -it onyx-relational_db-1 psql -U postgres -c "SELECT * FROM user LIMIT 10;"

# 마이그레이션 실행
alembic upgrade head

# 모든 테스트 실행
pytest -xv backend/tests/unit
```

### 유용한 링크

- **프로젝트 GitHub**: https://github.com/onyx-dot-app/onyx
- **공식 문서**: https://docs.onyx.app
- **이슈 트래커**: https://github.com/onyx-dot-app/onyx/issues

---

*문서 최종 업데이트: 2026-02-25*
