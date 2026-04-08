#!/bin/bash
# =============================================================================
# UISCloud 이미지 빌드 스크립트 (서버 로컬 빌드)
#
# 인터넷 연결된 서버에서 소스코드로 Docker 이미지를 직접 빌드합니다.
# 호스트 아키텍처(amd64/arm64)에 맞는 네이티브 이미지가 생성됩니다.
#
# 사용법:
#   ./build.sh                    # 전체 빌드
#   ./build.sh web_server         # 특정 서비스만 빌드
#   ./build.sh --no-cache         # 캐시 없이 빌드
#
# 빌드 후 배포:
#   ./deploy.sh
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 스탠드얼론 모드(패키지) vs 레포지토리 모드 자동 감지
if [ -f "$SCRIPT_DIR/docker-compose.prod.yml" ]; then
  COMPOSE_DIR="$SCRIPT_DIR"
else
  COMPOSE_DIR="$(cd "$SCRIPT_DIR/../docker_compose" && pwd)"
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

# ── Compose 파일 구성 ─────────────────────────────────────────────────────────
if [ ! -f "$COMPOSE_DIR/docker-compose.build-local.yml" ]; then
  error "docker-compose.build-local.yml 파일이 없습니다."
  error "빌드 패키지가 올바르게 구성되어 있는지 확인하세요."
  exit 1
fi

COMPOSE_FILES="-f docker-compose.prod.yml -f docker-compose.build-local.yml"

# arm64 서버: arm64.yml 자동 포함 (서드파티 이미지 native arm64)
ARCH=$(uname -m)
if [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ]; then
  if [ -f "$COMPOSE_DIR/docker-compose.arm64.yml" ]; then
    COMPOSE_FILES="$COMPOSE_FILES -f docker-compose.arm64.yml"
    info "ARM64 서버 감지: 서드파티 이미지는 native arm64 사용"
  fi
fi

# ── 소스코드 확인 ─────────────────────────────────────────────────────────────
check_sources() {
  local missing=()
  [ ! -d "$COMPOSE_DIR/backend" ] && missing+=("backend/")
  [ ! -d "$COMPOSE_DIR/web" ]     && missing+=("web/")

  if [ "${#missing[@]}" -gt 0 ]; then
    error "소스코드 디렉터리가 없습니다: ${missing[*]}"
    error "빌드 패키지에 소스코드가 포함되어 있는지 확인하세요."
    exit 1
  fi
}

# ── 메인 ──────────────────────────────────────────────────────────────────────
main() {
  echo ""
  log "🔨 UISCloud 이미지 빌드 시작"
  info "아키텍처: $ARCH"
  info "빌드 경로: $COMPOSE_DIR"
  echo ""

  check_sources

  cd "$COMPOSE_DIR"

  log "Docker 이미지 빌드 중..."
  info "  • uiscloud/web-server:local"
  info "  • uiscloud/onyx-backend:local"
  info "  • uiscloud/onyx-model-server:local (BGE-M3 포함, 수 분 소요)"
  echo ""

  # 빌드 실행 (추가 인자 전달 가능: 서비스명, --no-cache 등)
  docker compose $COMPOSE_FILES build "$@"

  echo ""
  log "═══════════════════════════════════════════════════"
  log " ✅ 이미지 빌드 완료"
  log "═══════════════════════════════════════════════════"
  echo ""
  info "빌드된 이미지:"
  docker images --filter "reference=uiscloud/*" --format "  {{.Repository}}:{{.Tag}}\t{{.Size}}"
  echo ""
  info "다음 단계:"
  info "  cp .env.example .env && nano .env"
  info "  ./deploy.sh"
  echo ""
}

main "$@"
