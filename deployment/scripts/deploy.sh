#!/bin/bash
# =============================================================================
# UISCloud 배포 스크립트
#
# 사용법:
#   bash deployment/scripts/deploy.sh [OPTIONS]
#
# 옵션:
#   --rollback    이전 이미지로 롤백 (PREVIOUS_WEB_IMAGE 환경변수 필요)
#   --dry-run     실제 배포 없이 실행 예상 내용 확인
#   --no-pull     이미지 풀 생략 (캐시된 이미지 사용)
# =============================================================================
set -euo pipefail

# ── 경로 설정 ─────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE_DIR="$(cd "$SCRIPT_DIR/../docker_compose" && pwd)"
COMPOSE_FILES="-f docker-compose.prod.yml -f docker-compose.uiscloud.yml"

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

for arg in "$@"; do
  case $arg in
    --dry-run)   DRY_RUN=true ;;
    --no-pull)   NO_PULL=true ;;
    --rollback)  ROLLBACK=true ;;
    *) error "알 수 없는 옵션: $arg"; exit 1 ;;
  esac
done

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
    error "  cp deployment/docker_compose/.env.uiscloud.example deployment/docker_compose/.env"
    error "  nano deployment/docker_compose/.env"
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

# ── 이미지 풀 ─────────────────────────────────────────────────────────────────
pull_images() {
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

  # 웹 서버 응답 확인
  if curl -fsS "http://localhost/" > /dev/null 2>&1; then
    log "✅ 웹 서버 정상"
  else
    warn "웹 서버 응답 없음. nginx 로그 확인하세요."
  fi
}

# ── 배포 후 정보 출력 ─────────────────────────────────────────────────────────
print_status() {
  echo ""
  info "═══════════════════════════════════════"
  info " 배포 완료 상태"
  info "═══════════════════════════════════════"
  docker compose $COMPOSE_FILES ps --format "table {{.Name}}\t{{.Status}}"
  echo ""

  local web_image
  web_image=$(docker compose $COMPOSE_FILES images web_server 2>/dev/null | tail -1 | awk '{print $1":"$2}' || echo "알 수 없음")
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
  [ "$DRY_RUN" = true ] && warn "DRY-RUN 모드: 실제 배포 없음"
  [ "$ROLLBACK" = true ] && warn "ROLLBACK 모드"
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
