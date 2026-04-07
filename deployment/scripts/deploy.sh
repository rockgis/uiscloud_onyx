#!/bin/bash
# =============================================================================
# UISCloud 배포 스크립트
#
# 사용법:
#   bash deploy.sh [OPTIONS]
#
# 옵션:
#   --airgap      폐쇄망 모드: 이미지 풀 생략, images/*.tar 자동 로드
#   --no-pull     이미지 풀 생략 (캐시된 이미지 사용)
#   --rollback    이전 이미지로 롤백 (PREVIOUS_WEB_IMAGE 환경변수 필요)
#   --dry-run     실제 배포 없이 실행 예상 내용 확인
#
# 폐쇄망 배포 흐름:
#   1. (인터넷 환경) save-images.sh 실행 → images/*.tar 생성
#   2. 패키지 전체를 폐쇄망 서버로 전송 후 임의 디렉터리에 압축 해제
#   3. load-images.sh 실행 → Docker에 이미지 로드
#   4. cp .env.example .env && 편집
#   5. bash deploy.sh --airgap
# =============================================================================
set -euo pipefail

# ── 경로 설정 ─────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 스탠드얼론 모드: compose 파일이 스크립트와 같은 디렉터리에 있을 때
# 레포지토리 모드: deployment/scripts/ 에서 실행될 때
if [ -f "$SCRIPT_DIR/docker-compose.prod.yml" ]; then
  COMPOSE_DIR="$SCRIPT_DIR"
else
  COMPOSE_DIR="$(cd "$SCRIPT_DIR/../docker_compose" && pwd)"
fi

# ── Compose 파일 구성 ─────────────────────────────────────────────────────────
COMPOSE_FILES="-f docker-compose.prod.yml -f docker-compose.uiscloud.yml"

# 폐쇄망 경로 오버라이드 파일이 있으면 자동 포함
if [ -f "$COMPOSE_DIR/docker-compose.airgap.yml" ]; then
  COMPOSE_FILES="$COMPOSE_FILES -f docker-compose.airgap.yml"
fi

# 릴리즈 포트/모드 오버라이드 파일이 있으면 자동 포함 (포트 8082, HTTP 전용)
if [ -f "$COMPOSE_DIR/docker-compose.release.yml" ]; then
  COMPOSE_FILES="$COMPOSE_FILES -f docker-compose.release.yml"
fi

# ── 색상 출력 ─────────────────────────────────────────────────────────────────
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

log()   { echo -e "${GREEN}[$(date '+%H:%M:%S')]${NC} $*"; }
info()  { echo -e "${BLUE}[$(date '+%H:%M:%S')]${NC} $*"; }
warn()  { echo -e "${YELLOW}[$(date '+%H:%M:%S')] WARN:${NC} $*"; }
error() { echo -e "${RED}[$(date '+%H:%M:%S')] ERROR:${NC} $*" >&2; }

# ── 옵션 파싱 ─────────────────────────────────────────────────────────────────
DRY_RUN=false
NO_PULL=false
ROLLBACK=false
AIRGAP=false

for arg in "$@"; do
  case $arg in
    --dry-run)  DRY_RUN=true ;;
    --no-pull)  NO_PULL=true ;;
    --rollback) ROLLBACK=true ;;
    --airgap)   AIRGAP=true; NO_PULL=true ;;
    *) error "알 수 없는 옵션: $arg"; exit 1 ;;
  esac
done

# images/ 디렉터리가 있으면 자동으로 폐쇄망 모드 활성화
if [ -d "$COMPOSE_DIR/images" ] && \
   [ "$(find "$COMPOSE_DIR/images" -name '*.tar' 2>/dev/null | wc -l)" -gt 0 ]; then
  if [ "$AIRGAP" = false ] && [ "$NO_PULL" = false ]; then
    warn "images/ 디렉터리가 감지되었습니다. 폐쇄망 모드로 전환합니다."
    AIRGAP=true
    NO_PULL=true
  fi
fi

# ── 실행 함수 (dry-run 지원) ──────────────────────────────────────────────────
run() {
  if [ "$DRY_RUN" = true ]; then
    info "[DRY-RUN] $*"
  else
    "$@"
  fi
}

# ── 전제 조건 확인 ────────────────────────────────────────────────────────────
check_prerequisites() {
  log "전제 조건 확인 중..."

  if ! command -v docker &>/dev/null; then
    error "Docker가 설치되어 있지 않습니다."
    exit 1
  fi

  if ! docker compose version &>/dev/null; then
    error "Docker Compose v2가 설치되어 있지 않습니다."
    exit 1
  fi

  if [ ! -f "$COMPOSE_DIR/.env" ]; then
    error ".env 파일이 없습니다. 먼저 다음을 실행하세요:"
    error "  cp .env.example .env"
    error "  nano .env"
    exit 1
  fi

  if [ ! -f "$COMPOSE_DIR/.env.nginx" ]; then
    warn ".env.nginx 파일이 없습니다. 기본값으로 생성합니다."
    if [ "$DRY_RUN" = false ]; then
      echo "DOMAIN=${DOMAIN:-localhost}" > "$COMPOSE_DIR/.env.nginx"
    fi
  fi

  log "✅ 전제 조건 확인 완료"
}

# ── 현재 실행 중인 이미지 저장 (롤백용) ──────────────────────────────────────
save_current_image() {
  local current_image
  current_image=$(docker compose $COMPOSE_FILES -p onyx ps --format json 2>/dev/null \
    | grep web_server \
    | python3 -c "import sys,json; data=json.load(sys.stdin); print(data.get('Image',''))" 2>/dev/null \
    || echo "")

  if [ -n "$current_image" ]; then
    export PREVIOUS_WEB_IMAGE="$current_image"
    log "현재 이미지 저장: $current_image"
  fi
}

# ── 이미지 로드 (폐쇄망) ──────────────────────────────────────────────────────
load_images() {
  local images_dir="$COMPOSE_DIR/images"
  log "폐쇄망 모드: images/ 에서 이미지 로드 중..."

  if [ ! -d "$images_dir" ] || \
     [ "$(find "$images_dir" -name '*.tar' | wc -l)" -eq 0 ]; then
    error "images/ 디렉터리가 없거나 .tar 파일이 없습니다."
    error "save-images.sh를 먼저 실행하여 이미지를 저장하세요."
    exit 1
  fi

  local load_script
  if [ -f "$SCRIPT_DIR/load-images.sh" ]; then
    load_script="$SCRIPT_DIR/load-images.sh"
  else
    load_script="$(cd "$COMPOSE_DIR/.." && pwd)/scripts/load-images.sh"
  fi

  if [ -f "$load_script" ]; then
    bash "$load_script"
  else
    # load-images.sh가 없으면 직접 로드
    while IFS= read -r -d '' tar_file; do
      log "로드: $(basename "$tar_file")"
      run docker load -i "$tar_file"
    done < <(find "$images_dir" -name "*.tar" -print0 | sort -z)
  fi

  log "✅ 이미지 로드 완료"
}

# ── 이미지 풀 ─────────────────────────────────────────────────────────────────
pull_images() {
  if [ "$AIRGAP" = true ]; then
    warn "폐쇄망 모드: 이미지 풀 생략"

    # 필요한 이미지가 로컬에 없으면 자동 로드
    local web_image
    web_image=$(grep '^UISCLOUD_WEB_IMAGE=' "$COMPOSE_DIR/.env" 2>/dev/null \
      | cut -d'=' -f2- | tr -d '"' || echo "")

    if [ -n "$web_image" ] && ! docker image inspect "$web_image" &>/dev/null; then
      warn "이미지가 로컬에 없습니다. images/ 에서 로드합니다..."
      load_images
    fi
    return
  fi

  if [ "$NO_PULL" = true ]; then
    warn "--no-pull 옵션: 이미지 풀 생략"
    return
  fi

  log "최신 이미지 풀 중..."
  run docker compose $COMPOSE_FILES pull --quiet
  log "✅ 이미지 풀 완료"
}

# ── 서비스 업데이트 ───────────────────────────────────────────────────────────
update_services() {
  log "서비스 업데이트 중..."
  run docker compose $COMPOSE_FILES up -d \
    --remove-orphans \
    --no-build \
    --wait \
    --wait-timeout 120
  log "✅ 서비스 업데이트 완료"
}

# ── 헬스 체크 ─────────────────────────────────────────────────────────────────
health_check() {
  if [ "$DRY_RUN" = true ]; then
    info "[DRY-RUN] 헬스 체크 생략"
    return
  fi

  log "헬스 체크 중 (최대 60초 대기)..."

  local retries=12
  local wait=5
  local attempt=0

  while [ $attempt -lt $retries ]; do
    attempt=$((attempt + 1))
    if curl -fsS "http://localhost/api/health" > /dev/null 2>&1; then
      log "✅ API 서버 정상"
      break
    fi
    if [ $attempt -lt $retries ]; then
      warn "API 아직 준비 중... (${attempt}/${retries}) ${wait}초 후 재시도"
      sleep $wait
    else
      error "❌ 헬스 체크 실패 (${retries}회 시도)"
      error "로그 확인:"
      docker compose $COMPOSE_FILES logs --tail=30 api_server web_server nginx
      return 1
    fi
  done

  if curl -fsS "http://localhost/" > /dev/null 2>&1; then
    log "✅ 웹 서버 정상"
  else
    warn "웹 서버 응답 없음. nginx 로그를 확인하세요."
  fi
}

# ── 배포 후 상태 출력 ─────────────────────────────────────────────────────────
print_status() {
  echo ""
  info "═══════════════════════════════════════"
  info " 배포 완료 상태"
  info "═══════════════════════════════════════"
  docker compose $COMPOSE_FILES ps --format "table {{.Name}}\t{{.Status}}"
  echo ""

  local web_image
  web_image=$(docker compose $COMPOSE_FILES images web_server 2>/dev/null \
    | tail -1 | awk '{print $1":"$2}' || echo "알 수 없음")
  info "🐳 웹 이미지: $web_image"
  info "🌐 접속 URL: http://$(hostname -f 2>/dev/null || echo 'localhost')"
  info "═══════════════════════════════════════"
}

# ── 롤백 ─────────────────────────────────────────────────────────────────────
rollback() {
  if [ -z "${PREVIOUS_WEB_IMAGE:-}" ]; then
    error "롤백할 이전 이미지 정보가 없습니다. PREVIOUS_WEB_IMAGE 환경변수를 설정하세요."
    exit 1
  fi

  warn "⚠️  롤백 실행: $PREVIOUS_WEB_IMAGE"
  run UISCLOUD_WEB_IMAGE="$PREVIOUS_WEB_IMAGE" \
    docker compose $COMPOSE_FILES up -d --no-build --wait web_server
  log "✅ 롤백 완료"
}

# ── 메인 실행 ─────────────────────────────────────────────────────────────────
main() {
  cd "$COMPOSE_DIR"

  echo ""
  log "🚀 UISCloud 배포 시작"
  [ "$DRY_RUN"  = true ] && warn "DRY-RUN 모드: 실제 배포 없음"
  [ "$ROLLBACK" = true ] && warn "ROLLBACK 모드"
  [ "$AIRGAP"   = true ] && info "폐쇄망(AIR-GAP) 모드"
  echo ""

  check_prerequisites

  if [ "$ROLLBACK" = true ]; then
    rollback
  else
    save_current_image
    pull_images
    update_services
    health_check
    print_status
  fi

  log "✅ 배포 완료!"
}

main
