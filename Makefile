# =============================================================================
# UISCloud Makefile — 배포 및 개발 편의 명령어
#
# 사용법: make <target>
# 예시:   make deploy
# =============================================================================

COMPOSE_DIR     := deployment/docker_compose
COMPOSE_PROD    := -f docker-compose.prod.yml -f docker-compose.uiscloud.yml
COMPOSE_DEV     := -f docker-compose.yml
SHELL           := /bin/bash
.DEFAULT_GOAL   := help

# ── 도움말 ────────────────────────────────────────────────────────────────────
.PHONY: help
help:
	@echo ""
	@echo "UISCloud 배포 명령어"
	@echo "════════════════════════════════════════"
	@echo ""
	@echo "  🚀 배포"
	@echo "    make deploy            프로덕션 서버 배포 (이미지 pull + up)"
	@echo "    make deploy-dry        배포 시뮬레이션 (실제 배포 없음)"
	@echo "    make rollback          이전 버전으로 롤백"
	@echo ""
	@echo "  🔨 빌드"
	@echo "    make build-web         web-server 이미지 로컬 빌드"
	@echo "    make push-web          web-server 이미지 빌드 후 ghcr.io 푸시"
	@echo ""
	@echo "  🔍 상태 확인"
	@echo "    make status            실행 중인 컨테이너 상태"
	@echo "    make logs              모든 서비스 로그 (실시간)"
	@echo "    make logs-web          web_server 로그만"
	@echo "    make logs-api          api_server 로그만"
	@echo "    make health            헬스 체크"
	@echo ""
	@echo "  🛑 서비스 관리"
	@echo "    make up-prod           프로덕션 모드로 서비스 시작"
	@echo "    make down              모든 서비스 중지"
	@echo "    make restart-web       web_server만 재시작"
	@echo ""
	@echo "  💻 개발"
	@echo "    make dev               개발 서버 시작 (Next.js dev mode)"
	@echo "    make up-dev            개발용 Docker Compose 시작"
	@echo ""
	@echo "  🔧 초기 설정"
	@echo "    make setup-env         환경변수 파일 초기화"
	@echo "    make setup-server      새 서버 초기화 스크립트 실행"
	@echo ""

# ── 배포 ─────────────────────────────────────────────────────────────────────
.PHONY: deploy
deploy:
	@bash deployment/scripts/deploy.sh

.PHONY: deploy-dry
deploy-dry:
	@bash deployment/scripts/deploy.sh --dry-run

.PHONY: rollback
rollback:
	@bash deployment/scripts/deploy.sh --rollback

# ── 빌드 ─────────────────────────────────────────────────────────────────────
.PHONY: build-web
build-web:
	@echo "🔨 web-server 이미지 로컬 빌드..."
	docker build \
		--build-arg NODE_OPTIONS=--max-old-space-size=4096 \
		-t ghcr.io/rockgis/uiscloud_onyx/web-server:local \
		web/

.PHONY: push-web
push-web: build-web
	@echo "📤 web-server 이미지 ghcr.io 푸시..."
	docker push ghcr.io/rockgis/uiscloud_onyx/web-server:local
	@echo "✅ 푸시 완료"

# ── 상태 확인 ─────────────────────────────────────────────────────────────────
.PHONY: status
status:
	@cd $(COMPOSE_DIR) && docker compose $(COMPOSE_PROD) ps

.PHONY: logs
logs:
	@cd $(COMPOSE_DIR) && docker compose $(COMPOSE_PROD) logs -f --tail=100

.PHONY: logs-web
logs-web:
	@cd $(COMPOSE_DIR) && docker compose $(COMPOSE_PROD) logs -f --tail=100 web_server

.PHONY: logs-api
logs-api:
	@cd $(COMPOSE_DIR) && docker compose $(COMPOSE_PROD) logs -f --tail=100 api_server

.PHONY: health
health:
	@echo "헬스 체크 중..."
	@curl -fsS http://localhost/api/health && echo -e "\n✅ API 서버 정상" || echo -e "\n❌ API 서버 응답 없음"
	@curl -fsS -o /dev/null -w "웹 서버 HTTP 상태: %{http_code}\n" http://localhost/ || true

# ── 서비스 관리 ───────────────────────────────────────────────────────────────
.PHONY: up-prod
up-prod:
	@cd $(COMPOSE_DIR) && docker compose $(COMPOSE_PROD) up -d --wait

.PHONY: down
down:
	@cd $(COMPOSE_DIR) && docker compose $(COMPOSE_PROD) down

.PHONY: restart-web
restart-web:
	@cd $(COMPOSE_DIR) && docker compose $(COMPOSE_PROD) restart web_server nginx

# ── 개발 ─────────────────────────────────────────────────────────────────────
.PHONY: dev
dev:
	@cd web && npm run dev

.PHONY: up-dev
up-dev:
	@cd $(COMPOSE_DIR) && docker compose $(COMPOSE_DEV) up -d

# ── 초기 설정 ─────────────────────────────────────────────────────────────────
.PHONY: setup-env
setup-env:
	@if [ ! -f $(COMPOSE_DIR)/.env ]; then \
		cp $(COMPOSE_DIR)/.env.uiscloud.example $(COMPOSE_DIR)/.env; \
		echo "✅ .env 파일 생성: $(COMPOSE_DIR)/.env"; \
		echo "⚠️  반드시 편집하세요: nano $(COMPOSE_DIR)/.env"; \
	else \
		echo "⚠️  .env 파일이 이미 존재합니다. 덮어쓰지 않음."; \
	fi

.PHONY: setup-server
setup-server:
	@bash deployment/scripts/server-setup.sh
