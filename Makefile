.PHONY: help up down restart logs build clean ps shell-admin shell-chroma backup restore dev-chroma

# Variables
COMPOSE_FILE := docker-compose.yml
PROJECT_NAME := chromadb-admin
BACKUP_DIR := ./backups

help: ## Hiển thị trợ giúp
	@echo "ChromaDB Admin - Docker Commands"
	@echo "================================="
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

up: ## Start tất cả services (detached mode)
	docker-compose up -d

down: ## Stop và remove containers
	docker-compose down

down-v: ## Stop và remove containers + volumes (XÓA DATA!)
	@echo "⚠️  WARNING: Lệnh này sẽ XÓA TẤT CẢ DATA!"
	@read -p "Bạn có chắc muốn tiếp tục? [y/N] " -n 1 -r; \
	echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		docker-compose down -v; \
	fi

restart: ## Restart tất cả services
	docker-compose restart

restart-admin: ## Restart chỉ admin service
	docker-compose restart chromadb-admin

restart-chroma: ## Restart chỉ chromadb service
	docker-compose restart chromadb

logs: ## Xem logs của tất cả services
	docker-compose logs -f

logs-admin: ## Xem logs của admin service
	docker-compose logs -f chromadb-admin

logs-chroma: ## Xem logs của chromadb service
	docker-compose logs -f chromadb

build: ## Build lại images
	docker-compose build

build-no-cache: ## Build lại images (no cache)
	docker-compose build --no-cache

rebuild: ## Rebuild và restart services
	docker-compose up -d --build

ps: ## Xem trạng thái containers
	docker-compose ps

shell-admin: ## Vào shell của admin container
	docker-compose exec chromadb-admin sh

shell-chroma: ## Vào shell của chromadb container
	docker-compose exec chromadb sh

clean: ## Dọn dẹp containers và images không dùng
	docker system prune -f

clean-all: ## Dọn dẹp tất cả (containers, images, volumes)
	@echo "⚠️  WARNING: Lệnh này sẽ XÓA TẤT CẢ containers, images, và volumes không sử dụng!"
	@read -p "Bạn có chắc muốn tiếp tục? [y/N] " -n 1 -r; \
	echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		docker system prune -a --volumes -f; \
	fi

backup: ## Backup ChromaDB data
	@mkdir -p $(BACKUP_DIR)
	@echo "Creating backup..."
	@docker run --rm \
		-v $(PROJECT_NAME)_chroma_data:/data \
		-v $(PWD)/$(BACKUP_DIR):/backup \
		alpine tar czf /backup/chroma-backup-$$(date +%Y%m%d-%H%M%S).tar.gz -C /data .
	@echo "✅ Backup completed! Files saved in $(BACKUP_DIR)/"
	@ls -lh $(BACKUP_DIR)

restore: ## Restore ChromaDB data từ backup (cần BACKUP_FILE=filename)
	@if [ -z "$(BACKUP_FILE)" ]; then \
		echo "❌ Error: BACKUP_FILE is required"; \
		echo "Usage: make restore BACKUP_FILE=chroma-backup-YYYYMMDD-HHMMSS.tar.gz"; \
		exit 1; \
	fi
	@echo "⚠️  WARNING: Lệnh này sẽ GHI ĐÈ data hiện tại!"
	@read -p "Bạn có chắc muốn restore từ $(BACKUP_FILE)? [y/N] " -n 1 -r; \
	echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		echo "Stopping services..."; \
		docker-compose down; \
		echo "Restoring backup..."; \
		docker run --rm \
			-v $(PROJECT_NAME)_chroma_data:/data \
			-v $(PWD)/$(BACKUP_DIR):/backup \
			alpine tar xzf /backup/$(BACKUP_FILE) -C /data; \
		echo "Starting services..."; \
		docker-compose up -d; \
		echo "✅ Restore completed!"; \
	fi

dev-chroma: ## Chỉ start ChromaDB cho development (run admin local)
	docker-compose up -d chromadb

dev-local: ## Stop admin container, chỉ giữ chromadb (để run local dev)
	docker-compose stop chromadb-admin

health: ## Kiểm tra health của services
	@echo "Checking ChromaDB..."
	@curl -f http://localhost:8000/api/v1/heartbeat && echo "✅ ChromaDB is healthy" || echo "❌ ChromaDB is not responding"
	@echo "\nChecking Admin UI..."
	@curl -f http://localhost:3001 && echo "✅ Admin UI is healthy" || echo "❌ Admin UI is not responding"

stats: ## Xem resource usage của containers
	docker stats --no-stream

# Development shortcuts
dev-install: ## Install dependencies local
	npm install

dev-start: dev-chroma dev-install ## Start ChromaDB + Run admin local
	npm run dev

# Production
prod-up: ## Start production mode
	docker-compose up -d

prod-logs: ## Production logs
	docker-compose logs --tail=100 -f

# Alias commands
start: up ## Alias của 'up'
stop: down ## Alias của 'down'

