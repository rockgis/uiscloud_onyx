# UISCloud 배포 가이드

## 개요

UISCloud 배포는 **GitHub Releases**에서 배포 패키지를 다운로드하여 진행합니다.

```
GitHub Release 발행
    → 이미지 자동 빌드 (ghcr.io)
    → 배포 패키지 자동 생성 (uiscloud-deployment.tar.gz)
        → 서버에서 패키지 다운로드 → .env 설정 → deploy.sh 실행
```

### 배포 패키지 구성

Release를 발행하면 `uiscloud-deployment.tar.gz` 파일이 자동으로 첨부됩니다.

```
uiscloud-deployment/
├── docker-compose.prod.yml       # Onyx 프로덕션 서비스 정의
├── docker-compose.uiscloud.yml   # UISCloud 웹 이미지 오버라이드
├── .env.example                  # 환경변수 템플릿
├── deploy.sh                     # 배포 스크립트
├── server-setup.sh               # 서버 초기 설정 스크립트
└── README.md                     # 이 가이드
```

---

## 1. 서버 최초 설정

> 처음 서버를 준비할 때만 실행합니다. 이미 설정된 서버라면 [3. 배포 실행](#3-배포-실행)으로 이동하세요.

### 요구사항

- Ubuntu 22.04 LTS 이상
- sudo 권한
- 포트 80, 443 개방

### 자동 설정 스크립트 (권장)

```bash
# 최신 릴리즈 기준으로 서버 초기화
curl -fsSL \
  https://raw.githubusercontent.com/rockgis/uiscloud_onyx/main/deployment/scripts/server-setup.sh \
  | bash

# 옵션 지정 시
bash <(curl -fsSL \
  https://raw.githubusercontent.com/rockgis/uiscloud_onyx/main/deployment/scripts/server-setup.sh) \
  --version v1.0.0 \
  --dir /opt/uiscloud \
  --domain yourdomain.com
```

스크립트가 자동으로 수행하는 작업:
1. Docker + Docker Compose v2 설치
2. GitHub Releases에서 배포 패키지 다운로드 & 압축 해제
3. `.env` 파일 생성 (템플릿 복사)
4. UFW 방화벽 규칙 설정 (22, 80, 443 허용)
5. ghcr.io 로그인 안내

완료 후 `.env` 파일 편집이 필요합니다 — [2. 환경변수 설정](#2-환경변수-설정)을 참고하세요.

---

## 2. 수동 설치 (자동 스크립트 없이)

### 2-1. 배포 패키지 다운로드

```bash
# 설치 디렉터리 생성
sudo mkdir -p /opt/uiscloud
sudo chown $USER:$USER /opt/uiscloud
cd /opt/uiscloud

# 최신 릴리즈 다운로드
curl -fsSL \
  https://github.com/rockgis/uiscloud_onyx/releases/latest/download/uiscloud-deployment.tar.gz \
  | tar xz --strip-components=1

# 특정 버전 지정
curl -fsSL \
  https://github.com/rockgis/uiscloud_onyx/releases/download/v1.0.0/uiscloud-deployment.tar.gz \
  | tar xz --strip-components=1

# 실행 권한 부여
chmod +x deploy.sh server-setup.sh
```

### 2-2. Docker 설치 (미설치 시)

```bash
curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker $USER
newgrp docker
```

### 2-3. ghcr.io 로그인 (이미지가 private인 경우)

```bash
# GitHub Personal Access Token (read:packages 권한) 필요
echo "<GITHUB_TOKEN>" | docker login ghcr.io -u <USERNAME> --password-stdin
```

---

## 3. 환경변수 설정

```bash
cd /opt/uiscloud
cp .env.example .env
nano .env
```

### 필수 변경 항목

```bash
# ⚠️ 기본값 그대로 사용 금지 — 반드시 변경하세요

# 1. 보안 암호화 키 (아래 명령으로 생성)
#    openssl rand -hex 32
ENCRYPTION_KEY_SECRET=CHANGE_ME_USE_openssl_rand_hex_32

# 2. PostgreSQL 비밀번호
POSTGRES_PASSWORD=CHANGE_ME_STRONG_PASSWORD

# 3. MinIO 비밀번호 (세 항목 모두 동일하게 설정)
MINIO_ROOT_PASSWORD=CHANGE_ME_STRONG_PASSWORD
S3_AWS_SECRET_ACCESS_KEY=CHANGE_ME_STRONG_PASSWORD
```

### 선택 변경 항목

```bash
# 웹 도메인 (도메인이 있는 경우 — HTTPS 리다이렉트에 사용)
WEB_DOMAIN=https://yourdomain.com

# 업스트림 Onyx 이미지 버전 고정 (기본: latest)
IMAGE_TAG=v3.4.1

# UISCloud 웹 이미지 버전 변경 (기본: 릴리즈 버전으로 고정됨)
UISCLOUD_WEB_IMAGE=ghcr.io/rockgis/uiscloud_onyx/web-server:latest

# LLM 모델 서버 비활성화 (외부 API만 사용 시 리소스 절약)
# DISABLE_MODEL_SERVER=true
```

### 보안 키 생성

```bash
# ENCRYPTION_KEY_SECRET 생성
openssl rand -hex 32

# 강력한 비밀번호 생성
openssl rand -base64 24
```

---

## 4. 배포 실행

```bash
cd /opt/uiscloud
bash deploy.sh
```

배포 스크립트 동작 순서:

1. `.env` 파일 존재 여부 확인
2. ghcr.io에서 최신 이미지 Pull
3. `docker compose up -d --wait` (기존 컨테이너 무중단 교체)
4. 헬스 체크 (`/api/health`, 최대 60초 대기)
5. 배포 결과 출력

### 고급 옵션

```bash
# 배포 시뮬레이션 (실제 변경 없음)
bash deploy.sh --dry-run

# 이미지 Pull 생략 (이미 최신 이미지 보유 시)
bash deploy.sh --no-pull

# 이전 버전으로 롤백
PREVIOUS_WEB_IMAGE=ghcr.io/rockgis/uiscloud_onyx/web-server:v1.0.0 \
  bash deploy.sh --rollback
```

---

## 5. 첫 배포 후 설정

### 관리자 계정 생성

브라우저로 접속 후 회원가입하면 첫 번째 계정이 자동으로 관리자가 됩니다.

```
http://yourdomain.com
```

### LLM 프로바이더 연결

관리자 페이지에서 LLM을 설정합니다.

```
http://yourdomain.com/admin/configuration/llm
```

지원 프로바이더: OpenAI, Anthropic, Azure OpenAI, Ollama (로컬), 기타 OpenAI 호환 API

---

## 6. 버전 업그레이드

새 릴리즈가 발행되면 패키지를 다시 다운로드하고 배포합니다.

```bash
cd /opt/uiscloud

# 1. 새 릴리즈 패키지 다운로드 (.env는 덮어쓰지 않음)
curl -fsSL \
  https://github.com/rockgis/uiscloud_onyx/releases/latest/download/uiscloud-deployment.tar.gz \
  | tar xz --strip-components=1 --skip-old-files

# 2. 배포 (새 이미지 자동 적용)
bash deploy.sh
```

> `.env` 파일은 `--skip-old-files` 옵션으로 보호됩니다.

### 특정 버전으로 업그레이드

```bash
# .env에서 이미지 버전 수동 지정
nano .env
# UISCLOUD_WEB_IMAGE=ghcr.io/rockgis/uiscloud_onyx/web-server:v1.2.0

bash deploy.sh
```

### 업스트림 Onyx 업그레이드

```bash
# .env에서 IMAGE_TAG 수정
nano .env
# IMAGE_TAG=v3.5.0

bash deploy.sh
```

> ⚠️ 업스트림 업그레이드 전에 [Onyx 릴리즈 노트](https://github.com/onyx-dot-app/onyx/releases)에서 Breaking Change를 확인하세요.

---

## 7. 롤백

```bash
# 실행 중인 이미지 태그 확인
cd /opt/uiscloud
docker compose -f docker-compose.prod.yml -f docker-compose.uiscloud.yml images

# 이전 버전으로 롤백
PREVIOUS_WEB_IMAGE=ghcr.io/rockgis/uiscloud_onyx/web-server:v1.0.0 \
  bash deploy.sh --rollback
```

---

## 8. 서비스 관리

### 상태 확인

```bash
cd /opt/uiscloud

# 컨테이너 상태
docker compose -f docker-compose.prod.yml -f docker-compose.uiscloud.yml ps

# 헬스 체크
curl -fsS http://localhost/api/health && echo "✅ API 정상"
```

### 로그 확인

```bash
cd /opt/uiscloud

# 전체 로그 (실시간)
docker compose -f docker-compose.prod.yml -f docker-compose.uiscloud.yml logs -f

# 웹 서버만
docker compose -f docker-compose.prod.yml -f docker-compose.uiscloud.yml logs -f web_server

# API 서버만
docker compose -f docker-compose.prod.yml -f docker-compose.uiscloud.yml logs -f api_server
```

### 서비스 재시작 / 중지

```bash
cd /opt/uiscloud

# 웹 서버 재시작
docker compose -f docker-compose.prod.yml -f docker-compose.uiscloud.yml restart web_server nginx

# 전체 중지
docker compose -f docker-compose.prod.yml -f docker-compose.uiscloud.yml down

# 전체 시작
docker compose -f docker-compose.prod.yml -f docker-compose.uiscloud.yml up -d --wait
```

---

## 9. 문제 해결

### 이미지 Pull 실패 (ghcr.io 인증 오류)

```bash
# GitHub PAT (read:packages 권한) 로그인
echo "<GITHUB_TOKEN>" | docker login ghcr.io -u <USERNAME> --password-stdin
```

### 컨테이너가 시작되지 않을 때

```bash
cd /opt/uiscloud
# 실패한 컨테이너 로그 확인
docker compose -f docker-compose.prod.yml -f docker-compose.uiscloud.yml logs api_server
```

### 포트 충돌 (80번 포트 사용 중)

```bash
sudo lsof -i :80
sudo systemctl stop nginx   # 또는 apache2
```

### 디스크 용량 부족

```bash
# 사용하지 않는 Docker 리소스 정리
docker system prune -f
docker image prune -a --filter "until=720h"
```

---

## 10. GitHub Releases 확인

릴리즈 목록 및 배포 패키지 다운로드:

```
https://github.com/rockgis/uiscloud_onyx/releases
```

각 릴리즈에는 다음이 포함됩니다:
- `uiscloud-deployment.tar.gz` — 배포 패키지
- Docker 이미지: `ghcr.io/rockgis/uiscloud_onyx/web-server:{version}`
