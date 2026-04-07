#!/bin/bash
# =============================================================================
# UISCloud 서비스 시작 스크립트
#
# 이미 배포된 컨테이너를 시작합니다 (이미지 풀/업데이트 없음).
# 신규 배포(이미지 업데이트)는 deploy.sh 를 사용하세요.
#
# 사용법:
#   bash start.sh [서비스명...]
#
# 예시:
#   bash start.sh              # 전체 서비스 시작
#   bash start.sh nginx        # nginx만 시작
#   bash start.sh api_server background
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ -f "$SCRIPT_DIR/docker-compose.prod.yml" ]; then
  COMPOSE_DIR="$SCRIPT_DIR"
else
  COMPOSE_DIR="$(cd "$SCRIPT_DIR/../docker_compose" && pwd)"
fi

COMPOSE_FILES="-f docker-compose.prod.yml -f docker-compose.uiscloud.yml"
[ -f "$COMPOSE_DIR/docker-compose.airgap.yml" ]   && COMPOSE_FILES="$COMPOSE_FILES -f docker-compose.airgap.yml"
RELEASE_MODE=false
[ -f "$COMPOSE_DIR/docker-compose.release.yml" ]  && { COMPOSE_FILES="$COMPOSE_FILES -f docker-compose.release.yml"; RELEASE_MODE=true; }

detect_service_port() {
  local port=""
  [ -f "$COMPOSE_DIR/.env" ] && \
    port=$(grep '^SERVICE_PORT=' "$COMPOSE_DIR/.env" 2>/dev/null \
      | cut -d'=' -f2- | tr -d '"' | tr -d "'" | tr -d ' ' || true)
  [ -z "$port" ] && { [ "$RELEASE_MODE" = true ] && port="8082" || port="80"; }
  echo "$port"
}
SERVICE_PORT=$(detect_service_port)

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; BLUE='\033[0;34m'; NC='\033[0m'
log()   { echo -e "${GREEN}[$(date '+%H:%M:%S')]${NC} $*"; }
info()  { echo -e "${BLUE}[$(date '+%H:%M:%S')]${NC} $*"; }
warn()  { echo -e "${YELLOW}[$(date '+%H:%M:%S')] WARN:${NC} $*"; }
error() { echo -e "${RED}[$(date '+%H:%M:%S')] ERROR:${NC} $*" >&2; }

cd "$COMPOSE_DIR"

echo ""
log "▶  UISCloud 서비스 시작"
[ $# -gt 0 ] && info "대상: $*" || info "대상: 전체 서비스"
echo ""

if ! docker info &>/dev/null; then
  error "Docker 데몬이 실행 중이 아닙니다."
  error "  sudo systemctl start docker"
  exit 1
fi

if [ ! -f "$COMPOSE_DIR/.env" ]; then
  error ".env 파일이 없습니다."
  error "  cp .env.example .env && nano .env"
  exit 1
fi

docker compose $COMPOSE_FILES start "$@"

echo ""
log "서비스 상태:"
docker compose $COMPOSE_FILES ps --format "table {{.Name}}\t{{.Status}}" 2>/dev/null || true

host=$(hostname -I 2>/dev/null | awk '{print $1}' || hostname -f 2>/dev/null || echo "localhost")
echo ""
info "🌐 접속 URL: http://${host}:${SERVICE_PORT}"
log "✅ 시작 완료"
