# Jenkins 배포 설정 가이드

UISCloud Onyx를 Jenkins로 빌드하고 배포하는 방법을 설명합니다.

---

## 목차

1. [사전 요구사항](#1-사전-요구사항)
2. [Jenkins 플러그인 설치](#2-jenkins-플러그인-설치)
3. [Credentials 설정](#3-credentials-설정)
4. [Jenkins Pipeline Job 생성](#4-jenkins-pipeline-job-생성)
5. [GitHub Webhook 설정](#5-github-webhook-설정)
6. [파이프라인 파라미터](#6-파이프라인-파라미터)
7. [이미지 태그 전략](#7-이미지-태그-전략)
8. [배포 흐름](#8-배포-흐름)
9. [수동 배포](#9-수동-배포)
10. [롤백](#10-롤백)
11. [트러블슈팅](#11-트러블슈팅)

---

## 1. 사전 요구사항

### Jenkins 서버

| 요구사항 | 버전 |
|---------|------|
| Jenkins | 2.400 이상 |
| Java | 17 이상 |
| Docker | 24 이상 (Jenkins 서버에 설치) |
| Docker Compose v2 | 2.20 이상 |

Jenkins 실행 사용자가 `docker` 그룹에 속해야 합니다:

```bash
sudo usermod -aG docker jenkins
sudo systemctl restart jenkins
```

### 배포 대상 서버

- Docker + Docker Compose v2 설치
- `deployment/scripts/server-setup.sh`로 초기화 완료
- `/opt/uiscloud-onyx/.env` 파일 설정 완료
- Jenkins 서버에서 SSH 접근 가능

---

## 2. Jenkins 플러그인 설치

Jenkins 관리 → Plugin Manager → Available 에서 설치:

| 플러그인 | 역할 |
|---------|------|
| **Pipeline** | 선언적 파이프라인 지원 |
| **Git** | Git 연동 |
| **GitHub Branch Source** | GitHub Webhook 자동 처리 |
| **SSH Agent** | SSH 키 자격증명 주입 (`sshagent`) |
| **Credentials Binding** | `withCredentials` 지원 |
| **AnsiColor** | 컬러 로그 출력 |
| **Timestamper** | 빌드 로그에 타임스탬프 추가 |
| **Workspace Cleanup** | 빌드 후 워크스페이스 정리 |

설치 후 Jenkins 재시작:

```bash
sudo systemctl restart jenkins
```

---

## 3. Credentials 설정

Jenkins 관리 → Credentials → System → Global credentials → Add Credentials

### 3-1. GHCR 인증 정보 (필수)

GitHub Container Registry 푸시 권한이 필요합니다.

| 항목 | 값 |
|------|---|
| Kind | **Username with password** |
| Scope | Global |
| Username | GitHub 계정명 (예: `rockgis`) |
| Password | GitHub Personal Access Token |
| ID | `ghcr-credentials` |
| Description | GitHub Container Registry 인증 |

**GitHub PAT 생성 방법:**

1. GitHub → Settings → Developer settings → Personal access tokens → Tokens (classic)
2. `Generate new token (classic)` 클릭
3. 권한 선택:
   - `write:packages` (이미지 푸시)
   - `read:packages` (이미지 풀)
4. 토큰 복사

### 3-2. 배포 서버 SSH 키 (필수)

| 항목 | 값 |
|------|---|
| Kind | **SSH Username with private key** |
| Scope | Global |
| ID | `deploy-ssh-key` |
| Description | 배포 서버 SSH 키 |
| Username | 서버 SSH 사용자 (예: `ubuntu`) |
| Private Key | Enter directly → 키 내용 붙여넣기 |

**SSH 키 생성 (Jenkins 서버에서):**

```bash
# Jenkins 서버에서 SSH 키 쌍 생성
ssh-keygen -t ed25519 -C "jenkins-deploy" -f ~/.ssh/jenkins_deploy_key -N ""

# 공개키 출력 (배포 서버의 ~/.ssh/authorized_keys에 추가)
cat ~/.ssh/jenkins_deploy_key.pub

# 비밀키 출력 (Jenkins Credentials에 입력)
cat ~/.ssh/jenkins_deploy_key
```

**배포 서버에 공개키 등록:**

```bash
# 배포 서버에서 실행
echo "ssh-ed25519 AAAA...공개키내용..." >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
```

---

## 4. Jenkins Pipeline Job 생성

### 4-1. Multibranch Pipeline 생성 (권장)

여러 브랜치와 태그를 자동으로 감지합니다.

1. Jenkins 대시보드 → **New Item**
2. 이름: `uiscloud-onyx`
3. 타입: **Multibranch Pipeline** 선택
4. **OK** 클릭

**Branch Sources 설정:**

| 항목 | 값 |
|------|---|
| Source | GitHub |
| Credentials | GitHub 연동 토큰 |
| Repository HTTPS URL | `https://github.com/rockgis/uiscloud_onyx` |
| Discover branches | All branches |
| Discover tags | 체크 (`v*.*.*` 패턴 태그) |

**Build Configuration:**

| 항목 | 값 |
|------|---|
| Mode | by Jenkinsfile |
| Script Path | `Jenkinsfile` |

**Scan Multibranch Pipeline Triggers:**

- Periodically if not otherwise run: `1 hour` (폴백용)
- GitHub webhook으로 즉각 트리거 (5번 섹션 참조)

5. **Save** 클릭

### 4-2. 단일 Pipeline Job 생성 (간단 구성)

main 브랜치만 빌드하는 단순 구성입니다.

1. Jenkins → **New Item**
2. 이름: `uiscloud-onyx-deploy`
3. 타입: **Pipeline** 선택
4. **OK**

**Pipeline 섹션:**

| 항목 | 값 |
|------|---|
| Definition | Pipeline script from SCM |
| SCM | Git |
| Repository URL | `https://github.com/rockgis/uiscloud_onyx.git` |
| Credentials | GitHub 인증 |
| Branch | `*/main` |
| Script Path | `Jenkinsfile` |

**Build Triggers:**

- `GitHub hook trigger for GITScm polling` 체크

---

## 5. GitHub Webhook 설정

Jenkins가 GitHub push 이벤트를 실시간으로 받도록 설정합니다.

### 5-1. GitHub Repository Webhook 추가

1. GitHub → 저장소 → Settings → Webhooks → **Add webhook**

| 항목 | 값 |
|------|---|
| Payload URL | `https://{JENKINS_URL}/github-webhook/` |
| Content type | `application/json` |
| Secret | (선택사항) 랜덤 문자열 |
| Events | **Just the push event** 또는 원하는 이벤트 선택 |

2. **Add webhook** 클릭
3. Recent Deliveries에서 ✅ 표시 확인

### 5-2. Jenkins Multibranch Webhook (멀티브랜치 사용 시)

Multibranch Pipeline에서는 Payload URL을 다르게 설정합니다:

```
https://{JENKINS_URL}/multibranch-webhook-trigger/invoke?token={TOKEN}
```

`Multibranch Scan Webhook Trigger` 플러그인이 필요합니다.

---

## 6. 파이프라인 파라미터

`Jenkinsfile`의 `parameters` 블록에서 정의된 값들입니다. 빌드 실행 시 **Build with Parameters**에서 지정합니다.

| 파라미터 | 기본값 | 설명 |
|---------|--------|------|
| `DEPLOY_HOST` | (비어있음) | 배포 서버 IP/호스트명. **비워두면 배포 생략** |
| `DEPLOY_USER` | `ubuntu` | SSH 접속 사용자 |
| `DEPLOY_PATH` | `/opt/uiscloud-onyx` | 서버의 배포 디렉토리 |
| `SKIP_DEPLOY` | `false` | 빌드/푸시만 하고 배포 생략 |
| `SKIP_TESTS` | `false` | 테스트 단계 생략 (빠른 배포) |

### 자동 배포 조건

`DEPLOY_HOST`가 설정되어 있을 때 자동 배포가 실행되는 조건:

- `main` 브랜치 push
- `v*.*.*` 형식의 태그 push

다른 브랜치는 이미지 빌드/푸시만 수행합니다.

---

## 7. 이미지 태그 전략

| 트리거 | 생성되는 태그 | 배포 이미지 |
|--------|------------|-----------|
| main push | `:main`, `:sha-abc1234` | `:sha-abc1234` |
| `v1.2.3` 태그 | `:v1.2.3`, `:1.2.3`, `:1.2`, `:1`, `:latest` | `:v1.2.3` |
| 기타 브랜치 | `:branch-name`, `:sha-abc1234` | `:sha-abc1234` |

이미지 레지스트리:

```
ghcr.io/rockgis/uiscloud_onyx/web-server:{태그}
```

---

## 8. 배포 흐름

```
GitHub push/tag
    │
    ▼
Jenkins (Webhook 수신)
    │
    ▼
┌─────────────────────────┐
│  Stage: Checkout        │ ← 소스 코드 체크아웃
└────────────┬────────────┘
             ▼
┌─────────────────────────┐
│  Stage: Set Build Info  │ ← 브랜치/태그별 이미지 태그 결정
└────────────┬────────────┘
             ▼
┌─────────────────────────┐
│  Stage: Build Image     │ ← web/Dockerfile로 이미지 빌드
└────────────┬────────────┘
             ▼
┌─────────────────────────┐
│  Stage: Push Image      │ ← GHCR에 이미지 푸시 (로그인/로그아웃)
└────────────┬────────────┘
             ▼
┌─────────────────────────┐
│  Stage: Deploy          │ ← SSH로 서버 접속 후 deploy.sh 실행
│  (DEPLOY_HOST 설정 시)  │
└────────────┬────────────┘
             ▼
         완료 (성공/실패)
```

**Deploy 단계 서버 동작:**

1. 현재 실행 중인 이미지를 `PREVIOUS_WEB_IMAGE`로 `.env`에 백업
2. `.env`의 `UISCLOUD_WEB_IMAGE`를 새 이미지로 업데이트
3. `deploy.sh` 실행 → 이미지 풀 → `docker compose up -d` → 헬스 체크

---

## 9. 수동 배포

### Jenkins UI에서 수동 실행

1. Jenkins → `uiscloud-onyx` 파이프라인 선택
2. 브랜치 또는 태그 선택
3. **Build with Parameters** 클릭
4. 파라미터 입력:
   - `DEPLOY_HOST`: `192.168.1.100` (또는 도메인)
   - `DEPLOY_USER`: `ubuntu`
   - `DEPLOY_PATH`: `/opt/uiscloud-onyx`
5. **Build** 클릭

### CLI에서 수동 실행 (Jenkins CLI)

```bash
# Jenkins CLI 다운로드
curl -O http://{JENKINS_URL}/jnlpJars/jenkins-cli.jar

# 빌드 실행
java -jar jenkins-cli.jar \
  -s http://{JENKINS_URL} \
  -auth {USER}:{API_TOKEN} \
  build uiscloud-onyx/main \
  -p DEPLOY_HOST=192.168.1.100 \
  -p DEPLOY_USER=ubuntu \
  -p DEPLOY_PATH=/opt/uiscloud-onyx \
  -s -v
```

### API로 수동 실행

```bash
curl -X POST \
  "http://{JENKINS_URL}/job/uiscloud-onyx/job/main/buildWithParameters" \
  --user "{USER}:{API_TOKEN}" \
  --data "DEPLOY_HOST=192.168.1.100&DEPLOY_USER=ubuntu&DEPLOY_PATH=/opt/uiscloud-onyx"
```

---

## 10. 롤백

### 방법 1: Jenkins에서 이전 빌드로 롤백

1. Jenkins → 해당 Pipeline → 정상 작동하던 빌드 번호 선택
2. **Rebuild** 클릭
3. `SKIP_DEPLOY`를 `false`로, `DEPLOY_HOST` 설정 후 실행

### 방법 2: 서버에서 직접 롤백

```bash
# 배포 서버에서 실행
cd /opt/uiscloud-onyx

# .env에서 이전 이미지 확인
grep PREVIOUS_WEB_IMAGE .env

# 롤백 실행
bash scripts/deploy.sh --rollback
```

### 방법 3: 특정 이미지 태그로 롤백

```bash
# 배포 서버에서 실행
cd /opt/uiscloud-onyx

# 특정 버전으로 변경
sed -i "s|^UISCLOUD_WEB_IMAGE=.*|UISCLOUD_WEB_IMAGE=ghcr.io/rockgis/uiscloud_onyx/web-server:v1.0.0|" .env

# 배포
bash scripts/deploy.sh --no-pull
```

---

## 11. 트러블슈팅

### Docker 권한 오류

```
Got permission denied while trying to connect to the Docker daemon socket
```

**해결:**

```bash
sudo usermod -aG docker jenkins
sudo systemctl restart jenkins
```

### GHCR 로그인 실패

```
Error response from daemon: unauthorized
```

**확인:**

1. Jenkins Credentials의 `ghcr-credentials` ID 확인
2. GitHub PAT 권한: `write:packages` 포함 여부
3. PAT 만료 여부 확인

```bash
# 수동으로 로그인 테스트
echo "TOKEN" | docker login ghcr.io -u USERNAME --password-stdin
```

### SSH 연결 실패

```
ssh: connect to host X.X.X.X port 22: Connection refused
```

**확인:**

1. 배포 서버 방화벽 22번 포트 오픈 확인
2. Jenkins Credentials의 `deploy-ssh-key` SSH 키 확인
3. 수동 연결 테스트:

```bash
ssh -i /path/to/key -o StrictHostKeyChecking=no ubuntu@X.X.X.X
```

### .env 파일 없음 오류

```
.env 파일이 없습니다. 서버 초기 설정을 먼저 진행하세요.
```

**해결:** 배포 서버에서 초기 설정 실행

```bash
cd /opt/uiscloud-onyx
cp .env.example .env
nano .env  # 실제 값으로 변경
```

### 이미지 빌드 시 캐시 오류

```bash
# 캐시 없이 강제 재빌드
docker builder prune -f
```

### 파이프라인에서 파라미터가 보이지 않을 때

첫 번째 빌드 실행 후 파라미터가 등록됩니다. 이후 빌드부터 **Build with Parameters**로 나타납니다.

---

## 환경별 Credentials 구성 예시

여러 서버(개발/스테이징/프로덕션)에 배포하는 경우:

| Credential ID | 용도 |
|-------------|------|
| `ghcr-credentials` | GHCR 이미지 푸시 (공통) |
| `deploy-ssh-key-dev` | 개발 서버 SSH 키 |
| `deploy-ssh-key-staging` | 스테이징 서버 SSH 키 |
| `deploy-ssh-key-prod` | 프로덕션 서버 SSH 키 |

`Jenkinsfile`에서 환경에 따라 다른 Credential을 사용하도록 파라미터를 추가하거나, 브랜치별로 분기 처리할 수 있습니다.
