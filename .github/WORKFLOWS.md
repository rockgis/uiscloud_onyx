# GitHub Actions 워크플로우 가이드

UISCloud Onyx에서 사용 중인 GitHub Actions 워크플로우 16개에 대한 설명 및 사용 방법입니다.

---

## 목차

1. [배포 워크플로우](#1-배포-워크플로우)
   - [uiscloud-build-deploy.yml](#uiscloud-build-deployyml)
2. [PR 테스트 워크플로우](#2-pr-테스트-워크플로우)
   - [pr-integration-tests.yml](#pr-integration-testsyml)
   - [pr-playwright-tests.yml](#pr-playwright-testsyml)
   - [pr-python-connector-tests.yml](#pr-python-connector-testsyml)
   - [pr-external-dependency-unit-tests.yml](#pr-external-dependency-unit-testsyml)
   - [pr-python-checks.yml](#pr-python-checksyml)
   - [pr-python-tests.yml](#pr-python-testsyml)
   - [pr-jest-tests.yml](#pr-jest-testsyml)
   - [pr-database-tests.yml](#pr-database-testsyml)
   - [pr-quality-checks.yml](#pr-quality-checksyml)
   - [pr-helm-chart-testing.yml](#pr-helm-chart-testingyml)
3. [스케줄 워크플로우](#3-스케줄-워크플로우)
   - [pr-python-model-tests.yml](#pr-python-model-testsyml)
   - [nightly-close-stale-issues.yml](#nightly-close-stale-issuesyml)
4. [유틸리티 워크플로우](#4-유틸리티-워크플로우)
   - [pr-labeler.yml](#pr-labeleryml)
   - [merge-group.yml](#merge-groupyml)
   - [zizmor.yml](#zizmoryml)

---

## 워크플로우 한눈에 보기

| 워크플로우 | 트리거 | 역할 |
|-----------|--------|------|
| `uiscloud-build-deploy` | main push, Release 발행, 수동 | 이미지 빌드 & 배포 패키지 생성 |
| `pr-integration-tests` | PR, merge_group, 태그 | 백엔드 통합 테스트 (병렬) |
| `pr-playwright-tests` | PR, merge_group, 태그 | E2E 브라우저 테스트 |
| `pr-python-connector-tests` | PR, merge_group, 태그, 매일 | 외부 커넥터 통합 테스트 |
| `pr-external-dependency-unit-tests` | PR, merge_group, 태그 | 외부 의존성 단위 테스트 |
| `pr-python-checks` | PR, merge_group, 태그 | MyPy 타입 검사 |
| `pr-python-tests` | PR, merge_group, 태그 | Python 단위 테스트 |
| `pr-jest-tests` | PR, merge_group, 태그 | 프론트엔드 단위 테스트 |
| `pr-database-tests` | PR, merge_group, 태그 | DB 마이그레이션 테스트 |
| `pr-quality-checks` | merge_group, main push, 태그 | pre-commit 코드 품질 검사 |
| `pr-helm-chart-testing` | PR, merge_group, 태그, 수동 | Helm 차트 lint & 설치 테스트 |
| `pr-python-model-tests` | 매일 16:00 UTC, 수동 | LLM/임베딩 모델 테스트 |
| `nightly-close-stale-issues` | 매일 11:00 UTC | 오래된 이슈/PR 자동 마감 |
| `pr-labeler` | PR 열림/수정 | PR 타이틀 Conventional Commits 검사 |
| `merge-group` | merge_group | 브랜치 보호 규칙 fast-pass |
| `zizmor` | main push, `.github/**` 변경 PR | GitHub Actions 보안 스캔 |

---

## 1. 배포 워크플로우

### uiscloud-build-deploy.yml

**UISCloud 전용** 이미지 빌드 및 배포 패키지 생성 워크플로우입니다.

#### 트리거

| 이벤트 | 조건 |
|--------|------|
| `push` | `main` 브랜치 |
| `release` | `published` (릴리즈 발행 시) |
| `workflow_dispatch` | 수동 실행 |

#### 실행 Job

**1. `build-web` — 웹 서버 이미지 빌드**

`web/Dockerfile`로 Next.js 이미지를 빌드하여 GHCR에 푸시합니다.

| 이벤트 | 생성되는 태그 |
|--------|-------------|
| main push | `:main`, `:sha-{7자리 커밋 해시}` |
| Release 발행 | `:v1.2.3`, `:1.2`, `:1`, `:latest` |

이미지 레지스트리:
```
ghcr.io/{github.repository}/web-server
```

**2. `package-deployment` — 배포 패키지 생성** _(Release 이벤트에만 실행)_

서버 배포에 필요한 파일들을 묶어 GitHub Release 에셋으로 업로드합니다.

패키지 파일명:
```
uiscloud-onyx.{VERSION}.tar.gz
```

패키지 내용:
```
uiscloud-onyx-{VERSION}/
├── docker-compose.prod.yml
├── docker-compose.uiscloud.yml
├── .env.example
├── deploy.sh
├── server-setup.sh
└── DEPLOY_GUIDE.md
```

#### 필요한 Secrets

| Secret | 용도 |
|--------|------|
| `GITHUB_TOKEN` | GHCR 이미지 푸시, Release 에셋 업로드 (자동 제공) |

#### 수동 실행 방법

GitHub → Actions → `UISCloud Build and Deploy` → `Run workflow` → 브랜치 선택 → `Run workflow`

#### 릴리즈 생성 → 배포 패키지 자동 생성 흐름

```
GitHub Release 발행
    → build-web (이미지 빌드 + 태그: v1.2.3, latest)
    → package-deployment (tar.gz 생성 + Release 에셋 업로드)
```

---

## 2. PR 테스트 워크플로우

PR 생성 시 자동으로 실행되어 코드 품질과 기능을 검증합니다.

### pr-integration-tests.yml

백엔드 통합 테스트를 병렬로 실행합니다. 실제 Onyx 서비스(PostgreSQL, Vespa, Redis, MinIO)를 모두 띄운 상태에서 테스트합니다.

#### 트리거

- PR → `main`, `release/**` 브랜치
- `merge_group`
- `v*.*.*` 태그 push

#### 실행 흐름

```
discover-test-dirs          # backend/tests/integration 하위 디렉토리 동적 탐색
    ↓
build-backend-image         ┐
build-model-server-image    ├ 이미지 병렬 빌드
build-integration-image     ┘
    ↓
integration-tests           # 각 디렉토리 × 에디션(EE/MIT) 병렬 실행
no-vectordb-tests           # Vespa 없는 모드 테스트
multitenant-tests           # 멀티테넌트 설정 테스트
    ↓
required                    # 최종 합격 판정
```

#### 에디션별 실행 정책

| 이벤트 | 실행 에디션 |
|--------|-----------|
| PR | EE만 실행 (속도 우선) |
| merge_group, 태그 | EE + MIT 둘 다 실행 |

#### 인프라 구성

- PostgreSQL, Redis, Vespa, MinIO를 Docker Compose로 자동 실행
- 테스트 재시도: 최대 3회
- 로그 아티팩트: 30일 보관

#### 필요한 Secrets

| Secret | 필요 이유 |
|--------|---------|
| `OPENAI_API_KEY` | LLM 연동 테스트 |
| `SLACK_BOT_TOKEN` | Slack 커넥터 테스트 |
| `CONFLUENCE_*` | Confluence 커넥터 테스트 |
| `JIRA_*` | Jira 커넥터 테스트 |
| `PERM_SYNC_SHAREPOINT_*` | SharePoint 권한 동기화 테스트 |

> 커넥터 테스트는 해당 Secret이 없으면 자동으로 스킵됩니다.

---

### pr-playwright-tests.yml

Playwright를 사용한 E2E 브라우저 테스트입니다. 프론트엔드와 백엔드 전체를 실행하여 사용자 시나리오를 검증합니다.

#### 트리거

- PR → `main`, `release/**` 브랜치
- `merge_group`
- `v*.*.*` 태그 push

#### 실행 흐름

```
build-web-image             ┐
build-backend-image         ├ arm64 이미지 병렬 빌드
build-model-server-image    ┘
    ↓
playwright-tests            # admin, exclusive-projects 테스트 그룹 병렬 실행
    ↓
visual-regression-comment   # 시각적 변경사항 PR 코멘트 게시
```

#### 시각적 회귀 테스트 (Visual Regression)

스크린샷 비교 결과를 S3에 업로드하고, PR에 자동으로 코멘트를 남깁니다.

```
S3 버킷 (PLAYWRIGHT_S3_BUCKET)
├── baseline/           # 기준 스크린샷
└── diff/{run_id}/      # 현재 실행 비교 결과
```

#### 필요한 Secrets

| Secret | 용도 |
|--------|------|
| `OPENAI_API_KEY` | 채팅/검색 기능 테스트 |
| `PLAYWRIGHT_S3_BUCKET` | 스크린샷 저장소 |
| `AWS_*` | S3 접근 |

---

### pr-python-connector-tests.yml

40개 이상의 외부 데이터 소스 커넥터를 실제 외부 서비스에 연결하여 테스트합니다.

#### 트리거

- PR → `main` 브랜치
- `merge_group`
- `v*.*.*` 태그 push
- **매일 16:00 UTC (01:00 KST)** 스케줄

#### 지원 커넥터 (테스트 대상)

| 카테고리 | 커넥터 |
|---------|--------|
| 클라우드 스토리지 | AWS S3, Cloudflare R2, Google Cloud Storage |
| 문서/위키 | Confluence, Notion, Slab, Gitbook |
| 프로젝트 관리 | Jira, Asana, Airtable, HubSpot, Salesforce |
| 소통 | Slack, Discord, Teams |
| 코드 관리 | GitHub, GitLab, Bitbucket |
| 이메일 | Gmail, IMAP |
| 기타 | Gong, Zendesk, Highspot, Fireflies, SharePoint |

#### 조건부 실행

변경된 파일 경로를 감지하여 관련 커넥터 테스트만 선택 실행합니다.

```yaml
# 예: HubSpot 관련 파일이 변경된 경우에만 HubSpot 테스트 실행
hubspot_changed: ${{ contains(steps.filter.outputs.*, 'hubspot') }}
```

#### 스케줄 실패 시 알림

매일 자동 실행 실패 시 Slack 알림 발송 (`SLACK_WEBHOOK` secret 필요).

---

### pr-external-dependency-unit-tests.yml

외부 의존성(PostgreSQL, Redis, Vespa, MinIO)을 실제로 실행하되, Onyx 애플리케이션은 직접 함수 호출로 테스트합니다.

#### 트리거

- PR → `main` 브랜치
- `merge_group`
- `v*.*.*` 태그 push

#### 실행 흐름

```
discover-test-dirs                      # 테스트 디렉토리 동적 탐색
    ↓
external-dependency-unit-tests          # DB 마이그레이션 후 테스트 실행
```

테스트 위치: `backend/tests/external_dependency_unit/`

#### 인프라 구성

- Docker Compose: Vespa, Redis, PostgreSQL, MinIO, OpenSearch
- 의존성 실행 후 Alembic 마이그레이션 자동 적용

#### 필요한 Secrets

| Secret | 용도 |
|--------|------|
| `CONFLUENCE_*` | Confluence 통합 테스트 |
| `OPENAI_API_KEY` | LLM 기능 테스트 |
| `ANTHROPIC_API_KEY` | Claude 모델 테스트 |

---

### pr-python-checks.yml

MyPy를 사용한 Python 정적 타입 검사입니다.

#### 트리거

- PR → `main`, `release/**` 브랜치
- `merge_group`
- `v*.*.*` 태그 push

#### 실행 내용

```bash
# OpenAPI 스키마 생성 후 타입 검사
python generate_openapi_schema.py
mypy backend/ tools/
```

#### 캐싱

MyPy 증분 캐시를 GitHub Actions 캐시에 저장합니다.

```
캐시 키: mypy-{python-version}-{파일 해시}
```

캐시 비활성화: 저장소 변수 `DISABLE_MYPY_CACHE=true` 설정

---

### pr-python-tests.yml

`backend/tests/unit/` 하위 Python 단위 테스트를 실행합니다. 외부 의존성 없이 순수 함수/클래스 로직을 검증합니다.

#### 트리거

- PR → `main`, `release/**` 브랜치
- `merge_group`
- `v*.*.*` 태그 push

#### 실행 명령

```bash
pytest -xv --ff backend/tests/unit
# -x: 첫 번째 실패 시 중단
# -v: 상세 출력
# --ff: 이전 실패 테스트 먼저 실행
```

---

### pr-jest-tests.yml

프론트엔드 Jest 단위 테스트를 실행합니다.

#### 트리거

- PR → `main`, `release/**` 브랜치
- `merge_group`
- `v*.*.*` 태그 push

#### 실행 내용

```bash
cd web
npm run test -- --coverage --maxWorkers=50%
```

#### 아티팩트

커버리지 리포트를 7일간 GitHub Actions에 보관합니다.

---

### pr-database-tests.yml

Alembic 마이그레이션의 정합성을 검증합니다. PostgreSQL만 실행하여 마이그레이션 적용/롤백이 정상 동작하는지 확인합니다.

#### 트리거

- PR → `main`, `release/**` 브랜치
- `merge_group`
- `v*.*.*` 태그 push

#### 실행 내용

```bash
# OpenAPI 스키마 생성 후 마이그레이션 테스트
pytest -m alembic tests/integration/tests/migrations/
```

#### 인프라

PostgreSQL만 Docker Compose로 실행 (Vespa, Redis 불필요).

---

### pr-quality-checks.yml

pre-commit 훅과 GitHub Actions 보안 검사를 실행합니다.

#### 트리거

> **주의**: `pull_request` 이벤트에서는 실행되지 않습니다.

- `merge_group`
- `push` → `main` 브랜치
- `v*.*.*` 태그 push

#### 실행 내용

1. **prek**: pre-commit 기반 코드 품질 검사 (black, ruff, prettier 등)
2. **check-actions**: GitHub Actions YAML 유효성 검사

#### 이벤트별 검사 범위

| 이벤트 | 범위 |
|--------|------|
| merge_group | `base_sha`~`head_sha` 변경 파일만 |
| main push | 전체 파일 (`--all-files`) |

---

### pr-helm-chart-testing.yml

Helm 차트의 lint 검사와 실제 Kind 클러스터에 설치 테스트를 수행합니다.

#### 트리거

- PR → `main` 브랜치
- `merge_group`
- `v*.*.*` 태그 push
- `workflow_dispatch` (수동 실행)

#### 실행 흐름

```
Kind 클러스터 생성
    → 의존 Helm 레포 등록 (ingress-nginx, Vespa, OpenSearch 등)
    → Redis Operator CRD 설치
    → 이미지 pre-pull (CloudNative-PG, Redis, web-server)
    → Helm 차트 lint
    → Helm 차트 설치 테스트 (25분 타임아웃)
    → Pod 상태 모니터링
```

#### 설치 시 비활성화 컴포넌트

| 컴포넌트 | 이유 |
|---------|------|
| nginx | Kind 환경에서 LoadBalancer 불필요 |
| MinIO | 테스트 환경에서 불필요 |
| Vespa | 무거운 리소스 절약 |

#### 수동 실행 방법

GitHub → Actions → `Helm Chart Testing` → `Run workflow`

---

## 3. 스케줄 워크플로우

### pr-python-model-tests.yml

LLM 및 임베딩 모델 연동을 매일 테스트합니다.

#### 트리거

- **매일 16:00 UTC (01:00 KST)** 스케줄
- `workflow_dispatch` (수동 실행)

#### 테스트 대상

| 모델 유형 | 테스트 파일 위치 |
|---------|--------------|
| LLM (OpenAI, Bedrock, Azure, Cohere) | `backend/tests/daily/llm/` |
| 임베딩 모델 | `backend/tests/daily/embedding/` |

#### 인프라

Docker Compose로 `inference_model_server` 실행 후 테스트 진행.

#### 실패 시 알림

Slack 채널에 실패 알림 발송 (`SLACK_WEBHOOK` secret 필요).

#### 수동 실행 방법

GitHub → Actions → `Python Model Tests` → `Run workflow`

---

### nightly-close-stale-issues.yml

오랫동안 활동이 없는 이슈와 PR을 자동으로 처리합니다.

#### 트리거

- **매일 11:00 UTC (20:00 KST)** 스케줄

#### 동작 규칙

| 상태 | 기준 | 메시지 |
|------|------|--------|
| stale 표시 | 75일 동안 활동 없음 | "This issue has been automatically marked as stale..." |
| 자동 마감 | stale 표시 후 15일 추가 (= 90일) | "Closing this issue..." |

#### 대상

- 이슈 (Issues)
- PR (Pull Requests)

---

## 4. 유틸리티 워크플로우

### pr-labeler.yml

PR 타이틀이 [Conventional Commits](https://www.conventionalcommits.org/) 형식을 따르는지 검사합니다.

#### 트리거

- PR → `main` 브랜치 (opened, reopened, synchronize, edited)

#### 허용되는 타이틀 형식

```
<type>(<scope>): <description>
```

| type | 용도 |
|------|------|
| `feat` | 새 기능 |
| `fix` | 버그 수정 |
| `docs` | 문서 변경 |
| `test` | 테스트 추가/수정 |
| `ci` | CI/CD 변경 |
| `refactor` | 리팩토링 |
| `perf` | 성능 개선 |
| `chore` | 기타 작업 |
| `revert` | 커밋 되돌리기 |
| `build` | 빌드 시스템 변경 |

**예시:**
```
feat: add Korean language support
fix(auth): handle null password error
docs(deploy): update server setup guide
ci: add uiscloud build workflow
```

---

### merge-group.yml

GitHub Merge Queue(merge_group) 이벤트에서 브랜치 보호 규칙을 통과시키기 위한 fast-pass stub입니다.

#### 트리거

- `merge_group` 이벤트

#### 동작

실제 테스트를 수행하지 않고, `required`와 `playwright-required` Job을 즉시 성공으로 처리합니다. 브랜치 보호 규칙에서 필수 상태 체크로 등록된 Job 이름과 일치시키기 위해 존재합니다.

---

### zizmor.yml

GitHub Actions 워크플로우 파일의 보안 취약점을 스캔합니다.

#### 트리거

- `push` → `main` 브랜치
- PR → `.github/**` 경로 변경 포함 시

#### 동작

```bash
zizmor --format=sarif .github/workflows/
```

SARIF 형식으로 결과를 생성하고 GitHub Security 탭에 업로드합니다.

결과 확인: GitHub → Security → Code scanning → zizmor

---

## 필요한 Repository Secrets 전체 목록

GitHub → Settings → Secrets and variables → Actions 에서 설정합니다.

### 필수 Secrets

| Secret | 사용 워크플로우 | 용도 |
|--------|---------------|------|
| `OPENAI_API_KEY` | integration-tests, playwright-tests, external-dep-tests | OpenAI API 호출 |

### 커넥터 테스트 Secrets (선택)

커넥터 테스트 Secret이 없으면 해당 커넥터 테스트는 자동 스킵됩니다.

| Secret | 커넥터 |
|--------|--------|
| `CONFLUENCE_*` | Confluence 위키 |
| `JIRA_*` | Jira 프로젝트 관리 |
| `SLACK_BOT_TOKEN` | Slack |
| `GITHUB_PERMISSION_SYNC_*` | GitHub 권한 동기화 |
| `PERM_SYNC_SHAREPOINT_*` | SharePoint |
| `GOOGLE_*` | Google Drive, Gmail |
| `NOTION_*` | Notion |

### 알림 Secrets (선택)

| Secret | 용도 |
|--------|------|
| `SLACK_WEBHOOK` | 스케줄 실패 시 알림 (model-tests, connector-tests) |

### 시각적 회귀 테스트 Secrets (선택)

| Secret | 용도 |
|--------|------|
| `PLAYWRIGHT_S3_BUCKET` | 스크린샷 저장 S3 버킷명 |
| `AWS_REGION` | S3 버킷 리전 |

---

## 로컬에서 테스트 실행하기

PR을 올리기 전에 로컬에서 테스트를 실행하는 방법입니다.

### Python 단위 테스트

```bash
source .venv/bin/activate
pytest -xv backend/tests/unit
```

### Python 타입 검사

```bash
source .venv/bin/activate
cd backend
mypy . --config-file pyproject.toml
```

### 프론트엔드 테스트

```bash
cd web
npm run test
```

### 통합 테스트 (Docker 필요)

```bash
source .venv/bin/activate
python -m dotenv -f .vscode/.env run -- pytest backend/tests/integration
```

### E2E 테스트 (Playwright)

```bash
cd web
npx playwright test
# i18n 테스트만 실행
npx playwright test --config=playwright.i18n.config.ts
```

### DB 마이그레이션 테스트

```bash
source .venv/bin/activate
cd backend
# PostgreSQL 실행 후
pytest -m alembic tests/integration/tests/migrations/
```

### pre-commit 품질 검사

```bash
pre-commit run --all-files
```

---

## 브랜치 보호 규칙과의 연관

main 브랜치 보호를 위해 다음 Job들이 필수 상태 체크로 등록되어 있습니다.

| 필수 체크 | 워크플로우 |
|---------|-----------|
| `required` | pr-integration-tests, merge-group |
| `playwright-required` | pr-playwright-tests, merge-group |
| `mypy-check` | pr-python-checks |
| `backend-check` | pr-python-tests |
| `jest-tests` | pr-jest-tests |
| `database-tests` | pr-database-tests |

Merge Queue 사용 시 `merge-group.yml`이 이 체크들을 즉시 통과시켜 빠른 병합을 가능하게 합니다.
