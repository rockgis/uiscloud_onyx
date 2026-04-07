#!/bin/bash
# =============================================================================
# UISCloud 서버 초기 설정 스크립트 (폐쇄망 전용)
#
# 배포 패키지를 임의의 디렉터리에 압축 해제한 뒤,
# 해당 디렉터리에서 이 스크립트를 실행하면 초기 설정을 완료합니다.
# 인터넷 연결이 필요하지 않습니다.
#
# 사전 준비:
#   - Docker 및 Docker Compose v2 설치 (오프라인 설치 방법은 아래 참고)
#   - save-images.sh로 저장한 images/*.tar 파일 포함
#
# 사용법:
#   tar xzf uiscloud-onyx.tar.gz
#   cd uiscloud-onyx
#   bash server-setup.sh [--domain example.com]
#
# 옵션:
#   --domain <도메인>   nginx에 설정할 도메인 (기본값: localhost)
#   --skip-firewall     방화벽 설정 건너뜀
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 스탠드얼론 모드: compose 파일이 스크립트와 같은 디렉터리에 있을 때
# 레포지토리 모드: deployment/scripts/ 에서 실행될 때
if [ -f "$SCRIPT_DIR/docker-compose.prod.yml" ]; then
  DEPLOY_DIR="$SCRIPT_DIR"
else
  DEPLOY_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
fi

DOMAIN="localhost"
SKIP_FIREWALL=false

# ── 색상 출력 ─────────────────────────────────────────────────────────────────
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

log()   { echo -e "${GREEN}[SETUP]${NC} $*"; }
info()  { echo -e "${BLUE}[INFO]${NC}  $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }
step()  { echo -e "\n${BLUE}━━━ $* ━━━${NC}"; }

# ── 옵션 파싱 ─────────────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case $1 in
    --domain)         DOMAIN="$2"; shift 2 ;;
    --skip-firewall)  SKIP_FIREWALL=true; shift ;;
    *) error "알 수 없는 옵션: $1"; exit 1 ;;
  esac
done

# ── Docker 확인 ───────────────────────────────────────────────────────────────
check_docker() {
  step "Docker 확인"

  if ! command -v docker &>/dev/null; then
    error "Docker가 설치되어 있지 않습니다."
    error ""
    error "폐쇄망 Docker 설치 방법:"
    error "  Ubuntu/Debian:"
    error "    1. 인터넷 환경에서 Docker 패키지 다운로드:"
    error "         apt-get download docker-ce docker-ce-cli containerd.io docker-compose-plugin"
    error "    2. 폐쇄망 서버로 전송 후 설치:"
    error "         sudo dpkg -i *.deb"
    error "  또는 Docker 공식 오프라인 패키지 사용:"
    error "    https://download.docker.com/linux/ubuntu/dists/"
    exit 1
  fi

  log "Docker: $(docker --version)"

  if ! docker compose version &>/dev/null; then
    error "Docker Compose v2 플러그인이 설치되어 있지 않습니다."
    error "  설치: sudo apt-get install docker-compose-plugin"
    exit 1
  fi

  log "Docker Compose: $(docker compose version)"

  # v2.26.0 미만이면 !reset 문법 미지원 경고
  local dc_version
  dc_version=$(docker compose version --short 2>/dev/null || echo "0.0.0")
  local dc_major dc_minor
  dc_major=$(echo "$dc_version" | cut -d. -f1)
  dc_minor=$(echo "$dc_version" | cut -d. -f2)
  if [ "${dc_major:-0}" -lt 2 ] || \
     { [ "${dc_major:-0}" -eq 2 ] && [ "${dc_minor:-0}" -lt 26 ]; }; then
    warn "⚠️  Docker Compose v${dc_version} 감지됨"
    warn "이 패키지는 v2.26.0 이상이 필요합니다 (!reset 문법 사용)"
    warn "업그레이드:"
    warn "  sudo apt-get update && sudo apt-get install -y docker-compose-plugin"
    warn "계속 진행하면 배포가 실패할 수 있습니다."
  else
    log "Docker Compose v${dc_version} ✅"
  fi

  log "✅ Docker 확인 완료"
}

# ── Docker 데몬 실행 확인 ─────────────────────────────────────────────────────
check_docker_daemon() {
  step "Docker 데몬 확인"

  if ! docker info &>/dev/null; then
    error "Docker 데몬이 실행 중이 아닙니다."
    error "  시작: sudo systemctl start docker"
    error "  자동시작 등록: sudo systemctl enable docker"
    exit 1
  fi

  log "✅ Docker 데몬 실행 중"
}

# ── 패키지 파일 확인 ──────────────────────────────────────────────────────────
check_package() {
  step "배포 패키지 확인"

  local required_files=(
    "docker-compose.prod.yml"
    "docker-compose.uiscloud.yml"
    "docker-compose.airgap.yml"
    ".env.example"
  )

  local missing=()
  for f in "${required_files[@]}"; do
    if [ ! -f "$DEPLOY_DIR/$f" ]; then
      missing+=("$f")
    fi
  done

  if [ ${#missing[@]} -gt 0 ]; then
    error "다음 필수 파일이 없습니다:"
    for f in "${missing[@]}"; do
      error "  - $f"
    done
    exit 1
  fi

  if [ ! -d "$DEPLOY_DIR/images" ] || \
     [ "$(find "$DEPLOY_DIR/images" -name '*.tar' 2>/dev/null | wc -l)" -eq 0 ]; then
    warn "images/ 디렉터리가 없거나 .tar 파일이 없습니다."
    warn "나중에 load-images.sh를 실행하거나 --no-pull 없이 deploy.sh를 실행하세요."
  else
    local count
    count=$(find "$DEPLOY_DIR/images" -name '*.tar' | wc -l)
    log "이미지 파일: ${count}개"
  fi

  log "✅ 패키지 파일 확인 완료"
  info "배포 경로: $DEPLOY_DIR"
}

# ── Docker 이미지 로드 ────────────────────────────────────────────────────────
load_images() {
  step "Docker 이미지 로드"

  local images_dir="$DEPLOY_DIR/images"

  if [ ! -d "$images_dir" ] || \
     [ "$(find "$images_dir" -name '*.tar' 2>/dev/null | wc -l)" -eq 0 ]; then
    warn "images/ 디렉터리가 없습니다. 이미지 로드를 건너뜁니다."
    warn "배포 전에 반드시 load-images.sh를 실행하세요."
    return
  fi

  local load_script="$SCRIPT_DIR/load-images.sh"
  if [ ! -f "$load_script" ]; then
    load_script="$DEPLOY_DIR/load-images.sh"
  fi

  if [ -f "$load_script" ]; then
    bash "$load_script"
  else
    warn "load-images.sh를 찾을 수 없습니다. 수동으로 로드합니다..."
    while IFS= read -r -d '' tar_file; do
      log "로드: $(basename "$tar_file")"
      docker load -i "$tar_file"
    done < <(find "$images_dir" -name "*.tar" -print0 | sort -z)
  fi

  log "✅ 이미지 로드 완료"
}

# ── 환경 설정 파일 ────────────────────────────────────────────────────────────
setup_env() {
  step "환경 설정 파일"

  local env_file="$DEPLOY_DIR/.env"
  local example_file="$DEPLOY_DIR/.env.example"

  if [ ! -f "$example_file" ]; then
    error ".env.example 파일을 찾을 수 없습니다: $example_file"
    exit 1
  fi

  if [ ! -f "$env_file" ]; then
    cp "$example_file" "$env_file"

    # 도메인 자동 설정
    if [ "$DOMAIN" != "localhost" ]; then
      sed -i "s|# WEB_DOMAIN=https://yourdomain.com|WEB_DOMAIN=https://${DOMAIN}|g" "$env_file"
    fi

    log "✅ .env 파일 생성: $env_file"
  else
    warn ".env 파일이 이미 존재합니다. 덮어쓰지 않습니다: $env_file"
  fi

  # .env.nginx 파일 생성
  local nginx_env="$DEPLOY_DIR/.env.nginx"
  if [ ! -f "$nginx_env" ]; then
    echo "DOMAIN=${DOMAIN}" > "$nginx_env"
    log "✅ .env.nginx 파일 생성"
  fi

  echo ""
  warn "══════════════════════════════════════════════════════"
  warn "  ⚠️  .env 파일에서 다음 항목을 반드시 변경하세요"
  warn "══════════════════════════════════════════════════════"
  warn ""
  warn "  ENCRYPTION_KEY_SECRET  →  openssl rand -hex 32"
  warn "  POSTGRES_PASSWORD      →  강력한 비밀번호"
  warn "  MINIO_ROOT_PASSWORD    →  강력한 비밀번호"
  warn "  S3_AWS_SECRET_ACCESS_KEY → MINIO_ROOT_PASSWORD와 동일"
  warn ""
  warn "  편집: nano $env_file"
  warn "══════════════════════════════════════════════════════"
  echo ""
}

# ── 스크립트 실행 권한 설정 ───────────────────────────────────────────────────
setup_permissions() {
  step "실행 권한 설정"

  local scripts=(
    "$DEPLOY_DIR/deploy.sh"
    "$DEPLOY_DIR/load-images.sh"
    "$DEPLOY_DIR/save-images.sh"
    "$DEPLOY_DIR/server-setup.sh"
  )

  for s in "${scripts[@]}"; do
    [ -f "$s" ] && chmod +x "$s"
  done

  log "✅ 실행 권한 설정 완료"
}

# ── 방화벽 설정 ───────────────────────────────────────────────────────────────
setup_firewall() {
  if [ "$SKIP_FIREWALL" = true ]; then
    warn "방화벽 설정 건너뜀 (--skip-firewall)"
    return
  fi

  step "방화벽 설정"

  if command -v ufw &>/dev/null; then
    sudo ufw allow 22/tcp   comment "SSH"            2>/dev/null || true
    sudo ufw allow 80/tcp   comment "HTTP"           2>/dev/null || true
    sudo ufw allow 443/tcp  comment "HTTPS"          2>/dev/null || true
    sudo ufw allow 8082/tcp comment "UISCloud HTTP"  2>/dev/null || true
    sudo ufw --force enable 2>/dev/null || true
    log "✅ UFW 방화벽: 22, 80, 443, 8082 허용"
  else
    warn "UFW가 없습니다. 수동으로 포트 22, 80, 443, 8082를 열어주세요."
  fi
}

# ── 완료 메시지 ───────────────────────────────────────────────────────────────
print_next_steps() {
  echo ""
  echo -e "${GREEN}═══════════════════════════════════════════════════${NC}"
  echo -e "${GREEN} ✅ 서버 초기 설정 완료!${NC}"
  echo -e "${GREEN}═══════════════════════════════════════════════════${NC}"
  echo ""
  echo "📋 다음 단계:"
  echo ""
  echo "  1️⃣  환경 변수 설정 (필수):"
  echo "       nano $DEPLOY_DIR/.env"
  echo ""
  echo "  2️⃣  배포 실행:"
  echo "       bash $DEPLOY_DIR/deploy.sh"
  echo ""
  echo "  3️⃣  상태 확인:"
  echo "       cd $DEPLOY_DIR"
  echo "       docker compose -f docker-compose.prod.yml -f docker-compose.uiscloud.yml ps"
  echo ""
  local port
  port=$(grep '^SERVICE_PORT=' "$DEPLOY_DIR/.env" 2>/dev/null \
    | cut -d'=' -f2- | tr -d '"' | tr -d "'" | tr -d ' ' || true)
  port="${port:-8082}"
  if [ "$port" = "80" ]; then
    echo "  🌐 접속 URL: http://$DOMAIN"
  else
    echo "  🌐 접속 URL: http://$DOMAIN:$port"
  fi
  echo ""
}

# ── 메인 실행 ─────────────────────────────────────────────────────────────────
main() {
  echo ""
  log "🚀 UISCloud 서버 초기 설정 시작 (폐쇄망)"
  info "배포 경로: $DEPLOY_DIR"
  info "도메인:    $DOMAIN"
  echo ""

  check_docker
  check_docker_daemon
  check_package
  setup_permissions
  load_images
  setup_env
  setup_firewall
  print_next_steps
}

main
