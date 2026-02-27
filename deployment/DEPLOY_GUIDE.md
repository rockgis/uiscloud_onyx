# UISCloud 배포 가이드

## 개요

UISCloud는 **GitHub Actions**로 Docker 이미지를 자동 빌드하고, 서버에서 수동으로 `deploy.sh`를 실행하여 배포합니다.

```
개발자 코드 push
    → GitHub Actions 빌드 (ghcr.io에 이미지 push)
        → 서버에서 deploy.sh 실행 (이미지 pull + 컨테이너 교체)
```

---

## 아키텍처

| 구성 요소 | 역할 |
|-----------|------|
| `docker-compose.prod.yml` | Onyx 공식 프로덕션 Compose (업스트림) |
| `docker-compose.uiscloud.yml` | UISCloud 오버라이드 (웹 이미지 교체, 내부 포트 제거) |
| `.env` | 환경변수 (비밀번호, 도메인 등) |
| `ghcr.io/rockgis/uiscloud_onyx/web-server` | UISCloud 커스텀 웹 서버 이미지 |

---

## 1. 서버 최초 설정

> 처음 서버를 준비할 때만 실행합니다. 이미 설정된 서버라면 2번으로 이동하세요.

### 1-1. 자동 설정 (권장)

```bash
# Ubuntu 22.04+ 기준
bash <(curl -fsSL https://raw.githubusercontent.com/rockgis/uiscloud_onyx/main/deployment/scripts/server-setup.sh) \
  --domain yourdomain.com \
  --dir /opt/uiscloud
```

스크립트가 자동으로 수행하는 작업:
- Docker + Docker Compose v2 설치
- 저장소 클론 (`/opt/uiscloud`)
- `.env` 파일 생성 (템플릿 복사)
- UFW 방화벽 규칙 설정 (22, 80, 443 허용)
- ghcr.io 로그인 안내

### 1-2. 수동 설정

```bash
# 1. Docker 설치
curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker $USER
newgrp docker

# 2. 저장소 클론
git clone git@github.com:rockgis/uiscloud_onyx.git /opt/uiscloud
cd /opt/uiscloud

# 3. 환경 설정 파일 복사
cp deployment/docker_compose/.env.uiscloud.example deployment/docker_compose/.env

# 4. ghcr.io 로그인 (이미지가 private인 경우)
echo "GITHUB_TOKEN" | docker login ghcr.io -u USERNAME --password-stdin
```

---

## 2. 환경변수 설정

```bash
nano /opt/uiscloud/deployment/docker_compose/.env
```

### 필수 변경 항목

```bash
# ⚠️ 반드시 변경하세요 (기본값 그대로 사용 금지)

# 보안 키 (openssl rand -hex 32 로 생성)
ENCRYPTION_KEY_SECRET=<랜덤 64자 hex값>

# PostgreSQL 비밀번호
POSTGRES_PASSWORD=<강력한_비밀번호>

# MinIO 비밀번호 (세 곳 모두 동일하게)
MINIO_ROOT_PASSWORD=<강력한_비밀번호>
S3_AWS_SECRET_ACCESS_KEY=<강력한_비밀번호>  # MinIO와 동일하게

# 웹 도메인 (도메인이 있는 경우)
WEB_DOMAIN=https://yourdomain.com
```

### 선택 변경 항목

```bash
# LLM 모델 서버 비활성화 (외부 API만 사용 시 리소스 절약)
DISABLE_MODEL_SERVER=true

# 업스트림 Onyx 이미지 버전 고정 (기본: latest)
IMAGE_TAG=v3.4.1

# UISCloud 웹 이미지 버전 고정 (기본: latest)
UISCLOUD_WEB_IMAGE=ghcr.io/rockgis/uiscloud_onyx/web-server:main
```

### 보안 키 생성 방법

```bash
# ENCRYPTION_KEY_SECRET 생성
openssl rand -hex 32

# 강력한 비밀번호 생성
openssl rand -base64 24
```

---

## 3. 이미지 빌드 (GitHub Actions)

코드를 push하거나 Release를 발행하면 **자동으로** 이미지가 빌드됩니다.

### 트리거별 동작

| 트리거 | 빌드 | 이미지 태그 |
|--------|------|-------------|
| `main` branch push | ✅ | `:main`, `:sha-abc1234` |
| GitHub Release 발행 | ✅ | `:1.2.3`, `:1.2`, `:1`, `:latest` |
| workflow_dispatch (수동) | ✅ | 현재 브랜치 기준 |

### Release를 통한 버전 배포

```bash
# GitHub CLI로 Release 발행
gh release create v1.2.3 \
  --title "v1.2.3 — 한국어 UI 개선" \
  --notes "변경사항: ..."

# Actions 탭에서 빌드 확인
gh run list --limit 3
```

### 빌드 상태 확인

```bash
# 최근 워크플로우 실행 확인
gh run list --limit 5

# 특정 run 상세 확인
gh run view <RUN_ID>

# 빌드 로그 스트리밍
gh run watch <RUN_ID>
```

---

## 4. 서버 배포

### 4-1. 기본 배포 (`make deploy`)

```bash
cd /opt/uiscloud

# 최신 이미지 pull + 컨테이너 교체 + 헬스 체크
make deploy
```

내부적으로 `deployment/scripts/deploy.sh`를 실행합니다.

### 4-2. 직접 실행

```bash
bash /opt/uiscloud/deployment/scripts/deploy.sh
```

### 4-3. 고급 옵션

```bash
# 배포 시뮬레이션 (실제 변경 없음)
make deploy-dry

# 이미지 Pull 없이 배포 (이미 최신 이미지가 있을 때)
bash deployment/scripts/deploy.sh --no-pull

# 이전 버전으로 롤백
PREVIOUS_WEB_IMAGE=ghcr.io/rockgis/uiscloud_onyx/web-server:sha-abc1234 \
  bash deployment/scripts/deploy.sh --rollback
```

### 배포 스크립트 동작 순서

```
1. 전제 조건 확인 (.env 파일 존재 여부 등)
2. 현재 실행 중인 이미지 태그 저장 (롤백 대비)
3. ghcr.io에서 최신 이미지 Pull
4. docker compose up -d --wait (기존 컨테이너 무중단 교체)
5. 헬스 체크 (http://localhost/api/health, 최대 60초 대기)
6. 배포 결과 출력
```

---

## 5. 서비스 관리

### 상태 확인

```bash
# 컨테이너 상태
make status

# API 서버 헬스 체크
make health

# 실행 중인 이미지 버전 확인
cd deployment/docker_compose
docker compose -f docker-compose.prod.yml -f docker-compose.uiscloud.yml images
```

### 로그 확인

```bash
# 전체 로그 (실시간)
make logs

# 웹 서버만
make logs-web

# API 서버만
make logs-api

# 특정 서비스 + 시간 범위
cd deployment/docker_compose
docker compose -f docker-compose.prod.yml -f docker-compose.uiscloud.yml \
  logs --since 1h web_server api_server
```

### 서비스 재시작

```bash
# 웹 서버 + nginx만 재시작 (빠름)
make restart-web

# 전체 중지 후 재시작
make down && make up-prod
```

---

## 6. 버전 업그레이드

### UISCloud 웹 이미지 업그레이드

새 Release가 발행되면 ghcr.io에 새 이미지가 push됩니다.

```bash
# 서버에서 실행
cd /opt/uiscloud

# 특정 버전 지정 (선택사항)
# .env에서 UISCLOUD_WEB_IMAGE=ghcr.io/rockgis/uiscloud_onyx/web-server:1.2.3

# 배포
make deploy
```

### 업스트림 Onyx 업그레이드

업스트림 Onyx(백엔드, 모델 서버)의 새 버전으로 업그레이드할 때:

```bash
# .env에서 IMAGE_TAG 수정
nano deployment/docker_compose/.env
# IMAGE_TAG=v3.5.0

# 배포
make deploy
```

> ⚠️ **주의**: 업스트림 업그레이드 전에 [Onyx 릴리즈 노트](https://github.com/onyx-dot-app/onyx/releases)에서 Breaking Change를 반드시 확인하세요.

---

## 7. 롤백

```bash
# 방법 1: 이전 이미지 태그를 직접 지정
PREVIOUS_WEB_IMAGE=ghcr.io/rockgis/uiscloud_onyx/web-server:sha-abc1234 \
  bash deployment/scripts/deploy.sh --rollback

# 방법 2: .env에서 이미지 태그 변경 후 재배포
# UISCLOUD_WEB_IMAGE=ghcr.io/rockgis/uiscloud_onyx/web-server:1.1.0
make deploy
```

### 실행 중인 이미지 태그 확인 (롤백 전)

```bash
cd deployment/docker_compose
docker compose -f docker-compose.prod.yml -f docker-compose.uiscloud.yml \
  images web_server
```

---

## 8. 초기 관리자 계정 설정

배포 후 처음 접속 시 브라우저에서 관리자 계정을 생성합니다.

```
http://yourdomain.com → 회원가입 → 첫 번째 계정이 자동으로 관리자
```

또는 CLI로 생성:

```bash
# API 서버 컨테이너에서 실행
docker exec -it onyx-api_server-1 \
  python onyx/scripts/create_user.py \
  --email admin@example.com \
  --password <비밀번호> \
  --admin
```

---

## 9. LLM 설정

배포 후 관리자 페이지에서 LLM 프로바이더를 설정합니다.

```
http://yourdomain.com/admin/configuration/llm
```

지원 프로바이더: OpenAI, Anthropic, Azure OpenAI, Ollama (로컬), 기타 OpenAI 호환 API

---

## 10. 문제 해결

### 컨테이너가 시작되지 않을 때

```bash
# 컨테이너 상태 확인
cd deployment/docker_compose
docker compose -f docker-compose.prod.yml -f docker-compose.uiscloud.yml ps

# 실패한 컨테이너 로그
docker compose -f docker-compose.prod.yml -f docker-compose.uiscloud.yml logs api_server
```

### 이미지 Pull 실패 (ghcr.io 인증 오류)

```bash
# ghcr.io 로그인 (GitHub PAT, read:packages 권한 필요)
echo "<GITHUB_TOKEN>" | docker login ghcr.io -u <USERNAME> --password-stdin
```

### 포트 충돌 (80번 포트 사용 중)

```bash
# 80번 포트 사용 프로세스 확인
sudo lsof -i :80

# nginx 또는 apache 중지
sudo systemctl stop nginx
sudo systemctl stop apache2
```

### DB 마이그레이션 실패

```bash
# api_server 로그에서 alembic 에러 확인
docker logs onyx-api_server-1 2>&1 | grep -i alembic

# DB 접속 확인
docker exec -it onyx-relational_db-1 psql -U postgres -c "\l"
```

### 디스크 용량 부족

```bash
# 사용하지 않는 Docker 리소스 정리
docker system prune -f

# 오래된 이미지만 정리
docker image prune -a --filter "until=720h"
```

---

## Makefile 명령어 요약

```bash
make deploy          # 프로덕션 배포 (pull + up)
make deploy-dry      # 배포 시뮬레이션
make rollback        # 이전 버전 롤백

make status          # 컨테이너 상태
make health          # 헬스 체크
make logs            # 전체 로그
make logs-web        # 웹 서버 로그
make logs-api        # API 서버 로그

make up-prod         # 서비스 시작
make down            # 서비스 중지
make restart-web     # 웹 서버 재시작

make setup-env       # .env 파일 초기화
make setup-server    # 서버 초기 설정
```

---

## 디렉터리 구조

```
/opt/uiscloud/
├── deployment/
│   ├── docker_compose/
│   │   ├── docker-compose.prod.yml       # 업스트림 프로덕션 Compose
│   │   ├── docker-compose.uiscloud.yml   # UISCloud 오버라이드
│   │   ├── .env                          # 환경변수 (git 제외)
│   │   └── .env.uiscloud.example         # 환경변수 템플릿
│   └── scripts/
│       ├── deploy.sh                     # 배포 스크립트
│       └── server-setup.sh              # 서버 초기 설정
└── Makefile                              # 편의 명령어
```
