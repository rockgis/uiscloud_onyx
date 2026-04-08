#!/bin/bash
# =============================================================================
# UISCloud 릴리즈 패키지 생성 스크립트
#
# deployment/ 하위의 모든 배포 관련 파일을 모아 배포 패키지(tarball)를 생성합니다.
#
# 사용법:
#   ./package.sh [버전]                      # 패키지만 생성 (이미지 별도 추가)
#   ./package.sh v1.2.0                      # 버전 지정
#   ./package.sh --with-images main          # 이미지 저장 후 패키지 생성 (amd64)
#   ./package.sh --build-on-server           # 서버 직접 빌드 패키지 (소스코드 포함)
#   ./package.sh --build-on-server v1.2.0    # 버전 지정 + 서버 빌드 패키지
#
# 출력:
#   deployment/release/dist/uiscloud-onyx.{VERSION}.tar.gz          # 일반 패키지
#   deployment/release/dist/uiscloud-onyx.{VERSION}-build.tar.gz    # 빌드 패키지
# =============================================================================
set -euo pipefail

RELEASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEPLOY_DIR="$(cd "$RELEASE_DIR/.." && pwd)"
REPO_ROOT="$(cd "$DEPLOY_DIR/.." && pwd)"

# ── 버전 결정 ─────────────────────────────────────────────────────────────────
WITH_IMAGES=false
BUILD_ON_SERVER=false
IMAGE_TAG="main"

VERSION=""
while [[ $# -gt 0 ]]; do
  case $1 in
    --with-images)
      WITH_IMAGES=true
      IMAGE_TAG="${2:-main}"
      shift; [[ $# -gt 0 ]] && shift || true
      ;;
    --build-on-server)
      BUILD_ON_SERVER=true
      shift
      ;;
    -*)
      echo "알 수 없는 옵션: $1"; exit 1 ;;
    *)
      VERSION="$1"; shift ;;
  esac
done

if [ -z "$VERSION" ]; then
  VERSION="$(cd "$REPO_ROOT" && git describe --tags --abbrev=0 2>/dev/null || echo 'dev')"
fi

# 빌드 패키지는 별도 이름 사용
if [ "$BUILD_ON_SERVER" = true ]; then
  PKG_NAME="uiscloud-onyx.${VERSION}-build"
else
  PKG_NAME="uiscloud-onyx.${VERSION}"
fi
DIST_DIR="$RELEASE_DIR/dist"
PKG_DIR="$DIST_DIR/$PKG_NAME"

# ── 색상 출력 ─────────────────────────────────────────────────────────────────
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log()  { echo -e "${GREEN}[$(date '+%H:%M:%S')]${NC} $*"; }
info() { echo -e "${BLUE}[$(date '+%H:%M:%S')]${NC} $*"; }
warn() { echo -e "${YELLOW}[$(date '+%H:%M:%S')] WARN:${NC} $*"; }

# ── 디렉터리 구조 생성 ────────────────────────────────────────────────────────
prepare_dirs() {
  log "패키지 디렉터리 준비: $PKG_DIR"
  rm -rf "$PKG_DIR"
  mkdir -p "$PKG_DIR/data/nginx"
  if [ "$BUILD_ON_SERVER" = false ]; then
    mkdir -p "$PKG_DIR/images"
  fi
}

# ── Docker Compose 파일 복사 ──────────────────────────────────────────────────
copy_compose_files() {
  log "Docker Compose 파일 복사..."

  local src="$DEPLOY_DIR/docker_compose"
  cp "$src/docker-compose.prod.yml"   "$PKG_DIR/"
  cp "$src/docker-compose.airgap.yml" "$PKG_DIR/"
  cp "$src/docker-compose.arm64.yml"  "$PKG_DIR/"
  cp "$RELEASE_DIR/docker-compose.release.yml" "$PKG_DIR/"

  # 패키지 전용 교정 (레포 구조와 다른 부분 직접 수정)
  # 1) 볼륨 경로: ../data/ → ./data/
  perl -i -pe 's|\.\./data/|./data/|g' "$PKG_DIR/docker-compose.prod.yml"
  # 2) nginx 포트: 80:80 → SERVICE_PORT:80, 443:443 제거
  perl -i -pe 's|"80:80"|"\${SERVICE_PORT:-8082}:80"|' "$PKG_DIR/docker-compose.prod.yml"
  perl -i -ne 'print unless /^\s+- "443:443"/' "$PKG_DIR/docker-compose.prod.yml"
  # 3) build-on-server 모드: build: 섹션 완전 제거
  #    Docker Compose v5가 prod.yml의 build.context(../../backend 등)를 절대경로로
  #    먼저 해석한 뒤 override가 무시되는 문제를 원천 차단
  if [ "$BUILD_ON_SERVER" = true ]; then
    perl -i -0pe 's/\n    build:\n( {6,}[^\n]*\n)+//g' "$PKG_DIR/docker-compose.prod.yml"
    info "  ✅ docker-compose.prod.yml (경로·포트 교정 + build 섹션 제거)"
  else
    info "  ✅ docker-compose.prod.yml (경로·포트 교정)"
  fi

  if [ "$BUILD_ON_SERVER" = true ]; then
    # 서버 빌드 모드: build-local.yml 사용 (uiscloud.yml 불필요)
    cp "$src/docker-compose.build-local.yml" "$PKG_DIR/"
    info "  ✅ docker-compose.build-local.yml"
  else
    # 일반 모드: uiscloud.yml 사용 (pre-built 이미지)
    cp "$src/docker-compose.uiscloud.yml" "$PKG_DIR/"
    info "  ✅ docker-compose.uiscloud.yml"
  fi

  info "  ✅ docker-compose.airgap.yml"
  info "  ✅ docker-compose.arm64.yml"
  info "  ✅ docker-compose.release.yml"
}

# ── nginx 설정 파일 복사 ──────────────────────────────────────────────────────
copy_nginx_configs() {
  log "nginx 설정 파일 복사..."

  local src="$DEPLOY_DIR/data/nginx"
  local dst="$PKG_DIR/data/nginx"

  # HTTP 전용 템플릿 (릴리즈 기본)
  cp "$src/app.conf.template"             "$dst/"
  # SSL 템플릿 (참고용)
  cp "$src/app.conf.template.prod"        "$dst/"
  # 실행 스크립트 (실행 권한 명시)
  cp "$src/run-nginx.sh"                  "$dst/"
  chmod +x "$dst/run-nginx.sh"
  # MCP 설정 템플릿
  cp "$src/mcp_upstream.conf.inc.template" "$dst/"
  cp "$src/mcp.conf.inc.template"          "$dst/"

  info "  ✅ data/nginx/ ($(ls "$dst" | wc -l | tr -d ' ')개 파일)"
}

# ── 배포 스크립트 복사 ────────────────────────────────────────────────────────
copy_scripts() {
  log "배포 스크립트 복사..."

  local src="$DEPLOY_DIR/scripts"

  cp "$src/deploy.sh"       "$PKG_DIR/"
  cp "$src/server-setup.sh" "$PKG_DIR/"
  cp "$src/start.sh"        "$PKG_DIR/"
  cp "$src/stop.sh"         "$PKG_DIR/"

  if [ "$BUILD_ON_SERVER" = true ]; then
    cp "$src/build.sh" "$PKG_DIR/"
    info "  ✅ build.sh"
  else
    cp "$src/load-images.sh" "$PKG_DIR/"
    cp "$src/save-images.sh" "$PKG_DIR/"
    info "  ✅ load-images.sh"
    info "  ✅ save-images.sh"
  fi

  chmod +x "$PKG_DIR"/*.sh

  info "  ✅ deploy.sh"
  info "  ✅ server-setup.sh"
  info "  ✅ start.sh"
  info "  ✅ stop.sh"
}

# ── 소스코드 복사 (서버 빌드 모드 전용) ──────────────────────────────────────
copy_sources() {
  if [ "$BUILD_ON_SERVER" = false ]; then return; fi

  log "소스코드 복사 중 (서버 빌드용)..."

  # backend 복사 (빌드 불필요 파일 제외)
  rsync -a --quiet \
    --exclude='.venv/' \
    --exclude='__pycache__/' \
    --exclude='*.pyc' \
    --exclude='.pytest_cache/' \
    --exclude='log/' \
    --exclude='logs/' \
    --exclude='.mypy_cache/' \
    "$REPO_ROOT/backend/" "$PKG_DIR/backend/"

  # web 복사 (빌드 불필요 파일 제외)
  rsync -a --quiet \
    --exclude='node_modules/' \
    --exclude='.next/' \
    --exclude='out/' \
    --exclude='.turbo/' \
    "$REPO_ROOT/web/" "$PKG_DIR/web/"

  local backend_size web_size
  backend_size=$(du -sh "$PKG_DIR/backend" | cut -f1)
  web_size=$(du -sh "$PKG_DIR/web" | cut -f1)
  info "  ✅ backend/ (${backend_size})"
  info "  ✅ web/ (${web_size})"
}

# ── 환경변수 템플릿 복사 ──────────────────────────────────────────────────────
copy_env_template() {
  log "환경변수 템플릿 복사..."

  cp "$DEPLOY_DIR/docker_compose/.env.uiscloud.example" "$PKG_DIR/.env.example"

  # 이미지 태그 결정:
  #   --build-on-server → local (서버에서 직접 빌드)
  #   --with-images 사용 시 → 실제 저장된 이미지 태그(IMAGE_TAG) 사용
  #   릴리즈 버전만 지정 시 → 버전 태그(v1.x.x) 사용 (레지스트리에서 pull)
  #   그 외 → latest 유지
  local effective_tag
  if [ "$BUILD_ON_SERVER" = true ]; then
    effective_tag="local"
    # build-on-server 모드: uiscloud/ 네임스페이스의 로컬 이미지 사용
    perl -i -pe "s|ghcr.io/rockgis/uiscloud_onyx/web-server:[^\s]*|uiscloud/web-server:local|g" "$PKG_DIR/.env.example"
    perl -i -pe "s|ghcr.io/rockgis/uiscloud_onyx/onyx-backend:[^\s]*|uiscloud/onyx-backend:local|g" "$PKG_DIR/.env.example"
    perl -i -pe "s|ghcr.io/rockgis/uiscloud_onyx/onyx-model-server:[^\s]*|uiscloud/onyx-model-server:local|g" "$PKG_DIR/.env.example"
  else
    if [ "$WITH_IMAGES" = true ]; then
      effective_tag="$IMAGE_TAG"
    elif [[ "$VERSION" =~ ^v[0-9] ]]; then
      effective_tag="$VERSION"
    else
      effective_tag="latest"
    fi
    perl -i -pe "s|web-server:latest|web-server:${effective_tag}|g"              "$PKG_DIR/.env.example"
    perl -i -pe "s|onyx-backend:latest|onyx-backend:${effective_tag}|g"          "$PKG_DIR/.env.example"
    perl -i -pe "s|onyx-model-server:latest|onyx-model-server:${effective_tag}|g" "$PKG_DIR/.env.example"
  fi
  info "  ✅ .env.example (이미지 태그: ${effective_tag})"

  # images 디렉터리 placeholder (빌드 모드에서는 불필요)
  if [ "$BUILD_ON_SERVER" = false ]; then
    touch "$PKG_DIR/images/.gitkeep"
  fi
}

# ── 이미지 복사/저장 (선택) ───────────────────────────────────────────────────
save_images() {
  if [ "$WITH_IMAGES" = false ]; then
    warn "이미지 저장 생략 (--with-images 미지정)"
    warn "배포 전 다음 명령으로 이미지를 저장하세요:"
    warn "  cd $PKG_DIR && ./save-images.sh $IMAGE_TAG"
    return
  fi

  local src_images="$DEPLOY_DIR/images"
  local dst_images="$PKG_DIR/images"

  # 이미 저장된 이미지가 있으면 복사 (재다운로드 생략)
  local existing_count
  existing_count=$(find "$src_images" -maxdepth 1 -name "*.tar" 2>/dev/null | wc -l | tr -d ' ')

  if [ "$existing_count" -gt 0 ]; then
    log "이미 저장된 이미지 발견 (${existing_count}개) → 복사 중..."
    cp "$src_images"/*.tar "$dst_images/"
    log "✅ 이미지 복사 완료"
  else
    log "Docker 이미지 저장 중 (태그: $IMAGE_TAG)..."
    IMAGE_TAG="$IMAGE_TAG" bash "$PKG_DIR/save-images.sh" "$IMAGE_TAG"
    log "✅ 이미지 저장 완료"
  fi
}

# ── tarball 생성 ──────────────────────────────────────────────────────────────
create_tarball() {
  log "tarball 생성 중..."

  local tarball="${DIST_DIR}/${PKG_NAME}.tar.gz"

  cd "$DIST_DIR"
  if [ "$WITH_IMAGES" = true ]; then
    # images/*.tar 포함
    tar czf "${PKG_NAME}.tar.gz" "${PKG_NAME}/"
  else
    # images/*.tar 제외 (build-on-server 모드에서는 images/ 자체가 없음)
    tar czf "${PKG_NAME}.tar.gz" \
      --exclude="${PKG_NAME}/images/*.tar" \
      "${PKG_NAME}/"
  fi

  local size
  size=$(du -sh "$tarball" | cut -f1)
  info "  ✅ $tarball ($size)"
}

# ── 결과 출력 ─────────────────────────────────────────────────────────────────
print_summary() {
  echo ""
  log "═══════════════════════════════════════════════════"
  log " ✅ 패키지 생성 완료"
  log "═══════════════════════════════════════════════════"
  echo ""
  info "버전:    $VERSION"
  info "경로:    $DIST_DIR/${PKG_NAME}.tar.gz"
  info "포트:    8082 (HTTP)"
  [ "$BUILD_ON_SERVER" = true ] && info "유형:    서버 빌드 패키지 (소스코드 포함)"
  echo ""
  echo "📦 패키지 내용 (일부):"
  tar tzf "$DIST_DIR/${PKG_NAME}.tar.gz" \
    | grep -v "/$" \
    | grep -v "/backend/\|/web/" \
    | sed 's/^/  /'
  echo ""

  if [ "$BUILD_ON_SERVER" = true ]; then
    echo "━━━ 서버 빌드 & 배포 방법 ──────────────────────────────"
    echo ""
    echo "  # 서버에서"
    echo "  tar xzf ${PKG_NAME}.tar.gz && cd ${PKG_NAME}"
    echo "  bash server-setup.sh          # 초기 설정 (Docker 설치 등)"
    echo "  bash build.sh                 # 이미지 빌드 (인터넷 필요, 수 분 소요)"
    echo "  cp .env.example .env && nano .env  # 환경변수 편집"
    echo "  bash deploy.sh                # 배포 (http://서버IP:8082)"
    echo ""
  elif [ "$WITH_IMAGES" = false ]; then
    echo "━━━ 이미지 추가 방법 (폐쇄망 배포 시) ─────────────────"
    echo ""
    echo "  # 1. 패키지 압축 해제 후 이미지 저장"
    echo "  tar xzf $DIST_DIR/${PKG_NAME}.tar.gz"
    echo "  cd $PKG_NAME"
    echo "  ./save-images.sh ${IMAGE_TAG}"
    echo ""
    echo "  # 2. images/ 포함하여 재패키징"
    echo "  cd $RELEASE_DIR"
    echo "  ./package.sh $VERSION --with-images ${IMAGE_TAG}"
    echo ""
    echo "━━━ 서버 배포 방법 ─────────────────────────────────────"
    echo ""
    echo "  # 서버에서"
    echo "  tar xzf ${PKG_NAME}.tar.gz && cd ${PKG_NAME}"
    echo "  bash server-setup.sh          # 초기 설정"
    echo "  nano .env                     # 환경변수 편집"
    echo "  bash deploy.sh                # 배포 (http://서버IP:8082)"
    echo ""
  fi
}

# ── 메인 ──────────────────────────────────────────────────────────────────────
main() {
  echo ""
  log "📦 UISCloud 패키지 생성 시작"
  info "버전:         $VERSION"
  if [ "$BUILD_ON_SERVER" = true ]; then
    info "유형:         서버 빌드 패키지 (소스코드 포함)"
  else
    info "이미지 포함:  $WITH_IMAGES"
    [ "$WITH_IMAGES" = true ] && info "이미지 태그:  $IMAGE_TAG"
  fi
  echo ""

  mkdir -p "$DIST_DIR"

  prepare_dirs
  copy_compose_files
  copy_nginx_configs
  copy_scripts
  copy_env_template
  copy_sources
  if [ "$BUILD_ON_SERVER" = false ]; then
    save_images
  fi
  create_tarball
  print_summary
}

main
