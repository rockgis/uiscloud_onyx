# Onyx 한국어 문서 목차

> 이 디렉토리는 Onyx 프로젝트의 모든 공식 문서를 한국어로 번역한 파일들을 포함합니다.

---

## 시작하기

| 문서 | 설명 |
|------|------|
| [프로젝트 전체 가이드](../ONYX_KO.md) | Onyx 프로젝트 종합 한국어 가이드 |
| [기여 가이드](CONTRIBUTING.md) | 프로젝트 기여 방법 |

---

## 기여 가이드

| 문서 | 설명 |
|------|------|
| [개발 환경 설정](contributing/dev_setup.md) | 로컬 개발 환경 구성 |
| [기여 프로세스](contributing/contribution_process.md) | 기여 절차 및 검토 과정 |
| [코드 품질 표준](contributing/best_practices.md) | 엔지니어링 원칙 및 스타일 가이드 |
| [macOS 설정](contributing/contributing_macos.md) | macOS 전용 설정 안내 |
| [VSCode 설정](contributing/contributing_vscode.md) | VSCode 디버거 설정 안내 |

---

## 백엔드

| 문서 | 설명 |
|------|------|
| [백그라운드 워커](backend/background_workers.md) | Celery 비동기 작업 시스템 |
| [커넥터 개발](backend/connectors.md) | 새로운 데이터 소스 커넥터 작성 방법 |
| [파일 저장소](backend/file_store.md) | S3 호환 파일 저장소 시스템 |
| [MCP 서버](backend/mcp_server.md) | Model Context Protocol 서버 |
| [프롬프트 캐싱](backend/prompt_cache.md) | LLM 프롬프트 캐싱 프레임워크 |
| [채팅 및 컨텍스트 관리](backend/chat.md) | 채팅 흐름 및 LLM 루프 아키텍처 |
| [DB 마이그레이션](backend/alembic.md) | Alembic 데이터베이스 마이그레이션 |

---

## 프론트엔드

| 문서 | 설명 |
|------|------|
| [웹 프론트엔드](web/README.md) | Next.js 프론트엔드 개요 및 개발 |
| [웹 코딩 표준](web/STANDARDS.md) | TypeScript/React 코딩 규칙 |

---

## 배포

| 문서 | 설명 |
|------|------|
| [Docker Compose](deployment/docker_compose.md) | Docker Compose 배포 가이드 |
| [Kubernetes (Helm)](deployment/helm.md) | Helm 차트를 이용한 Kubernetes 배포 |
| [Terraform (AWS)](deployment/terraform_aws.md) | AWS EKS + Terraform 배포 |

---

## 테스트

| 문서 | 설명 |
|------|------|
| [통합 테스트](testing/integration_tests.md) | 통합 테스트 작성 및 실행 |

---

## 기타 구성 요소

| 문서 | 설명 |
|------|------|
| [채팅 위젯](widget.md) | 임베드 가능한 채팅 위젯 |
| [데스크탑 앱](desktop.md) | macOS 데스크탑 앱 (Tauri) |
| [Chrome 확장](chrome_extension.md) | Chrome 브라우저 확장 프로그램 |
| [Prometheus 메트릭](metrics.md) | 모니터링 메트릭 레퍼런스 |

---

*마지막 업데이트: 2026-02-25*
