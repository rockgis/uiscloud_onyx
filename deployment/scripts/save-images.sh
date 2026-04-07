#!/bin/bash
# =============================================================================
# 폐쇄망 배포용 Docker 이미지 저장 스크립트
#
# UISCloud 커스텀 이미지(web-server, onyx-backend, onyx-model-server)만 저장합니다.
# 서드파티 이미지(postgres, redis, nginx 등)는 Docker Hub에서 직접 pull 가능하므로
# 저장에서 제외합니다. 완전한 폐쇄망 환경이라면 서버에서 직접 pull해 두거나
# 별도로 저장하세요.
#
# 사용법:
#   ./save-images.sh                # 기본 태그(main) 사용
#   ./save-images.sh main           # main 브랜치 빌드 사용
#   ./save-images.sh sha-a1b3fb7    # 특정 커밋 사용
#
# 요구사항:
#   - Docker 설치된 인터넷 연결 환경
#   - ghcr.io 인증 완료 (비공개 이미지의 경우)
#       echo "<TOKEN>" | docker login ghcr.io -u <USER> --password-stdin
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 스탠드얼론 모드: 스크립트와 같은 디렉터리에 compose 파일이 있을 때
# 레포지토리 모드: deployment/scripts/ 하위에서 실행될 때
if [ -f "$SCRIPT_DIR/docker-compose.prod.yml" ]; then
  BASE_DIR="$SCRIPT_DIR"
else
  BASE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
fi

IMAGE_TAG="${1:-main}"
IMAGES_DIR="$BASE_DIR/images"

# 배포 대상 플랫폼 (폐쇄망 서버는 통상 linux/amd64)
# arm64 Mac에서 amd64 이미지를 저장할 수 있도록 플랫폼 명시
TARGET_PLATFORM="${TARGET_PLATFORM:-linux/amd64}"

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

# ── 이미지 목록 ───────────────────────────────────────────────────────────────
REGISTRY="ghcr.io/rockgis/uiscloud_onyx"

# UISCloud 커스텀 이미지 (형식: "이미지명|파일명.tar")
# 서드파티 이미지(postgres, redis, nginx 등)는 Docker Hub에서 직접 pull 가능하므로 제외
CUSTOM_IMAGES=(
  "${REGISTRY}/web-server:${IMAGE_TAG}|web-server.tar"
  "${REGISTRY}/onyx-backend:${IMAGE_TAG}|onyx-backend.tar"
  "${REGISTRY}/onyx-model-server:${IMAGE_TAG}|onyx-model-server.tar"
)

# ── 이미지 풀 & 저장 ──────────────────────────────────────────────────────────
save_image() {
  local image="$1"
  local filename="$2"
  local filepath="$IMAGES_DIR/$filename"

  if [ -f "$filepath" ]; then
    warn "이미 존재: $filename (덮어씁니다...)"
  fi

  log "풀 중: $image (플랫폼: $TARGET_PLATFORM)"
  if ! docker pull --platform "$TARGET_PLATFORM" "$image"; then
    error "풀 실패: $image"
    return 1
  fi

  log "저장 중: $filename"
  docker save "$image" -o "$filepath"

  local size
  size=$(du -sh "$filepath" | cut -f1)
  info "  ✅ $filename ($size)"
}

# ── 메인 ──────────────────────────────────────────────────────────────────────
main() {
  echo ""
  log "🗂️  폐쇄망 배포용 Docker 이미지 저장 시작"
  info "이미지 태그: $IMAGE_TAG"
  info "저장 경로:   $IMAGES_DIR"
  echo ""

  if ! command -v docker &>/dev/null; then
    error "Docker가 설치되어 있지 않습니다."
    exit 1
  fi

  mkdir -p "$IMAGES_DIR"

  local failed=0

  # UISCloud 커스텀 이미지 (서드파티는 Docker Hub에서 직접 pull)
  log "── UISCloud 커스텀 이미지 ──────────────────────────"
  for entry in "${CUSTOM_IMAGES[@]}"; do
    IFS='|' read -r image filename <<< "$entry"
    if ! save_image "$image" "$filename"; then
      failed=$((failed + 1))
    fi
  done

  # 매니페스트 파일 생성
  {
    echo "# UISCloud 이미지 매니페스트"
    echo "# 생성: $(date)"
    echo "# 이미지 태그: $IMAGE_TAG"
    echo "# 참고: 서드파티 이미지(postgres, redis, nginx 등)는 배포 시 자동 pull"
    echo ""
    for entry in "${CUSTOM_IMAGES[@]}"; do
      IFS='|' read -r image filename <<< "$entry"
      echo "$filename|$image"
    done
  } > "$IMAGES_DIR/MANIFEST"

  echo ""
  if [ "$failed" -gt 0 ]; then
    error "⚠️  ${failed}개 이미지 저장 실패. 위 오류를 확인하세요."
    exit 1
  fi

  log "═══════════════════════════════════════════════════"
  log " ✅ 이미지 저장 완료"
  log "═══════════════════════════════════════════════════"
  echo ""
  info "저장된 파일:"
  ls -lh "$IMAGES_DIR/"
  echo ""
  info "다음 단계:"
  info "  1. 배포 패키지 전체를 폐쇄망 서버로 전송"
  info "  2. 폐쇄망 서버에서 압축 해제 후 해당 디렉터리에서 실행:"
  info "       ./load-images.sh"
  info "       cp .env.example .env && nano .env"
  info "       ./deploy.sh"
  echo ""
}

main
