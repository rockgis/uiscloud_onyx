# 프롬프트 캐싱 프레임워크

여러 LLM 제공자에서 프로바이더 측 프롬프트 토큰 캐싱을 활용하여 비용을 절감하는 포괄적인 프롬프트 캐싱 메커니즘입니다.

---

## 개요

프롬프트 캐싱 프레임워크는 다양한 LLM 제공자에 걸쳐 프롬프트 캐싱을 활성화하는 통합 인터페이스를 제공합니다. **암묵적 캐싱** (자동 프로바이더 측 캐싱)과 **명시적 캐싱** (캐시 제어 파라미터 포함)을 모두 지원합니다.

---

## 기능

| 기능 | 설명 |
|------|------|
| **제공자 지원** | OpenAI (암묵적), Anthropic (명시적), Vertex AI (명시적) |
| **유연한 입력** | `str`과 `Sequence[ChatCompletionMessage]` 입력 모두 지원 |
| **연속 처리** | 캐시 가능한 접두사와 접미사 메시지의 스마트 병합 |
| **최선 노력** | 캐싱 실패 시 우아하게 비캐싱 동작으로 저하 |
| **테넌트 인식** | 다중 테넌트 배포를 위한 자동 테넌트 격리 |
| **설정 가능** | 환경 변수로 활성화/비활성화 |

---

## 빠른 시작

### 기본 사용법

```python
from onyx.llm.prompt_cache import process_with_prompt_cache
from onyx.llm.models import SystemMessage, UserMessage

# 캐시 가능한 접두사 (정적 컨텍스트) 정의
cacheable_prefix = [
    SystemMessage(role="system", content="당신은 도움이 되는 어시스턴트입니다."),
    UserMessage(role="user", content="컨텍스트: ...")  # 정적 컨텍스트
]

# 접미사 (동적 사용자 입력) 정의
suffix = [UserMessage(role="user", content="날씨가 어떤가요?")]

# 캐싱으로 처리
processed_prompt, cache_metadata = process_with_prompt_cache(
    llm_config=llm.config,
    cacheable_prefix=cacheable_prefix,
    suffix=suffix,
    continuation=False,
)

# 처리된 프롬프트로 LLM 호출
response = llm.invoke(processed_prompt)
```

### continuation 플래그

`continuation=True`이면 접미사가 캐시 가능한 접두사의 마지막 메시지에 추가됩니다:

```python
# continuation 없음 (기본값)
# 결과: [system_msg, prefix_user_msg, suffix_user_msg]

# continuation=True인 경우
# 결과: [system_msg, prefix_user_msg + suffix_user_msg]
processed_prompt, _ = process_with_prompt_cache(
    llm_config=llm.config,
    cacheable_prefix=cacheable_prefix,
    suffix=suffix,
    continuation=True,  # 접미사를 마지막 접두사 메시지에 병합
)
```

---

## 제공자별 동작

### OpenAI

| 항목 | 값 |
|------|-----|
| **캐싱 타입** | 암묵적 (자동) |
| **동작** | 특별한 파라미터 불필요. 1024 토큰 이상 접두사 자동 캐싱 |
| **캐시 수명** | 최대 1시간 |
| **비용 절감** | 캐시된 토큰 50% 할인 |

### Anthropic

| 항목 | 값 |
|------|-----|
| **캐싱 타입** | 명시적 (`cache_control` 파라미터 필요) |
| **동작** | 캐시 가능한 접두사의 **마지막 메시지**에 `cache_control={"type": "ephemeral"}` 자동 추가 |
| **캐시 수명** | 5분 (기본값) |
| **제한** | 최대 4개의 캐시 중단점 지원 |

### Vertex AI

| 항목 | 값 |
|------|-----|
| **캐싱 타입** | 명시적 (`cache_control` 파라미터 포함) |
| **동작** | 캐시 가능한 메시지의 **모든 콘텐츠 블록**에 `cache_control={"type": "ephemeral"}` 추가 |
| **캐시 수명** | 5분 |

---

## 아키텍처

### 핵심 컴포넌트

| 파일 | 설명 |
|------|------|
| `processor.py` | 메인 진입점 (`process_with_prompt_cache`) |
| `cache_manager.py` | 캐시 메타데이터 저장 및 검색 |
| `models.py` | 캐시 메타데이터 Pydantic 모델 (`CacheMetadata`) |
| `providers/` | 제공자별 어댑터 |
| `utils.py` | 공유 유틸리티 함수 |

### 제공자 어댑터

| 파일 | 클래스 | 설명 |
|------|--------|------|
| `base.py` | `PromptCacheProvider` | 모든 제공자를 위한 추상 기본 클래스 |
| `openai.py` | `OpenAIPromptCacheProvider` | 암묵적 캐싱 (변환 없음) |
| `anthropic.py` | `AnthropicPromptCacheProvider` | 마지막 메시지에 `cache_control`로 명시적 캐싱 |
| `vertex.py` | `VertexAIPromptCacheProvider` | 모든 콘텐츠 블록에 `cache_control`로 명시적 캐싱 |
| `noop.py` | `NoOpPromptCacheProvider` | 지원되지 않는 제공자의 폴백 |

각 어댑터가 구현하는 메서드:
- `supports_caching()`: 캐싱 지원 여부
- `prepare_messages_for_caching()`: 캐싱을 위한 메시지 변환
- `extract_cache_metadata()`: 응답에서 메타데이터 추출
- `get_cache_ttl_seconds()`: 캐시 TTL

---

## 설정

```bash
# 프롬프트 캐싱 활성화/비활성화 (기본값: true)
ENABLE_PROMPT_CACHING=false  # 비활성화
```

---

## Best Practices

1. **정적 콘텐츠를 캐시하세요**: 요청 간에 변경되지 않는 시스템 프롬프트, 정적 컨텍스트, 지침을 캐시 가능한 접두사로 사용하세요.

2. **동적 콘텐츠는 접미사에 유지하세요**: 사용자 쿼리, 검색 결과 등 동적 콘텐츠는 접미사에 두세요.

3. **캐시 효율성 모니터링**: 캐시 히트/미스에 대한 로그를 확인하고 캐싱 전략을 조정하세요.

4. **제공자 선택**: 제공자마다 캐싱 특성이 다릅니다. 사용 사례에 따라 선택하세요.

---

## 에러 처리

프레임워크는 **최선 노력** 방식으로 작동합니다. 캐싱이 실패하면 캐싱 없이 우아하게 폴백됩니다:

- 캐시 조회 실패: 로깅 후 캐싱 없이 계속
- 제공자 어댑터 실패: no-op 어댑터로 폴백
- 캐시 저장 실패: 로깅 후 계속 (캐싱은 최선 노력)
- 유효하지 않은 캐시 메타데이터: 삭제 후 캐시 없이 진행

---

## 테스트 예시

자세한 통합 테스트 예시는 다음을 참고하세요:
```
backend/tests/external_dependency_unit/llm/test_prompt_caching.py
```
