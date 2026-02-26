#!/bin/bash
# =============================================================================
# UISCloud 서버 초기 설정 스크립트
#
# 새 서버에 처음 설치할 때 사용합니다.
#
# 사용법:
#   curl -fsSL https://raw.githubusercontent.com/rockgis/uiscloud_onyx/main/deployment/scripts/server-setup.sh | bash
#   또는
#   bash deployment/scripts/server-setup.sh [--domain example.com] [--dir /opt/uiscloud]
#
# 요구사항:
#   - Ubuntu 22.04 LTS 이상
#   - sudo 권한
# =============================================================================
set -euo pipefail

# ── 기본값 ────────────────────────────────────────────────────────────────────
REPO_URL="git@github.com:rockgis/uiscloud_onyx.git"
DEPLOY_DIR="/opt/uiscloud"
DOMAIN="localhost"
USER_NAME="${USER:-$(whoami)}"

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
    --domain) DOMAIN="$2"; shift 2 ;;
    --dir)    DEPLOY_DIR="$2"; shift 2 ;;
    --repo)   REPO_URL="$2"; shift 2 ;;
    *) error "알 수 없는 옵션: $1"; exit 1 ;;
  esac
done

# ── OS 확인 ───────────────────────────────────────────────────────────────────
check_os() {
  if [ "$(uname)" != "Linux" ]; then
    error "이 스크립트는 Linux에서만 실행됩니다."
    exit 1
  fi

  if ! command -v apt-get &>/dev/null; then
    error "Ubuntu/Debian 계열 Linux만 지원합니다."
    exit 1
  fi
}

# ── Docker 설치 ───────────────────────────────────────────────────────────────
install_docker() {
  step "Docker 설치"

  if command -v docker &>/dev/null; then
    log "Docker 이미 설치됨: $(docker --version)"
    return
  fi

  log "Docker 설치 중..."
  curl -fsSL https://get.docker.com | sudo sh

  # 현재 사용자를 docker 그룹에 추가
  sudo usermod -aG docker "$USER_NAME"

  log "✅ Docker 설치 완료"
  warn "docker 그룹 적용을 위해 재로그인이 필요할 수 있습니다."
}

# ── Docker Compose v2 설치 확인 ───────────────────────────────────────────────
check_compose() {
  step "Docker Compose 확인"

  if docker compose version &>/dev/null; then
    log "Docker Compose 이미 설치됨: $(docker compose version)"
    return
  fi

  log "Docker Compose v2 플러그인 설치 중..."
  sudo apt-get update -qq
  sudo apt-get install -y docker-compose-plugin
  log "✅ Docker Compose 설치 완료"
}

# ── 기타 필수 도구 ────────────────────────────────────────────────────────────
install_deps() {
  step "필수 도구 설치"

  local packages=(git curl jq)
  local missing=()

  for pkg in "${packages[@]}"; do
    if ! command -v "$pkg" &>/dev/null; then
      missing+=("$pkg")
    fi
  done

  if [ ${#missing[@]} -gt 0 ]; then
    log "누락된 패키지 설치: ${missing[*]}"
    sudo apt-get update -qq
    sudo apt-get install -y "${missing[@]}"
  fi

  log "✅ 필수 도구 확인 완료"
}

# ── 배포 디렉터리 생성 ────────────────────────────────────────────────────────
setup_directory() {
  step "배포 디렉터리 설정: $DEPLOY_DIR"

  if [ -d "$DEPLOY_DIR" ]; then
    warn "디렉터리 이미 존재: $DEPLOY_DIR"
    info "기존 디렉터리를 사용합니다. (git pull로 최신화)"
    return
  fi

  sudo mkdir -p "$DEPLOY_DIR"
  sudo chown "$USER_NAME:$USER_NAME" "$DEPLOY_DIR"
  log "✅ 배포 디렉터리 생성 완료"
}

# ── 저장소 클론 ───────────────────────────────────────────────────────────────
clone_or_update_repo() {
  step "저장소 설정"

  if [ -d "$DEPLOY_DIR/.git" ]; then
    log "저장소 업데이트 중..."
    cd "$DEPLOY_DIR"
    git pull origin main
    log "✅ 저장소 업데이트 완료"
    return
  fi

  log "저장소 클론 중: $REPO_URL"
  git clone "$REPO_URL" "$DEPLOY_DIR"
  log "✅ 저장소 클론 완료"
}

# ── 환경 설정 파일 ────────────────────────────────────────────────────────────
setup_env() {
  step "환경 설정 파일"

  local compose_dir="$DEPLOY_DIR/deployment/docker_compose"

  # .env 설정
  if [ ! -f "$compose_dir/.env" ]; then
    cp "$compose_dir/.env.uiscloud.example" "$compose_dir/.env"
    log "✅ .env 파일 생성: $compose_dir/.env"
    warn "⚠️  .env 파일을 반드시 편집하세요:"
    warn "    nano $compose_dir/.env"
    warn "    특히 다음 항목을 변경하세요:"
    warn "      - POSTGRES_PASSWORD (기본값 변경 필수)"
    warn "      - MINIO_ROOT_PASSWORD (기본값 변경 필수)"
    warn "      - ENCRYPTION_KEY_SECRET (보안 키 설정)"
  else
    warn ".env 파일 이미 존재: 덮어쓰지 않음"
  fi

  # .env.nginx 설정
  if [ ! -f "$compose_dir/.env.nginx" ]; then
    cat > "$compose_dir/.env.nginx" <<EOF
DOMAIN=${DOMAIN}
HOST_PORT=3000
HOST_PORT_80=80
EOF
    log "✅ .env.nginx 파일 생성 (도메인: $DOMAIN)"
  else
    warn ".env.nginx 파일 이미 존재: 덮어쓰지 않음"
  fi
}

# ── 스크립트 실행 권한 설정 ───────────────────────────────────────────────────
setup_permissions() {
  step "스크립트 권한 설정"
  chmod +x "$DEPLOY_DIR/deployment/scripts/"*.sh
  log "✅ 실행 권한 설정 완료"
}

# ── GitHub Container Registry 접근 설정 ──────────────────────────────────────
setup_registry_auth() {
  step "GitHub Container Registry 인증"

  info "ghcr.io에서 이미지를 Pull하기 위해 인증이 필요합니다."
  info "GitHub Personal Access Token (read:packages 권한)이 필요합니다."
  echo ""
  read -r -p "GitHub 사용자명을 입력하세요 (Enter로 건너뛰기): " gh_user
  if [ -n "$gh_user" ]; then
    read -r -s -p "GitHub Personal Access Token (read:packages): " gh_token
    echo ""
    if [ -n "$gh_token" ]; then
      echo "$gh_token" | docker login ghcr.io -u "$gh_user" --password-stdin
      log "✅ ghcr.io 로그인 완료"
    fi
  else
    warn "ghcr.io 인증 건너뜀. 이미지가 공개(public)이면 불필요합니다."
  fi
}

# ── SSL 초기화 (Let's Encrypt) ───────────────────────────────────────────────
setup_ssl() {
  if [ "$DOMAIN" = "localhost" ]; then
    warn "localhost로 설정됨: SSL 설정 건너뜀"
    return
  fi

  step "SSL 인증서 초기화 (Let's Encrypt)"

  local init_script="$DEPLOY_DIR/deployment/docker_compose/init-letsencrypt.sh"
  if [ -f "$init_script" ]; then
    info "SSL 초기화 스크립트 실행 여부:"
    read -r -p "  도메인 $DOMAIN 에 대해 Let's Encrypt 인증서를 발급받겠습니까? [y/N]: " yn
    if [[ "$yn" =~ ^[Yy]$ ]]; then
      cd "$DEPLOY_DIR/deployment/docker_compose"
      sudo bash init-letsencrypt.sh
      log "✅ SSL 인증서 초기화 완료"
    else
      warn "SSL 초기화 건너뜀. 나중에 수동으로 실행하세요:"
      warn "  cd $DEPLOY_DIR/deployment/docker_compose && sudo bash init-letsencrypt.sh"
    fi
  fi
}

# ── 방화벽 설정 ───────────────────────────────────────────────────────────────
setup_firewall() {
  step "방화벽 설정"

  if command -v ufw &>/dev/null; then
    log "UFW 방화벽 규칙 추가..."
    sudo ufw allow 22/tcp comment "SSH"
    sudo ufw allow 80/tcp comment "HTTP"
    sudo ufw allow 443/tcp comment "HTTPS"
    sudo ufw --force enable
    log "✅ 방화벽 설정 완료 (22, 80, 443 허용)"
  else
    warn "UFW 없음: 방화벽 설정 건너뜀"
    warn "수동으로 포트 22(SSH), 80(HTTP), 443(HTTPS)를 열어두세요."
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
  echo "      nano $DEPLOY_DIR/deployment/docker_compose/.env"
  echo ""
  echo "  2️⃣  첫 배포 실행:"
  echo "      cd $DEPLOY_DIR"
  echo "      bash deployment/scripts/deploy.sh"
  echo ""
  echo "  3️⃣  서비스 상태 확인:"
  echo "      cd $DEPLOY_DIR/deployment/docker_compose"
  echo "      docker compose -f docker-compose.prod.yml -f docker-compose.uiscloud.yml ps"
  echo ""
  echo "  4️⃣  로그 확인:"
  echo "      cd $DEPLOY_DIR/deployment/docker_compose"
  echo "      docker compose -f docker-compose.prod.yml -f docker-compose.uiscloud.yml logs -f"
  echo ""
  echo "  🌐 접속 URL: http://$DOMAIN"
  echo ""
}

# ── 메인 실행 ─────────────────────────────────────────────────────────────────
main() {
  echo ""
  log "🚀 UISCloud 서버 초기 설정 시작"
  info "배포 디렉터리: $DEPLOY_DIR"
  info "도메인: $DOMAIN"
  echo ""

  check_os
  install_deps
  install_docker
  check_compose
  setup_directory
  clone_or_update_repo
  setup_env
  setup_permissions
  setup_registry_auth
  setup_ssl
  setup_firewall
  print_next_steps
}

main
