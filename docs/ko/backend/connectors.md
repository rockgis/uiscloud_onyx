# 새로운 Onyx 커넥터 작성 가이드

이 문서는 Onyx의 새로운 커넥터를 기여하는 방법을 다룹니다. 디자인, 인터페이스, 필요한 변경 사항에 대한 개요를 포함합니다.

기여해 주셔서 감사합니다!

---

## 커넥터 개요

커넥터는 3가지 흐름으로 제공됩니다:

### Load Connector (전체 로드)
특정 시점을 반영하도록 문서를 대량 인덱싱합니다. 커넥터의 API를 통해 모든 문서를 가져오거나 덤프 파일에서 로드하여 작동합니다.

### Poll Connector (증분 업데이트)
제공된 시간 범위를 기반으로 문서를 증분 업데이트합니다. 백그라운드 작업이 마지막 폴링 이후의 최신 변경 사항을 가져오는 데 사용됩니다. 대용량 문서 세트에서 너무 느리게 수행될 모든 문서를 다시 가져오지 않고도 문서 인덱스를 최신 상태로 유지합니다.

### Slim Connector (프루닝용)
소스의 모든 문서를 확인하여 여전히 존재하는지 확인하는 경량 방법입니다. 문서 자체가 아닌 ID만 가져오며, 오래된 문서를 인덱스에서 제거하는 프루닝 작업에 사용됩니다.

### Event Based Connector (이벤트 기반)
이벤트를 수신하고 그에 따라 문서를 업데이트하는 커넥터입니다. 현재 백그라운드 작업에서는 사용되지 않으며 향후 설계를 위해 존재합니다.

---

## 커넥터 구현

### 기본 구조

커넥터는 `LoadConnector`, `PollConnector`, `CheckpointedConnector`, 또는 `CheckpointedConnectorWithPermSync` 중 하나 이상을 서브클래싱해야 합니다.

```python
class NewConnector(LoadConnector, PollConnector):
    def __init__(self, space: str = "engineering"):
        # 문서를 찾을 위치 및 가져올 문서를 구성하는 인수
        self.space = space

    def load_credentials(self, credentials: dict) -> None:
        # 접근 정보 로드 (사용자명, 액세스 토큰 등)
        self.api_key = credentials["api_key"]

    def load_from_state(self) -> GenerateDocumentsOutput:
        # 초기 전체 로드 구현
        ...

    def poll_source(
        self, start: SecondsSinceUnixEpoch, end: SecondsSinceUnixEpoch
    ) -> GenerateDocumentsOutput:
        # 증분 업데이트 구현
        ...
```

### 개발 팁

새 커넥터를 나머지 스택과 별도로 테스트할 때 유용한 템플릿:

```python
if __name__ == "__main__":
    import time
    test_connector = NewConnector(space="engineering")
    test_connector.load_credentials({
        "user_id": "foobar",
        "access_token": "fake_token"
    })
    all_docs = test_connector.load_from_state()

    current = time.time()
    one_day_ago = current - 24 * 60 * 60  # 1일
    latest_docs = test_connector.poll_source(one_day_ago, current)
```

> **참고:** 위 main을 실행하기 전에 PYTHONPATH를 `onyx/backend`로 설정하세요.

---

## 추가로 필요한 변경 사항

### 백엔드 변경

1. **`DocumentSource` enum에 새 타입 추가**
   - 파일: `backend/onyx/configs/constants.py`

2. **커넥터 팩토리에 매핑 추가**
   - 파일: `backend/onyx/connectors/factory.py`
   ```python
   SOURCE_TO_CONNECTOR_MAP = {
       DocumentSource.MY_SOURCE: MyConnector,
       ...
   }
   ```

### 프론트엔드 변경

1. **소스 메타데이터 맵에 커넥터 정의 추가**
   - 파일: `web/src/lib/sources.ts` (SOURCE_METADATA_MAP)

2. **커넥터 설정 폼 추가**
   - 파일: `web/src/lib/connectors/connectors.ts` (connectorConfigs 객체)

### 문서 변경

새 커넥터 페이지를 작성하고 Pull Request를 만드세요:
- 자격증명을 얻는 방법
- Onyx에서 커넥터를 설정하는 방법 (가이드 이미지 포함!)
- 저장소: [https://github.com/onyx-dot-app/documentation](https://github.com/onyx-dot-app/documentation)

---

## PR 오픈 전 체크리스트

1. **엔드투엔드 테스트**: 커넥터 설정부터 UI의 `커넥터 추가` 페이지에서 시작하여 성공적인 커넥터 생성을 보여주는 동영상을 첨부하세요.
2. **테스트 추가**: `backend/tests/daily/connectors` 디렉토리 아래에 폴더와 테스트를 추가하세요. PR 설명에 새 소스를 설정하여 테스트를 통과하는 방법에 대한 가이드를 포함하세요.
3. **린팅/포매팅 실행**: [기여 가이드의 포매팅 및 린팅 섹션](../CONTRIBUTING.md)을 참조하세요.

---

## 지원되는 커넥터 타입 참조

### 인터페이스 파일

```
backend/onyx/connectors/interfaces.py
```

### 커넥터 레지스트리

```
backend/onyx/connectors/registry.py   # 소스 → 커넥터 매핑
backend/onyx/connectors/factory.py    # 팩토리 패턴
```
