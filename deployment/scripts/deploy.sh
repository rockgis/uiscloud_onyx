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
#   5. bash deploy.sh
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
RELEASE_MODE=false
if [ -f "$COMPOSE_DIR/docker-compose.release.yml" ]; then
  COMPOSE_FILES="$COMPOSE_FILES -f docker-compose.release.yml"
  RELEASE_MODE=true
fi

# ── 서비스 포트 결정 ──────────────────────────────────────────────────────────
# .env 의 SERVICE_PORT → 릴리즈 기본값 8082 → 표준 80 순서로 결정
detect_service_port() {
  local port=""
  if [ -f "$COMPOSE_DIR/.env" ]; then
    port=$(grep '^SERVICE_PORT=' "$COMPOSE_DIR/.env" 2>/dev/null \
      | cut -d'=' -f2- | tr -d '"' | tr -d "'" | tr -d ' ' || true)
  fi
  if [ -z "$port" ]; then
    if [ "$RELEASE_MODE" = true ]; then
      port="8082"
    else
      port="80"
    fi
  fi
  echo "$port"
}
SERVICE_PORT=$(detect_service_port)

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

# ── Docker Compose 버전 확인 ──────────────────────────────────────────────────
check_compose_version() {
  local version
  version=$(docker compose version --short 2>/dev/null || echo "0.0.0")
  # v2.26.0 미만이면 !reset 문법 미지원 경고
  local major minor
  major=$(echo "$version" | cut -d. -f1)
  minor=$(echo "$version" | cut -d. -f2)
  if [ "${major:-0}" -lt 2 ] || \
     { [ "${major:-0}" -eq 2 ] && [ "${minor:-0}" -lt 26 ]; }; then
    warn "Docker Compose v${version} 감지됨"
    warn "이 패키지는 v2.26.0 이상이 필요합니다 (!reset 문법 사용)"
    warn "업그레이드: sudo apt-get install -y docker-compose-plugin"
    warn "계속 진행하면 배포가 실패할 수 있습니다. 5초 후 계속..."
    sleep 5
  else
    log "Docker Compose v${version} ✅"
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

  check_compose_version

  if ! docker info &>/dev/null; then
    error "Docker 데몬이 실행 중이 아닙니다."
    error "  시작: sudo systemctl start docker"
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
      echo "DOMAIN=localhost" > "$COMPOSE_DIR/.env.nginx"
    fi
  fi

  log "✅ 전제 조건 확인 완료 (서비스 포트: ${SERVICE_PORT})"
}

# ── 현재 실행 중인 이미지 저장 (롤백용) ──────────────────────────────────────
save_current_image() {
  local current_image=""
  # docker compose ps JSON 포맷으로 현재 web_server 이미지 조회
  current_image=$(docker compose $COMPOSE_FILES ps --format json 2>/dev/null \
    | grep -o '"Image":"[^"]*"' \
    | grep "web.server\|web-server" \
    | head -1 \
    | cut -d'"' -f4 || true)

  if [ -n "$current_image" ]; then
    export PREVIOUS_WEB_IMAGE="$current_image"
    log "현재 이미지 저장: $current_image"
  fi
}

# ── 이미지 로드 (폐쇄망) ──────────────────────────────────────────────────────
load_images() {
  local images_dir="$COMPOSE_DIR/images"
  log "폐쇄망 모드: images/ 에서 이미지 로드 중..."

  if [ ! -d "$images_dir" ]; then
    error "images/ 디렉터리가 없습니다: $images_dir"
    exit 1
  fi

  local tar_count
  tar_count=$(find "$images_dir" -maxdepth 1 -name "*.tar" 2>/dev/null | wc -l | tr -d ' ')
  if [ "$tar_count" -eq 0 ]; then
    error "images/ 디렉터리에 .tar 파일이 없습니다."
    error "save-images.sh를 먼저 실행하여 이미지를 저장하세요."
    exit 1
  fi

  # load-images.sh 위치 탐색
  local load_script=""
  if [ -f "$COMPOSE_DIR/load-images.sh" ]; then
    load_script="$COMPOSE_DIR/load-images.sh"
  elif [ -f "$SCRIPT_DIR/load-images.sh" ]; then
    load_script="$SCRIPT_DIR/load-images.sh"
  fi

  if [ -n "$load_script" ]; then
    bash "$load_script"
  else
    # load-images.sh가 없으면 직접 로드
    local failed=0
    while IFS= read -r -d '' tar_file; do
      log "로드: $(basename "$tar_file")"
      if ! docker load -i "$tar_file"; then
        error "로드 실패: $(basename "$tar_file")"
        failed=$((failed + 1))
      fi
    done < <(find "$images_dir" -maxdepth 1 -name "*.tar" -print0 | sort -z)
    [ "$failed" -gt 0 ] && { error "이미지 로드 실패: ${failed}개"; exit 1; }
  fi

  log "✅ 이미지 로드 완료"
}

# ── 이미지 풀 ─────────────────────────────────────────────────────────────────
pull_images() {
  if [ "$AIRGAP" = true ]; then
    warn "폐쇄망 모드: 이미지 풀 생략"

    # 커스텀 이미지 3개 중 하나라도 없으면 images/ 에서 로드
    local web_image backend_image
    web_image=$(grep '^UISCLOUD_WEB_IMAGE=' "$COMPOSE_DIR/.env" 2>/dev/null \
      | cut -d'=' -f2- | tr -d '"' | tr -d "'" | tr -d ' ' || true)
    backend_image=$(grep '^UISCLOUD_BACKEND_IMAGE=' "$COMPOSE_DIR/.env" 2>/dev/null \
      | cut -d'=' -f2- | tr -d '"' | tr -d "'" | tr -d ' ' || true)

    local needs_load=false
    for img in "$web_image" "$backend_image"; do
      if [ -n "$img" ] && ! docker image inspect "$img" &>/dev/null 2>&1; then
        needs_load=true
        break
      fi
    done
    # 아무 이미지도 없으면 무조건 로드
    if [ -z "$web_image" ] && [ -z "$backend_image" ]; then
      needs_load=true
    fi

    if [ "$needs_load" = true ]; then
      warn "로컬에 이미지가 없습니다. images/ 에서 로드합니다..."
      load_images
    else
      log "로컬 이미지 확인 완료 (로드 생략)"
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

  # --wait 플래그: Docker Compose v2.1+ 필요
  local compose_version
  compose_version=$(docker compose version --short 2>/dev/null || echo "0.0.0")
  local major minor
  major=$(echo "$compose_version" | cut -d. -f1)
  minor=$(echo "$compose_version" | cut -d. -f2)

  if [ "${major:-0}" -ge 2 ] && [ "${minor:-0}" -ge 1 ]; then
    run docker compose $COMPOSE_FILES up -d \
      --remove-orphans \
      --no-build \
      --wait \
      --wait-timeout 180
  else
    warn "Docker Compose v${compose_version}: --wait 미지원, 일반 up 사용"
    run docker compose $COMPOSE_FILES up -d \
      --remove-orphans \
      --no-build
    log "서비스 시작 대기 중 (30초)..."
    sleep 30
  fi

  log "✅ 서비스 업데이트 완료"
}

# ── 헬스 체크 ─────────────────────────────────────────────────────────────────
health_check() {
  if [ "$DRY_RUN" = true ]; then
    info "[DRY-RUN] 헬스 체크 생략"
    return
  fi

  local health_url="http://localhost:${SERVICE_PORT}/api/health"
  local web_url="http://localhost:${SERVICE_PORT}/"

  log "헬스 체크 중 (포트: ${SERVICE_PORT}, 최대 90초 대기)..."

  local retries=18
  local wait=5
  local attempt=0

  while [ $attempt -lt $retries ]; do
    attempt=$((attempt + 1))
    if curl -fsS "$health_url" > /dev/null 2>&1; then
      log "✅ API 서버 정상"
      break
    fi
    if [ $attempt -lt $retries ]; then
      warn "API 아직 준비 중... (${attempt}/${retries}) ${wait}초 후 재시도"
      sleep $wait
    else
      error "❌ 헬스 체크 실패 (${retries}회 시도)"
      error "확인 URL: $health_url"
      error ""
      error "서비스 상태:"
      docker compose $COMPOSE_FILES ps 2>/dev/null || true
      error ""
      error "최근 로그 (api_server):"
      docker compose $COMPOSE_FILES logs --tail=20 api_server 2>/dev/null || true
      error ""
      error "최근 로그 (nginx):"
      docker compose $COMPOSE_FILES logs --tail=20 nginx 2>/dev/null || true
      return 1
    fi
  done

  if curl -fsS "$web_url" > /dev/null 2>&1; then
    log "✅ 웹 서버 정상"
  else
    warn "웹 서버 응답 없음 (${web_url}). nginx 로그를 확인하세요."
  fi
}

# ── 배포 후 상태 출력 ─────────────────────────────────────────────────────────
print_status() {
  echo ""
  info "═══════════════════════════════════════"
  info " 배포 완료 상태"
  info "═══════════════════════════════════════"
  docker compose $COMPOSE_FILES ps --format "table {{.Name}}\t{{.Status}}" 2>/dev/null || true
  echo ""

  local web_image
  web_image=$(docker compose $COMPOSE_FILES images web_server 2>/dev/null \
    | tail -1 | awk '{print $1":"$2}' || echo "알 수 없음")
  local host
  host=$(hostname -I 2>/dev/null | awk '{print $1}' || hostname -f 2>/dev/null || echo "localhost")
  info "🐳 웹 이미지: $web_image"
  info "🌐 접속 URL: http://${host}:${SERVICE_PORT}"
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
    docker compose $COMPOSE_FILES up -d --no-build web_server
  log "✅ 롤백 완료"
}

# ── 메인 실행 ─────────────────────────────────────────────────────────────────
main() {
  cd "$COMPOSE_DIR"

  echo ""
  log "🚀 UISCloud 배포 시작"
  [ "$DRY_RUN"      = true ] && warn "DRY-RUN 모드: 실제 배포 없음"
  [ "$ROLLBACK"     = true ] && warn "ROLLBACK 모드"
  [ "$AIRGAP"       = true ] && info "폐쇄망(AIR-GAP) 모드"
  [ "$RELEASE_MODE" = true ] && info "릴리즈 모드 (포트: ${SERVICE_PORT})"
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
