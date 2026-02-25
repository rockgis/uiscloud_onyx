# 통합 테스트 가이드

---

## 일반 테스트 개요

통합 테스트는 조작되는 각 유형의 객체(사용자, 에이전트, 자격증명 등)에 대해 "매니저" 클래스와 "테스트" 클래스로 설계됩니다:

- **매니저 클래스**: 각 유형의 API 호출 메서드를 포함합니다. 엔티티 생성, 삭제, 존재 확인을 담당합니다.
- **테스트 클래스**: 테스트 중인 각 엔티티의 데이터를 저장합니다. 객체의 "예상 상태"입니다.

각 테스트는 매니저 클래스를 사용하여 `test*` 객체를 생성(`.create()`)할 수 있습니다. 그런 다음 객체에 대한 작업(예: API에 요청 전송)을 수행하고, 매니저 클래스의 `.verify()` 함수를 사용하여 `test*` 객체가 예상 상태에 있는지 확인할 수 있습니다.

---

## 로컬에서 통합 테스트 실행 방법

### 0. 의존성 생성

먼저 openapi-generator를 설치합니다:

```bash
brew install openapi-generator
```

그런 다음 VSCode/Cursor 디버거에서 `Onyx OpenAPI Schema Generator` 작업을 실행합니다 (`launch.json` 설정은 [VSCode 설정 가이드](../contributing/contributing_vscode.md) 참조).
이 작업이 통합 테스트에 필요한 Python 클라이언트를 자동으로 생성합니다.

클라이언트 생성에 실패하면 수동으로 실행:

```bash
openapi-generator generate \
  -i backend/generated/openapi.json \
  -g python \
  -o backend/generated/onyx_openapi_client \
  --package-name onyx_openapi_client \
  --skip-validate-spec \
  --openapi-normalizer "SIMPLIFY_ONEOF_ANYOF=true,SET_OAS3_NULLABLE=true"
```

### 1. Onyx 실행

Docker 또는 디버거를 사용하여 Onyx를 실행하고, API 서버가 포트 8080에서 실행 중인지 확인합니다.

필수 설정:
- `AUTH_TYPE=basic`
- `ENABLE_PAID_ENTERPRISE_EDITION_FEATURES=true`

`mock_llm_response`를 사용하는 테스트는 API 서버 프로세스에 `INTEGRATION_TESTS_MODE=true`도 필요합니다.

환경 변수는 `onyx/backend/tests/integration/` 디렉토리에 `.env` 파일을 만들어 설정할 수 있습니다.

### 2. 테스트 실행

`onyx/backend`로 이동한 후:

```bash
# 모든 테스트 실행
python -m dotenv -f .env run -- pytest -s tests/integration/tests/

# 파일의 모든 테스트 실행
python -m dotenv -f .env run -- pytest -s tests/integration/tests/path_to/test_file.py

# 단일 테스트 실행
python -m dotenv -f .env run -- pytest -s tests/integration/tests/path_to/test_file.py::test_function_name
```

### mock_connector_server 컨테이너 실행

일부 테스트는 `mock_connector_server` 컨테이너가 필요합니다:

```bash
cd backend/tests/integration/mock_services
docker compose -f docker-compose.mock-it-services.yml -p mock-it-services-stack up -d
```

> 기본값 `onyx` 외의 이름으로 표준 Onyx 서비스를 시작했다면, docker-compose 파일의 networks 섹션을 `<스택이름>_default`로 수정해야 합니다.

---

## 통합 테스트 작성 가이드라인

- 모든 테스트에 인증이 필요하므로, 각 테스트는 사용자 생성으로 시작해야 합니다.
- 각 테스트는 단일 API 흐름에 집중해야 합니다.
- 실패 케이스와 엣지 케이스를 고려하여 이를 확인하는 테스트를 작성하세요.
- 테스트의 모든 단계는 수행하는 작업과 예상 동작을 설명하는 주석이 있어야 합니다.
- 테스트 함수 상단에 테스트 요약을 제공하세요.
- 새 테스트, 매니저 클래스, 매니저 함수, 테스트 클래스를 작성할 때 기존 스타일을 따르세요.
- 범위 증가(scope creep)에 주의하세요:
  - 다른 곳에서 이미 다루고 있는 케이스는 모든 API 호출 후 검증할 필요가 없습니다.
  - 예: 관리자 사용자 생성은 거의 모든 테스트에서 이루어지지만, 관리자 권한 확인은 해당 케이스에 집중된 테스트에서만 확인하면 됩니다.

---

## 현재 테스트 제한 사항

### 테스트 커버리지

- 일부 테스트는 충분한 커버리지를 갖지 않을 수 있습니다.
- 특히 "커넥터" 테스트는 커넥터/cc_pair 재작업 예정으로 매우 기본적인 상태입니다.
- 글로벌 큐레이터 역할이 충분히 테스트되지 않았습니다.
- 인증 없는 상태는 전혀 테스트되지 않았습니다.

### 실패 확인

- 예상된 인증 실패를 테스트하지만 실패 자체만 확인합니다.
- 반환 코드가 예상대로인지 확인하지 않습니다.
- 각 실패 케이스에 적절한 코드가 반환되는지 확인해야 합니다.
- 각 실패 후 DB 쿼리로 DB가 예상 상태인지 확인해야 합니다.

---

## 테스트 커버리지 TODO

- 에이전트 권한 테스트
- 읽기 전용(및/또는 기본) 사용자 권한 테스트
  - chat/doc_search 엔드포인트를 사용한 적절한 권한 적용 확인
- 인증 없는 상태 테스트

---

## 유용한 파일

| 파일 | 설명 |
|------|------|
| `backend/tests/integration/conftest.py` | 유용한 픽스처 |
| `backend/tests/integration/common_utils/` | 유틸리티 함수 |
| `backend/tests/integration/tests/` | 실제 테스트 파일 |
