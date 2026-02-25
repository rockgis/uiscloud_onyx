# Alembic DB 마이그레이션

이 파일들은 관계형 DB(PostgreSQL)의 테이블을 생성/업데이트하기 위한 것입니다. Onyx 마이그레이션은 비동기 dbapi를 사용하는 일반 단일 데이터베이스 설정을 사용합니다.

---

## 새 마이그레이션 생성

`onyx/backend`에서 실행:

```bash
alembic revision -m <마이그레이션_설명>
```

> **참고:** `--autogenerate` 플래그는 자동 스키마 파싱이 작동하지 않으므로 사용할 수 없습니다.
>
> 새 마이그레이션 파일에서 `upgrade`와 `downgrade`를 수동으로 작성하세요.

자세한 내용: https://alembic.sqlalchemy.org/en/latest/autogenerate.html

---

## 마이그레이션 실행

미적용된 모든 마이그레이션 실행:

```bash
alembic upgrade head
```

마이그레이션 되돌리기:

```bash
alembic downgrade -X
# X는 현재 상태에서 되돌릴 마이그레이션 수
```

---

## 멀티 테넌트 마이그레이션

### 모든 테넌트 업그레이드

```bash
alembic -x upgrade_all_tenants=true upgrade head
```

### 특정 스키마 업그레이드

```bash
# 단일 스키마
alembic -x schemas=tenant_12345678-1234-1234-1234-123456789012 upgrade head

# 여러 스키마 (쉼표로 구분)
alembic -x schemas=tenant_12345678-1234-1234-1234-123456789012,public,another_tenant upgrade head
```

### 알파벳 범위 내 테넌트 업그레이드

```bash
# 알파벳 순으로 정렬했을 때 100-200번째 테넌트 업그레이드
alembic -x upgrade_all_tenants=true -x tenant_range_start=100 -x tenant_range_end=200 upgrade head

# 알파벳 순으로 1000번째 이후 테넌트 업그레이드
alembic -x upgrade_all_tenants=true -x tenant_range_start=1000 upgrade head

# 처음 500개 테넌트 업그레이드
alembic -x upgrade_all_tenants=true -x tenant_range_end=500 upgrade head
```

### 오류 발생 시 계속 진행 (일괄 작업용)

```bash
alembic -x upgrade_all_tenants=true -x continue=true upgrade head
```

**테넌트 범위 필터링 작동 방식:**
1. 테넌트 ID를 알파벳 순으로 정렬
2. 1부터 시작하는 위치 번호 사용 (1번째, 2번째, 3번째 테넌트 등)
3. 지정된 위치 범위로 필터링
4. 'public' 같은 비테넌트 스키마는 항상 포함됨

---

## 엔터프라이즈 에디션 테넌트 마이그레이션

```bash
# 새 마이그레이션 생성
alembic -n schema_private revision -m "설명"

# 마이그레이션 적용
alembic -n schema_private upgrade head
```
