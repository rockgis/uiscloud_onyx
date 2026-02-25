# 백그라운드 작업 개요

백그라운드 작업은 다음을 담당합니다:

1. 문서 수집/인덱싱 (커넥터에서)
2. 문서 메타데이터 업데이트 (커넥터에서)
3. 인덱싱 체크포인트 및 인덱스 시도 메타데이터 정리
4. 사용자 업로드 파일 처리 및 삭제 (Projects 기능 및 채팅 업로드)
5. 모니터링을 위한 큐 길이 등 메트릭 보고

---

## 워커 → 큐 매핑

| 워커 | 파일 | 큐 |
|------|------|-----|
| **Primary** | `apps/primary.py` | `celery` |
| **Light** | `apps/light.py` | `vespa_metadata_sync`, `connector_deletion`, `doc_permissions_upsert`, `checkpoint_cleanup`, `index_attempt_cleanup` |
| **Heavy** | `apps/heavy.py` | `connector_pruning`, `connector_doc_permissions_sync`, `connector_external_group_sync`, `csv_generation`, `sandbox` |
| **Docprocessing** | `apps/docprocessing.py` | `docprocessing` |
| **Docfetching** | `apps/docfetching.py` | `connector_doc_fetching` |
| **User File Processing** | `apps/user_file_processing.py` | `user_file_processing`, `user_file_project_sync`, `user_file_delete` |
| **Monitoring** | `apps/monitoring.py` | `monitoring` |
| **Background (통합)** | `apps/background.py` | `celery`를 제외한 모든 큐 |

---

## 비워커 앱

| 앱 | 파일 | 용도 |
|----|------|------|
| **Beat** | `beat.py` | 테넌트별 주기적 작업 스케줄을 생성하는 `DynamicTenantScheduler`를 사용하는 Celery Beat 스케줄러 |
| **Client** | `client.py` | API 서버 등 비워커 프로세스에서 작업을 제출하기 위한 최소한의 앱 |

### 공유 모듈

`app_base.py`가 제공하는 것:
- `TenantAwareTask` — 테넌트 컨텍스트를 설정하는 기본 작업 클래스
- 로깅, 정리 및 라이프사이클 이벤트 시그널 핸들러
- 준비 프로브 및 헬스 체크

---

## 워커 상세 설명

### Primary (코디네이터 및 작업 디스패처)

기본 Celery 큐의 작업을 처리하는 단일 워커입니다. `PRIMARY_WORKER` Redis 잠금으로 싱글턴이 보장됩니다.

**시작 시:**
- Redis, PostgreSQL, 문서 인덱스가 모두 정상인지 대기
- 싱글턴 잠금 획득
- 백그라운드 작업과 관련된 모든 Redis 상태 정리
- 고아 인덱스 시도를 실패로 표시

**주기적 작업:**

| 작업 | 주기 | 설명 |
|------|------|------|
| `check_for_indexing` | 15초 | 인덱싱이 필요한 커넥터 스캔 → `DOCFETCHING` 큐로 디스패치 |
| `check_for_vespa_sync_task` | 20초 | 오래된 문서/문서 세트 발견 → `VESPA_METADATA_SYNC` 큐로 디스패치 |
| `check_for_pruning` | 20초 | 프루닝이 필요한 커넥터 발견 → `CONNECTOR_PRUNING` 큐로 디스패치 |
| `check_for_connector_deletion` | 20초 | 삭제 요청 처리 → `CONNECTOR_DELETION` 큐로 디스패치 |
| `check_for_user_file_processing` | 20초 | 사용자 업로드 확인 → `USER_FILE_PROCESSING` 큐로 디스패치 |
| `check_for_checkpoint_cleanup` | 1시간 | 오래된 인덱싱 체크포인트 정리 |
| `check_for_index_attempt_cleanup` | 30분 | 오래된 인덱스 시도 정리 |
| `kombu_message_cleanup_task` | 주기적 | DB에서 고아 Kombu 메시지 정리 |
| `celery_beat_heartbeat` | 1분 | Beat 워치독을 위한 하트비트 |

**워치독:**
supervisord가 관리하는 별도의 Python 프로세스로, Redis의 `ONYX_CELERY_BEAT_HEARTBEAT_KEY`를 확인하여 Celery Beat가 죽지 않았는지 확인합니다.

---

### Light (빠른 작업)

빠르고 단기적으로 실행되는 리소스 집약적이지 않은 작업입니다.

- **동시성**: 최대 24개 워커, 각각 8개 프리페치 → 최대 192개 작업 동시 실행
- **처리 작업**:
  - 접근/권한, 문서 세트, 부스트, 숨김 상태 동기화
  - PostgreSQL에서 삭제로 표시된 문서 삭제
  - 체크포인트 및 인덱스 시도 정리

---

### Heavy (리소스 집약적 작업)

오래 실행되는 리소스 집약적 작업으로, 프루닝과 샌드박스 작업을 처리합니다.

- **동시성**: 최대 4개, 1개 프리페치
- 문서 인덱스와는 직접 상호작용하지 않음 (외부 시스템과의 동기화 처리)
- 프루닝 및 권한 가져오기를 위한 대용량 API 호출
- PostgreSQL의 중요한 데이터와 함께 시간이 오래 걸릴 수 있는 CSV 내보내기 생성
- **샌드박스** (새 기능): Next.js, Python 가상 환경, OpenCode AI 에이전트 실행

---

### Docprocessing 및 Docfetching

문서 인덱싱을 위한 워커:

- **Docfetching**: 커넥터를 실행하여 외부 API(Google Drive, Confluence 등)에서 문서를 가져오고, 배치를 파일 저장소에 저장한 후 Docprocessing 작업을 디스패치
- **Docprocessing**: 배치를 가져와 인덱싱 파이프라인(청킹, 임베딩)을 실행하고 문서 인덱스에 인덱싱

**사용자 파일 처리**: 입력 바를 통해 직접 업로드된 파일 처리

---

### Monitoring (모니터링)

관찰성 및 메트릭 수집:
- 큐 길이, 커넥터 성공/실패, 커넥터 지연 시간
- supervisor로 관리되는 프로세스(워커, beat, slack)의 메모리
- 클라우드 및 멀티테넌트 특화 모니터링

---

## 배포 모드

### 경량 모드 (기본값)

```env
USE_LIGHTWEIGHT_BACKGROUND_WORKER=true
```

단일 `background` 워커가 모든 작업 처리:
- 더 낮은 리소스 사용
- 소규모 배포 또는 개발 환경에 적합
- 기본 동시성: 20 스레드

### 표준 모드

```env
USE_LIGHTWEIGHT_BACKGROUND_WORKER=false
```

전문화된 워커 분리:
- 더 나은 격리 및 확장성
- 워크로드에 따라 개별 워커 독립적 확장 가능
- 높은 부하의 프로덕션 배포에 적합

---

## 중요 사항

- **Celery 작업 수정 후 반드시 워커를 재시작**해야 변경 사항이 적용됩니다. 코드 변경 시 자동 재시작 메커니즘이 없습니다.
- 모든 워커는 스레드 풀(프로세스 아님)을 사용하므로, Celery의 시간 제한 기능이 조용히 비활성화됩니다. 타임아웃 로직은 작업 자체 내에서 구현해야 합니다.
- 작업을 정의할 때는 항상 `@shared_task`를 사용하고 `@celery_app`은 사용하지 마세요.
- 작업은 `background/celery/tasks/` 또는 `ee/background/celery/tasks` 아래에 배치하세요.
