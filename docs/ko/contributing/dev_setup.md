# 개발 환경 설정 가이드

Onyx는 완전히 기능하는 앱으로, 다음과 같은 외부 소프트웨어에 의존합니다:

- [PostgreSQL](https://www.postgresql.org/) — 관계형 DB
- [Vespa](https://vespa.ai/) — 벡터 DB / 검색 엔진
- [Redis](https://redis.io/) — 캐시
- [MinIO](https://min.io/) — 파일 저장소
- [Nginx](https://nginx.org/) — 개발 환경에서는 일반적으로 불필요

> **참고:**
> 이 가이드는 Docker 컨테이너로 외부 소프트웨어를 제공하면서 Onyx를 소스에서 빌드하고 실행하는 방법을 안내합니다. 개발 목적으로 이 조합이 더 편리합니다. 사전 빌드된 컨테이너 이미지를 사용하려면 아래 Docker 전체 스택 실행 방법을 참고하세요.

---

## 로컬 설정

### Python 버전

반드시 **Python 3.11**을 사용하세요.

- macOS에서 Python 3.11 설치는 [macOS 설정 가이드](contributing_macos.md)를 참고하세요.
- 낮은 버전 사용 시 코드 수정이 필요합니다.
- 높은 버전은 일부 라이브러리가 지원되지 않을 수 있습니다.

### 백엔드: Python 의존성

[uv](https://docs.astral.sh/uv/)를 사용하여 가상환경을 생성합니다:

```bash
uv venv .venv --python 3.11
source .venv/bin/activate
```

**Windows (명령 프롬프트):**
```bash
.venv\Scripts\activate
```

**Windows (PowerShell):**
```powershell
.venv\Scripts\Activate.ps1
```

Python 의존성 설치:

```bash
uv sync --all-extras
```

웹 커넥터에 필요한 Playwright 설치:

```bash
uv run playwright install
```

---

### 프론트엔드: Node.js 의존성

Onyx는 **Node v22.20.0**을 사용합니다. [Node Version Manager (nvm)](https://github.com/nvm-sh/nvm)을 사용하는 것을 강력 권장합니다:

```bash
nvm install 22 && nvm use 22
node -v  # 현재 버전 확인
```

`onyx/web` 디렉토리로 이동 후 실행:

```bash
npm i
```

---

## 코드 포매팅 및 린팅

### 백엔드

pre-commit 훅(black, reorder-python-imports)을 설정합니다:

```bash
uv run pre-commit install
```

정적 타입 체크는 `mypy`를 사용합니다. Onyx는 완전히 타입 어노테이션되어 있습니다:

```bash
# onyx/backend 디렉토리에서 실행
uv run mypy .
```

### 프론트엔드

`prettier`를 사용합니다. `npm i` 실행 시 자동 설치됩니다:

```bash
# onyx/web 디렉토리에서 실행
npx prettier --write .
```

> pre-commit이 최근 수정한 파일에 자동으로 prettier를 실행합니다. 재포맷된 경우 커밋이 실패하며, 변경 사항을 다시 스테이징하고 커밋해야 합니다.

---

## 개발 모드로 실행

### VSCode 디버거 사용 (권장)

**VSCode 디버거를 강력히 권장합니다.** 자세한 내용은 [VSCode 설정 가이드](contributing_vscode.md)를 참고하세요.

### 수동 실행

#### 1. 외부 소프트웨어용 Docker 컨테이너 시작

`onyx/deployment/docker_compose`로 이동 후:

```bash
docker compose -f docker-compose.yml -f docker-compose.dev.yml up -d index relational_db cache minio
```

> `index` = Vespa, `relational_db` = PostgreSQL, `cache` = Redis

#### 2. 프론트엔드 시작

`onyx/web` 디렉토리에서:

```bash
npm run dev
```

#### 3. 모델 서버 시작 (로컬 NLP 모델)

`onyx/backend`에서:

```bash
uvicorn model_server.main:app --reload --port 9000
```

**Windows:**
```bash
powershell -Command "uvicorn model_server.main:app --reload --port 9000"
```

#### 4. DB 마이그레이션 실행 (최초 1회)

`onyx/backend`에서 (venv 활성화 후):

```bash
alembic upgrade head
```

#### 5. 백그라운드 작업 큐 시작

`onyx/backend`에서:

```bash
python ./scripts/dev_run_background_jobs.py
```

#### 6. 백엔드 API 서버 시작

`onyx/backend`에서:

```bash
AUTH_TYPE=disabled uvicorn onyx.main:app --reload --port 8080
```

**Windows:**
```bash
powershell -Command "
    $env:AUTH_TYPE='disabled'
    uvicorn onyx.main:app --reload --port 8080
"
```

> **참고:** 더 자세한 로그가 필요하면 `LOG_LEVEL=DEBUG` 환경 변수를 추가하세요.

---

### 실행 완료 확인

4개의 서버가 실행 중이어야 합니다:

| 서버 | 포트 |
|------|------|
| 웹 서버 | 3000 |
| 백엔드 API | 8080 |
| 모델 서버 | 9000 |
| 백그라운드 작업 | - |

브라우저에서 `http://localhost:3000`을 열면 Onyx 온보딩 화면이 나타납니다. 여기서 외부 LLM 제공자를 연결할 수 있습니다.

---

## Docker로 전체 스택 실행

사전 빌드된 이미지로 전체 Onyx 스택을 실행하려면 `onyx/deployment/docker_compose`에서:

```bash
docker compose up -d
```

Docker가 컨테이너를 가져오고 시작한 후 `http://localhost:3000`에서 Onyx를 사용할 수 있습니다.

로컬 변경 사항을 포함하여 빌드하려면:

```bash
docker compose up -d --build
```
