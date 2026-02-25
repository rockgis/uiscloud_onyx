# Onyx Prometheus 메트릭 레퍼런스

---

## 새 메트릭 추가 방법

모든 Prometheus 메트릭은 `backend/onyx/server/metrics/` 패키지에 있습니다.

### 1. 올바른 파일 선택 (또는 새 파일 생성)

| 파일 | 용도 |
|------|------|
| `metrics/slow_requests.py` | 느린 요청 카운터 + 콜백 |
| `metrics/postgres_connection_pool.py` | SQLAlchemy 연결 풀 메트릭 |
| `metrics/prometheus_setup.py` | FastAPI 인스트루멘테이터 설정 (오케스트레이터) |

독립적인 관심사(예: 캐시 히트율, 큐 깊이)가 있으면 `metrics/` 아래에 새 파일을 만들고 파일당 하나의 메트릭 개념을 유지하세요.

### 2. 메트릭 정의

모듈 레벨에서 `prometheus_client` 타입을 직접 사용하세요:

```python
# metrics/my_metric.py
from prometheus_client import Counter

_my_counter = Counter(
    "onyx_my_counter_total",          # 항상 onyx_ 접두사
    "사람이 읽을 수 있는 설명",
    ["label_a", "label_b"],           # 레이블 카디널리티를 낮게 유지
)
```

**명명 규칙:**
- 모든 메트릭 이름은 `onyx_` 접두사로 시작
- 카운터: `_total` 접미사 (예: `onyx_api_slow_requests_total`)
- 히스토그램: 기간/크기에 `_seconds` 또는 `_bytes` 접미사
- 게이지: 특별한 접미사 없음

**레이블 카디널리티:** 높은 카디널리티 레이블(원시 사용자 ID, UUID, 원시 경로)을 피하세요. `/api/items/abc-123` 대신 `/api/items/{item_id}` 같은 경로 템플릿을 사용하세요.

### 3. 인스트루멘테이터에 연결 (요청 범위인 경우)

```python
# metrics/my_metric.py
from prometheus_fastapi_instrumentator.metrics import Info

def my_metric_callback(info: Info) -> None:
    _my_counter.labels(label_a=info.method, label_b=info.modified_handler).inc()
```

```python
# metrics/prometheus_setup.py
from onyx.server.metrics.my_metric import my_metric_callback

# setup_prometheus_metrics() 내부에:
instrumentator.add(my_metric_callback)
```

### 4. setup_prometheus_metrics에 연결 (인프라 범위인 경우)

```python
# metrics/my_metric.py
def setup_my_metrics(resource: SomeResource) -> None:
    # 컬렉터 등록, 이벤트 리스너 연결 등
    ...
```

```python
# metrics/prometheus_setup.py 내부 setup_prometheus_metrics()에서:
from onyx.server.metrics.my_metric import setup_my_metrics

def setup_prometheus_metrics(app, engines=None) -> None:
    setup_my_metrics(resource)  # 호출 추가
    ...
```

모든 메트릭 초기화는 `onyx/main.py:lifespan()`의 단일 `setup_prometheus_metrics()` 호출을 통해 처리됩니다. `main.py`에 별도의 설정 호출을 추가하지 마세요.

### 5. 테스트 작성

`backend/tests/unit/onyx/server/`에 테스트를 추가하세요. `unittest.mock.patch`를 사용하여 prometheus 객체를 모킹하세요. 테스트에서 실제 전역 카운터를 증가시키지 마세요.

### 6. 메트릭 문서화

이 파일의 아래 참조 테이블에 메트릭을 추가하세요. 메트릭 이름, 타입, 레이블, 설명을 포함하세요.

### 7. Grafana 대시보드 업데이트

배포 후 관련 Grafana 대시보드에 패널을 추가하세요:

1. Grafana를 열고 Onyx 대시보드로 이동 (또는 새 대시보드 생성)
2. 새 패널 추가 — 적절한 시각화 선택:
   - **카운터** → 시계열 패널에서 `rate()` 사용 (예: `rate(onyx_my_counter_total[5m])`)
   - **히스토그램** → 백분위수에 `histogram_quantile()`, 평균에 `_sum/_count` 사용
   - **게이지** → stat 또는 gauge 패널로 직접 표시
3. 적절한 임계값과 알림 추가
4. 관련 패널을 행으로 그룹화 (예: "API 성능", "데이터베이스 풀")

---

## API 서버 메트릭

API 서버의 `GET /metrics`에서 노출됩니다.

### 내장 메트릭 (prometheus-fastapi-instrumentator)

| 메트릭 | 타입 | 레이블 | 설명 |
|--------|------|--------|------|
| `http_requests_total` | Counter | `method`, `status`, `handler` | 총 요청 수 |
| `http_request_duration_highr_seconds` | Histogram | (없음) | 고해상도 지연 시간 (많은 버킷, 레이블 없음) |
| `http_request_duration_seconds` | Histogram | `method`, `handler` | 핸들러별 지연 시간 (P95/P99용 커스텀 버킷) |
| `http_request_size_bytes` | Summary | `handler` | 수신 요청 콘텐츠 길이 |
| `http_response_size_bytes` | Summary | `handler` | 송신 응답 콘텐츠 길이 |
| `http_requests_inprogress` | Gauge | `method`, `handler` | 현재 진행 중인 요청 |

### 커스텀 메트릭 (onyx.server.metrics)

| 메트릭 | 타입 | 레이블 | 설명 |
|--------|------|--------|------|
| `onyx_api_slow_requests_total` | Counter | `method`, `handler`, `status` | `SLOW_REQUEST_THRESHOLD_SECONDS`(기본값 1s)를 초과하는 요청 |

### 설정

| 환경 변수 | 기본값 | 설명 |
|-----------|--------|------|
| `SLOW_REQUEST_THRESHOLD_SECONDS` | `1.0` | 느린 요청 카운팅을 위한 기간 임계값 |

---

## 데이터베이스 풀 메트릭

세 가지 엔진(`sync`, `async`, `readonly`)에 걸쳐 SQLAlchemy 연결 풀 상태를 확인합니다.

### 풀 상태 (스크랩마다 스냅샷)

| 메트릭 | 타입 | 레이블 | 설명 |
|--------|------|--------|------|
| `onyx_db_pool_checked_out` | Gauge | `engine` | 현재 체크아웃된 연결 |
| `onyx_db_pool_checked_in` | Gauge | `engine` | 풀에서 사용 가능한 유휴 연결 |
| `onyx_db_pool_overflow` | Gauge | `engine` | `pool_size`를 초과한 현재 오버플로 연결 |
| `onyx_db_pool_size` | Gauge | `engine` | 설정된 풀 크기 (상수) |

### 풀 라이프사이클

| 메트릭 | 타입 | 레이블 | 설명 |
|--------|------|--------|------|
| `onyx_db_pool_checkout_total` | Counter | `engine` | 풀에서 총 연결 체크아웃 |
| `onyx_db_pool_checkin_total` | Counter | `engine` | 풀로 총 연결 체크인 |
| `onyx_db_pool_connections_created_total` | Counter | `engine` | 총 새 데이터베이스 연결 생성 |
| `onyx_db_pool_invalidations_total` | Counter | `engine` | 총 연결 무효화 |
| `onyx_db_pool_checkout_timeout_total` | Counter | `engine` | 총 연결 체크아웃 타임아웃 |

### 엔드포인트별 연결 귀속

| 메트릭 | 타입 | 레이블 | 설명 |
|--------|------|--------|------|
| `onyx_db_connections_held_by_endpoint` | Gauge | `handler`, `engine` | 엔드포인트별 현재 보유 중인 DB 연결 |
| `onyx_db_connection_hold_seconds` | Histogram | `handler`, `engine` | 엔드포인트가 DB 연결을 보유하는 기간 |

엔진 레이블 값: `sync` (주 읽기-쓰기), `async` (비동기 세션), `readonly` (읽기 전용 사용자)

---

## 예시 PromQL 쿼리

### 현재 포화 상태인 엔드포인트는?

```promql
# 진행 중인 요청 기준 상위 10개 엔드포인트
topk(10, http_requests_inprogress)
```

### 엔드포인트별 P99 지연 시간은?

```promql
# 지난 5분간 핸들러별 P99 지연 시간
histogram_quantile(0.99, sum by (handler, le) (rate(http_request_duration_seconds_bucket[5m])))
```

### 어떤 엔드포인트의 요청률이 가장 높은가?

```promql
# 핸들러별 초당 요청 수, 상위 10개
topk(10, sum by (handler) (rate(http_requests_total[5m])))
```

### 어떤 엔드포인트가 오류를 반환하는가?

```promql
# 핸들러별 5xx 오류율
sum by (handler) (rate(http_requests_total{status=~"5.."}[5m]))
```

### 느린 요청 핫스팟

```promql
# 핸들러별 분당 느린 요청
sum by (handler) (rate(onyx_api_slow_requests_total[5m])) * 60
```

### 풀 활용도 (용량 대비 사용 중인 비율)

```promql
# Sync 풀 활용도: checked-out / (pool_size + max_overflow)
# 참고: 10을 실제 POSTGRES_API_SERVER_POOL_OVERFLOW 값으로 교체하세요
onyx_db_pool_checked_out{engine="sync"} / (onyx_db_pool_size{engine="sync"} + 10) * 100
```

### 어떤 엔드포인트가 DB 연결을 독점하는가?

```promql
# 현재 보유 중인 연결 기준 상위 10개 엔드포인트
topk(10, onyx_db_connections_held_by_endpoint{engine="sync"})
```

### 어떤 엔드포인트가 가장 오래 연결을 보유하는가?

```promql
# 엔드포인트별 연결 보유 시간 P99
histogram_quantile(0.99, sum by (handler, le) (rate(onyx_db_connection_hold_seconds_bucket{engine="sync"}[5m])))
```
