# Onyx 파일 저장소

Onyx 파일 저장소는 S3 호환 저장 시스템에 파일과 대용량 이진 객체를 저장하기 위한 통합 인터페이스를 제공합니다. AWS S3, MinIO, Azure Blob Storage, Digital Ocean Spaces 및 기타 S3 호환 서비스를 지원합니다.

---

## 아키텍처

파일 저장소는 단일 데이터베이스 테이블(`file_record`)을 사용하여 파일 메타데이터를 저장하고, 실제 파일 내용은 외부 S3 호환 저장소에 저장합니다. 이 방식은 확장성, 비용 효율성을 제공하고 파일 저장소를 데이터베이스에서 분리합니다.

### 데이터베이스 스키마

`file_record` 테이블 컬럼:

| 컬럼 | 설명 |
|------|------|
| `file_id` (PK) | 파일 고유 식별자 |
| `display_name` | 사람이 읽을 수 있는 파일 이름 |
| `file_origin` | 파일 출처/소스 (enum) |
| `file_type` | 파일의 MIME 타입 |
| `file_metadata` | JSON 형식의 추가 메타데이터 |
| `bucket_name` | 외부 저장소 버킷/컨테이너 이름 |
| `object_key` | 외부 저장소 객체 키/경로 |
| `created_at` | 파일 생성 타임스탬프 |
| `updated_at` | 마지막 업데이트 타임스탬프 |

---

## 스토리지 백엔드 비교

### S3 호환 저장소

| 장점 | 단점 |
|------|------|
| 확장 가능한 저장소 | 추가 인프라 필요 |
| 대용량 파일에 비용 효율적 | 네트워크 의존성 |
| CDN 통합 가능 | 최종 일관성 고려 필요 |
| 데이터베이스와 분리 | |
| 광범위한 에코시스템 지원 | |

---

## 설정

모든 설정은 환경 변수로 처리됩니다.

### AWS S3

```bash
S3_FILE_STORE_BUCKET_NAME=your-bucket-name    # 기본값: 'onyx-file-store-bucket'
S3_FILE_STORE_PREFIX=onyx-files               # 선택, 기본값: 'onyx-files'

# AWS 자격증명 (다음 방법 중 하나 사용)
# 방법 1: 환경 변수
S3_AWS_ACCESS_KEY_ID=your-access-key
S3_AWS_SECRET_ACCESS_KEY=your-secret-key
AWS_REGION_NAME=us-east-2                     # 선택, 기본값: 'us-east-2'

# 방법 2: IAM 역할 (EC2/ECS 배포에 권장)
# IAM 역할을 사용하면 추가 설정 불필요
```

### MinIO

```bash
S3_FILE_STORE_BUCKET_NAME=your-bucket-name
S3_ENDPOINT_URL=http://localhost:9000          # MinIO 엔드포인트
S3_AWS_ACCESS_KEY_ID=minioadmin
S3_AWS_SECRET_ACCESS_KEY=minioadmin
AWS_REGION_NAME=us-east-1                      # 아무 리전 이름
S3_VERIFY_SSL=false                            # 선택, 기본값: false
```

### Digital Ocean Spaces

```bash
S3_FILE_STORE_BUCKET_NAME=your-space-name
S3_ENDPOINT_URL=https://nyc3.digitaloceanspaces.com
S3_AWS_ACCESS_KEY_ID=your-spaces-key
S3_AWS_SECRET_ACCESS_KEY=your-spaces-secret
AWS_REGION_NAME=nyc3
```

### 기타 S3 호환 서비스

다음만 설정하면 됩니다:
- `S3_FILE_STORE_BUCKET_NAME`: 버킷/컨테이너 이름
- `S3_ENDPOINT_URL`: 서비스 엔드포인트 URL
- `S3_AWS_ACCESS_KEY_ID` 및 `S3_AWS_SECRET_ACCESS_KEY`: 자격증명
- `AWS_REGION_NAME`: 리전 (유효한 리전 이름 아무거나)

---

## FileStore 인터페이스

`FileStore` 추상 기본 클래스가 정의하는 메서드:

| 메서드 | 설명 |
|--------|------|
| `initialize()` | 스토리지 백엔드 초기화 (필요시 버킷 생성) |
| `has_file(file_id, file_origin, file_type)` | 파일 존재 여부 확인 |
| `save_file(...)` | 파일 저장 |
| `read_file(file_id, mode, use_tempfile)` | 파일 내용 읽기 |
| `read_file_record(file_id)` | DB에서 파일 메타데이터 가져오기 |
| `delete_file(file_id)` | 파일 및 메타데이터 삭제 |
| `get_file_with_mime_type(file_id)` | MIME 타입과 함께 파일 가져오기 |

---

## 사용 예시

```python
from onyx.file_store.file_store import get_default_file_store
from onyx.configs.constants import FileOrigin

# 설정된 파일 저장소 가져오기
file_store = get_default_file_store(db_session)

# 스토리지 백엔드 초기화 (필요시 버킷 생성)
file_store.initialize()

# 파일 저장
with open("example.pdf", "rb") as f:
    file_id = file_store.save_file(
        content=f,
        display_name="중요 문서.pdf",
        file_origin=FileOrigin.OTHER,
        file_type="application/pdf",
        file_metadata={"department": "engineering", "version": "1.0"}
    )

# 파일 존재 확인
exists = file_store.has_file(
    file_id=file_id,
    file_origin=FileOrigin.OTHER,
    file_type="application/pdf"
)

# 파일 읽기
file_content = file_store.read_file(file_id)

# 대용량 파일을 위한 임시 파일로 읽기
file_content = file_store.read_file(file_id, use_tempfile=True)

# 파일 메타데이터 가져오기
file_record = file_store.read_file_record(file_id)

# MIME 타입 감지와 함께 파일 가져오기
file_with_mime = file_store.get_file_with_mime_type(file_id)

# 파일 삭제
file_store.delete_file(file_id)
```

---

## 배포 시 초기화 체크리스트

1. S3 호환 저장 서비스가 접근 가능한지 확인
2. 자격증명이 올바르게 설정되었는지 확인
3. `S3_FILE_STORE_BUCKET_NAME`에 지정된 버킷이 존재하거나 서비스 계정에 버킷 생성 권한이 있는지 확인
4. 앱 시작 시 `file_store.initialize()` 호출하여 버킷 존재 확인

파일 저장소는 자격증명에 충분한 권한이 있으면 버킷이 없을 경우 자동으로 생성합니다.
