#!/bin/bash
# =============================================================================
# UISCloud 서버 초기 설정 스크립트
#
# GitHub Releases에서 배포 패키지를 다운로드하여 서버를 초기화합니다.
#
# 사용법:
#   # 최신 버전으로 설치
#   curl -fsSL https://raw.githubusercontent.com/rockgis/uiscloud_onyx/main/deployment/scripts/server-setup.sh | bash
#
#   # 옵션 지정
#   bash server-setup.sh [--version v1.0.0] [--dir /opt/uiscloud] [--domain example.com]
#
# 요구사항:
#   - Ubuntu 22.04 LTS 이상
#   - sudo 권한
# =============================================================================
set -euo pipefail

# ── 기본값 ────────────────────────────────────────────────────────────────────
REPO="rockgis/uiscloud_onyx"
RELEASES_URL="https://github.com/${REPO}/releases"
DEPLOY_DIR="/opt/uiscloud"
DOMAIN="localhost"
VERSION="latest"
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
    --version) VERSION="$2"; shift 2 ;;
    --dir)     DEPLOY_DIR="$2"; shift 2 ;;
    --domain)  DOMAIN="$2"; shift 2 ;;
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

# ── 필수 도구 설치 ────────────────────────────────────────────────────────────
install_deps() {
  step "필수 도구 확인"

  local packages=(curl tar jq)
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

# ── Docker 설치 ───────────────────────────────────────────────────────────────
install_docker() {
  step "Docker 설치"

  if command -v docker &>/dev/null; then
    log "Docker 이미 설치됨: $(docker --version)"
  else
    log "Docker 설치 중..."
    curl -fsSL https://get.docker.com | sudo sh
    sudo usermod -aG docker "$USER_NAME"
    warn "docker 그룹 적용을 위해 재로그인이 필요할 수 있습니다."
    log "✅ Docker 설치 완료"
  fi

  if ! docker compose version &>/dev/null; then
    log "Docker Compose v2 플러그인 설치 중..."
    sudo apt-get update -qq
    sudo apt-get install -y docker-compose-plugin
  fi

  log "✅ Docker Compose: $(docker compose version)"
}

# ── 배포 디렉터리 생성 ────────────────────────────────────────────────────────
setup_directory() {
  step "배포 디렉터리: $DEPLOY_DIR"

  sudo mkdir -p "$DEPLOY_DIR"
  sudo chown "$USER_NAME:$USER_NAME" "$DEPLOY_DIR"
  log "✅ 디렉터리 준비 완료"
}

# ── 릴리즈 패키지 다운로드 ────────────────────────────────────────────────────
download_release() {
  step "배포 패키지 다운로드"

  local download_url
  local asset_name

  if [ "$VERSION" = "latest" ]; then
    # 최신 버전 태그 조회
    VERSION=$(curl -fsSL "https://api.github.com/repos/${REPO}/releases/latest" \
      | grep '"tag_name"' | head -1 | sed 's/.*"tag_name": *"\([^"]*\)".*/\1/')
    log "최신 릴리즈 버전: $VERSION"
  fi

  asset_name="uiscloud-onyx.${VERSION}.tar.gz"
  download_url="${RELEASES_URL}/download/${VERSION}/${asset_name}"
  log "버전 ${VERSION} 다운로드 중..."

  info "URL: $download_url"

  local tmp_file
  tmp_file="$(mktemp /tmp/uiscloud-onyx-XXXXXX.tar.gz)"

  if ! curl -fsSL -o "$tmp_file" "$download_url"; then
    error "다운로드 실패: $download_url"
    error "릴리즈 목록: ${RELEASES_URL}"
    rm -f "$tmp_file"
    exit 1
  fi

  log "압축 해제 중: $DEPLOY_DIR"
  tar xzf "$tmp_file" -C "$DEPLOY_DIR" --strip-components=1
  rm -f "$tmp_file"

  chmod +x "$DEPLOY_DIR/deploy.sh" "$DEPLOY_DIR/server-setup.sh"

  log "✅ 패키지 다운로드 완료"
  info "설치된 파일:"
  ls -1 "$DEPLOY_DIR/"
}

# ── 환경 설정 파일 ────────────────────────────────────────────────────────────
setup_env() {
  step "환경 설정 파일"

  local env_file="$DEPLOY_DIR/.env"
  local example_file="$DEPLOY_DIR/.env.example"

  if [ ! -f "$env_file" ]; then
    cp "$example_file" "$env_file"

    # 도메인 자동 설정
    if [ "$DOMAIN" != "localhost" ]; then
      sed -i "s|# WEB_DOMAIN=https://yourdomain.com|WEB_DOMAIN=https://${DOMAIN}|g" "$env_file"
    fi

    log "✅ .env 파일 생성: $env_file"
    echo ""
    warn "══════════════════════════════════════════════════"
    warn "  ⚠️  .env 파일에서 다음 항목을 반드시 변경하세요"
    warn "══════════════════════════════════════════════════"
    warn ""
    warn "  ENCRYPTION_KEY_SECRET  →  openssl rand -hex 32"
    warn "  POSTGRES_PASSWORD      →  강력한 비밀번호"
    warn "  MINIO_ROOT_PASSWORD    →  강력한 비밀번호"
    warn "  S3_AWS_SECRET_ACCESS_KEY → MINIO_ROOT_PASSWORD와 동일"
    warn ""
    warn "  편집 명령: nano $env_file"
    warn "══════════════════════════════════════════════════"
    echo ""
  else
    warn ".env 파일 이미 존재: 덮어쓰지 않음"
  fi
}

# ── ghcr.io 인증 설정 ─────────────────────────────────────────────────────────
setup_registry_auth() {
  step "GitHub Container Registry 인증"

  info "이미지가 공개(public)이면 이 단계는 건너뛰어도 됩니다."
  echo ""
  read -r -p "ghcr.io 로그인이 필요합니까? [y/N]: " yn
  if [[ "$yn" =~ ^[Yy]$ ]]; then
    read -r -p "GitHub 사용자명: " gh_user
    read -r -s -p "GitHub Personal Access Token (read:packages 권한): " gh_token
    echo ""
    echo "$gh_token" | docker login ghcr.io -u "$gh_user" --password-stdin
    log "✅ ghcr.io 로그인 완료"
  else
    info "ghcr.io 인증 건너뜀"
  fi
}

# ── 방화벽 설정 ───────────────────────────────────────────────────────────────
setup_firewall() {
  step "방화벽 설정"

  if command -v ufw &>/dev/null; then
    sudo ufw allow 22/tcp comment "SSH" 2>/dev/null || true
    sudo ufw allow 80/tcp comment "HTTP" 2>/dev/null || true
    sudo ufw allow 443/tcp comment "HTTPS" 2>/dev/null || true
    sudo ufw --force enable 2>/dev/null || true
    log "✅ UFW 방화벽: 22, 80, 443 허용"
  else
    warn "UFW 없음 — 수동으로 포트 22, 80, 443을 열어두세요."
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
  echo "      nano $DEPLOY_DIR/.env"
  echo ""
  echo "  2️⃣  배포 실행:"
  echo "      bash $DEPLOY_DIR/deploy.sh"
  echo ""
  echo "  3️⃣  상태 확인:"
  echo "      cd $DEPLOY_DIR"
  echo "      docker compose -f docker-compose.prod.yml -f docker-compose.uiscloud.yml ps"
  echo ""
  echo "  🌐 접속 URL: http://$DOMAIN"
  echo ""
  echo "  📖 가이드: $DEPLOY_DIR/README.md"
  echo ""
}

# ── 메인 실행 ─────────────────────────────────────────────────────────────────
main() {
  echo ""
  log "🚀 UISCloud 서버 초기 설정 시작"
  info "설치 버전: $VERSION"
  info "설치 경로: $DEPLOY_DIR"
  info "도메인:    $DOMAIN"
  echo ""

  check_os
  install_deps
  install_docker
  setup_directory
  download_release
  setup_env
  setup_registry_auth
  setup_firewall
  print_next_steps
}

main
