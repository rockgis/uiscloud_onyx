#!/bin/bash
# =============================================================================
# UISCloud 서비스 중지 스크립트
#
# 실행 중인 컨테이너를 중지합니다 (컨테이너/볼륨은 삭제하지 않음).
# 컨테이너와 네트워크까지 제거하려면 --down 옵션을 사용하세요.
# 데이터(볼륨)는 어떤 경우에도 삭제되지 않습니다.
#
# 사용법:
#   bash stop.sh [옵션] [서비스명...]
#
# 옵션:
#   --down    컨테이너 및 네트워크 제거 (docker compose down)
#             데이터 볼륨은 유지됩니다.
#
# 예시:
#   bash stop.sh               # 전체 서비스 중지 (컨테이너 유지)
#   bash stop.sh --down        # 컨테이너·네트워크 제거
#   bash stop.sh nginx         # nginx만 중지
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ -f "$SCRIPT_DIR/docker-compose.prod.yml" ]; then
  COMPOSE_DIR="$SCRIPT_DIR"
else
  COMPOSE_DIR="$(cd "$SCRIPT_DIR/../docker_compose" && pwd)"
fi

COMPOSE_FILES="-f docker-compose.prod.yml -f docker-compose.uiscloud.yml"
[ -f "$COMPOSE_DIR/docker-compose.airgap.yml" ]  && COMPOSE_FILES="$COMPOSE_FILES -f docker-compose.airgap.yml"
[ -f "$COMPOSE_DIR/docker-compose.release.yml" ] && COMPOSE_FILES="$COMPOSE_FILES -f docker-compose.release.yml"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; BLUE='\033[0;34m'; NC='\033[0m'
log()   { echo -e "${GREEN}[$(date '+%H:%M:%S')]${NC} $*"; }
info()  { echo -e "${BLUE}[$(date '+%H:%M:%S')]${NC} $*"; }
warn()  { echo -e "${YELLOW}[$(date '+%H:%M:%S')] WARN:${NC} $*"; }
error() { echo -e "${RED}[$(date '+%H:%M:%S')] ERROR:${NC} $*" >&2; }

# ── 옵션 파싱 ─────────────────────────────────────────────────────────────────
DOWN=false
SERVICES=()
for arg in "$@"; do
  case $arg in
    --down) DOWN=true ;;
    *)      SERVICES+=("$arg") ;;
  esac
done

cd "$COMPOSE_DIR"

echo ""
if [ "$DOWN" = true ]; then
  log "⏹  UISCloud 서비스 제거 (docker compose down)"
  warn "컨테이너와 네트워크가 제거됩니다. 데이터 볼륨은 유지됩니다."
else
  log "⏸  UISCloud 서비스 중지"
  [ ${#SERVICES[@]} -gt 0 ] && info "대상: ${SERVICES[*]}" || info "대상: 전체 서비스"
fi
echo ""

if ! docker info &>/dev/null; then
  error "Docker 데몬이 실행 중이 아닙니다."
  exit 1
fi

if [ "$DOWN" = true ]; then
  docker compose $COMPOSE_FILES down --remove-orphans
  echo ""
  log "✅ 서비스 제거 완료 (볼륨/데이터 유지)"
  info "재시작하려면: bash deploy.sh"
else
  docker compose $COMPOSE_FILES stop "${SERVICES[@]}"
  echo ""
  log "서비스 상태:"
  docker compose $COMPOSE_FILES ps --format "table {{.Name}}\t{{.Status}}" 2>/dev/null || true
  echo ""
  log "✅ 중지 완료"
  info "재시작하려면: bash start.sh"
fi
