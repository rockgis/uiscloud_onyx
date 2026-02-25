# Docker Compose 배포 가이드

Onyx는 다음과 같은 여러 배포 옵션을 지원합니다:

1. `install.sh` 스크립트를 통한 빠른 가이드 설치
2. 저장소를 클론하여 `deployment/docker_compose` 디렉토리에서 `docker compose up -d` 실행
3. 대규모 Kubernetes 배포를 위한 Helm 또는 Terraform

이 가이드는 `install.sh`를 통한 가장 쉬운 설치 방법에 중점을 둡니다.

**더 자세한 가이드**: https://docs.onyx.app/deployment/overview

---

## install.sh 스크립트

```bash
curl -fsSL https://raw.githubusercontent.com/onyx-dot-app/onyx/main/deployment/docker_compose/install.sh \
  > install.sh && chmod +x install.sh && ./install.sh
```

Docker Compose를 통한 Onyx의 가이드 설치를 제공합니다. 최신 버전의 Onyx를 배포하고, 배포 또는 업그레이드 간에 데이터가 유지되도록 볼륨을 설정합니다.

스크립트는 `onyx_data` 디렉토리를 생성하며, 배포에 필요한 모든 파일이 여기에 저장됩니다. 앱 복원에 필요한 중요한 데이터는 이 디렉토리에 저장되지 않으므로 삭제해도 됩니다.

채팅, 사용자 등에 대한 데이터는 Docker가 관리하는 이름 있는 Docker 볼륨에 저장됩니다.

---

## 주요 명령어

| 명령어 | 설명 |
|--------|------|
| `./install.sh` | Onyx 설치 또는 업그레이드 |
| `./install.sh --shutdown` | 데이터 삭제 없이 배포 종료 |
| `./install.sh --delete-data` | 모든 데이터 포함 삭제 |

---

## 업그레이드

Onyx는 SemVer를 따르며 모든 마이너 버전에서 하위 호환성을 유지합니다.

**업그레이드 단계:**

1. `install.sh --shutdown` 또는 `docker compose down`으로 컨테이너 종료
2. `install.sh`를 다시 실행 (기본값 `latest` 사용 시 자동으로 최신 버전으로 업데이트)
3. 또는 직접 docker compose 명령 실행:
   ```bash
   # latest 태그 사용 시 이미지 업데이트
   docker compose pull
   # 최신 버전으로 서비스 재시작
   docker compose up
   ```

---

## 환경 변수

Docker Compose 파일은 같은 디렉토리의 `.env` 파일을 찾습니다. `install.sh` 스크립트는 초기 설정 시 다운로드되는 `env.template`에서 이를 설정합니다.

**주요 환경 변수:**

| 변수 | 설명 |
|------|------|
| `IMAGE_TAG` | 실행할 Onyx 버전. 각 재배포 시 모든 업데이트를 받으려면 `latest`로 유지 권장 |
| `AUTH_TYPE` | 인증 방식 (`disabled`, `basic`, `oidc`, `saml`, `oauth2`) |
| `POSTGRES_USER` | PostgreSQL 사용자명 |
| `POSTGRES_PASSWORD` | PostgreSQL 비밀번호 |
| `SECRET_KEY` | 세션 보안을 위한 시크릿 키 |
| `FILE_STORE_BACKEND` | 파일 저장소 (`s3` 또는 `postgres`) |

---

## Docker Compose 서비스 구성

| 서비스 | 역할 | 포트 |
|--------|------|------|
| `nginx` | 리버스 프록시 | 80, 443 |
| `web_server` | Next.js 프론트엔드 | 3000 |
| `api_server` | FastAPI 백엔드 | 8080 |
| `background` | Celery 워커 | - |
| `relational_db` | PostgreSQL | 5432 |
| `index` | Vespa 벡터 DB | 8081 |
| `cache` | Redis | 6379 |
| `minio` | S3 파일 저장소 (선택) | 9000 |
| `inference_model_server` | 임베딩 추론 | - |
| `indexing_model_server` | 인덱싱 모델 | - |

---

## 배포 프로필

```bash
# MinIO S3 저장소 활성화 (기본)
COMPOSE_PROFILES=s3-filestore

# S3 + OpenSearch (Vespa 대체)
COMPOSE_PROFILES=s3-filestore,opensearch-enabled

# PostgreSQL 파일 저장소 (외부 서비스 불필요)
# COMPOSE_PROFILES 변수 제거 후:
FILE_STORE_BACKEND=postgres
```

---

## 비루트 사용자로 실행

보안을 위해 비루트 사용자로 실행하려면 `docker-compose.yml`에서 다음 서비스에 보안 컨텍스트를 추가하세요:

```yaml
# api_server, web_server 등:
security_opt:
  - no-new-privileges:true
user: "1001:1001"
```
