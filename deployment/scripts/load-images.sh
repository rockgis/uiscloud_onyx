#!/bin/bash
# =============================================================================
# Docker 이미지 로드 스크립트 (폐쇄망용)
#
# images/ 디렉터리의 .tar 파일들을 Docker에 로드합니다.
# save-images.sh 로 저장한 이미지를 폐쇄망 서버에서 로드할 때 사용합니다.
#
# 사용법:
#   ./load-images.sh
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGES_DIR="$SCRIPT_DIR/images"

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

main() {
  echo ""
  log "📦 Docker 이미지 로드 시작"
  info "이미지 경로: $IMAGES_DIR"
  echo ""

  if ! command -v docker &>/dev/null; then
    error "Docker가 설치되어 있지 않습니다."
    error "Docker를 먼저 설치한 후 다시 실행하세요."
    exit 1
  fi

  if [ ! -d "$IMAGES_DIR" ]; then
    error "images/ 디렉터리가 없습니다: $IMAGES_DIR"
    error "save-images.sh를 먼저 실행하여 이미지를 저장하세요."
    exit 1
  fi

  # .tar 파일 목록 수집
  local tar_files=()
  while IFS= read -r -d '' f; do
    tar_files+=("$f")
  done < <(find "$IMAGES_DIR" -maxdepth 1 -name "*.tar" -print0 | sort -z)

  if [ ${#tar_files[@]} -eq 0 ]; then
    error "images/ 디렉터리에 .tar 파일이 없습니다."
    error "save-images.sh로 이미지를 먼저 저장하세요."
    exit 1
  fi

  local loaded=0
  local failed=0

  for tar_file in "${tar_files[@]}"; do
    local filename
    filename="$(basename "$tar_file")"
    log "로드 중: $filename"

    if docker load -i "$tar_file"; then
      loaded=$((loaded + 1))
      info "  ✅ 완료"
    else
      error "  ❌ 실패: $filename"
      failed=$((failed + 1))
    fi
    echo ""
  done

  log "═══════════════════════════════════════════════════"
  log " 로드 결과: ${loaded}개 성공 / ${failed}개 실패"
  log "═══════════════════════════════════════════════════"

  if [ "$failed" -gt 0 ]; then
    error "일부 이미지 로드에 실패했습니다."
    exit 1
  fi

  echo ""
  info "로드된 이미지 목록:"
  docker images --format "  {{.Repository}}:{{.Tag}}\t{{.Size}}"
  echo ""
  log "✅ 모든 이미지 로드 완료. 이제 deploy.sh를 실행하세요."
  echo ""
}

main
