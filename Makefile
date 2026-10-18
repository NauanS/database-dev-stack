# ===================================
# Makefile para Ambiente de Desenvolvimento por Contextos
# ===================================

.PHONY: help setup status logs clean backup restore passwords

# Configurações
COMPOSE_FILE=docker-compose.yml
ENV_FILE=.env

# Cores para output
GREEN=\033[0;32m
YELLOW=\033[1;33m
RED=\033[0;31m
BLUE=\033[0;34m
NC=\033[0m # No Color

help: ## 📋 Mostra esta ajuda
	@echo "$(GREEN)🚀 Comandos por contexto para bancos de dados:$(NC)"
	@echo ""
	@echo "$(BLUE)=== CONTEXTOS DISPONÍVEIS ===$(NC)"
	@echo "$(YELLOW)PostgreSQL:$(NC)"
	@echo "  make postgres-start        # Inicia PostgreSQL + pgAdmin4"
	@echo "  make postgres-stop         # Para PostgreSQL + pgAdmin4"
	@echo ""
	@echo "$(YELLOW)MySQL:$(NC)"
	@echo "  make mysql-start           # Inicia MySQL + Adminer"
	@echo "  make mysql-stop            # Para MySQL + Adminer"
	@echo ""
	@echo "$(YELLOW)MariaDB:$(NC)"
	@echo "  make mariadb-start         # Inicia MariaDB + Adminer"
	@echo "  make mariadb-stop          # Para MariaDB + Adminer"
	@echo ""
	@echo "$(YELLOW)MongoDB:$(NC)"
	@echo "  make mongodb-start         # Inicia MongoDB + Mongo Express"
	@echo "  make mongodb-stop          # Para MongoDB + Mongo Express"
	@echo ""
	@echo "$(YELLOW)Redis:$(NC)"
	@echo "  make redis-start           # Inicia Redis + RedisInsight"
	@echo "  make redis-stop            # Para Redis"
	@echo ""
	@echo "$(YELLOW)Firebird:$(NC)"
	@echo "  make firebird-start        # Inicia Firebird"
	@echo "  make firebird-stop         # Para Firebird"
	@echo ""
	@echo "$(BLUE)=== COMANDOS GERAIS ===$(NC)"
	@echo "  make setup                 # Configuração inicial"
	@echo "  make status                # Status de todos os serviços"
	@echo "  make stop-all              # Para todos os serviços"
	@echo "  make logs SERVICE=nome     # Logs de um serviço específico"
	@echo "  make shell-SERVICE         # Acessa shell do serviço"
	@echo ""

setup: ## ⚙️ Configuração inicial do ambiente
	@echo "$(GREEN)🔧 Configurando ambiente de desenvolvimento...$(NC)"
	@if [ ! -f $(ENV_FILE) ]; then \
		echo "$(YELLOW)Gerando configurações e senhas...$(NC)"; \
		./generate-passwords.sh; \
	else \
		echo "$(YELLOW)Arquivo .env já existe. Use 'make passwords' para regenerar.$(NC)"; \
	fi
	@echo "$(GREEN)✅ Configuração concluída!$(NC)"

passwords: ## 🔐 Gera novas senhas seguras
	@echo "$(GREEN)🔐 Gerando novas senhas...$(NC)"
	@./generate-passwords.sh

# ===================================
# CONTEXTO POSTGRESQL
# ===================================
postgres-start: ## 🐘 Inicia PostgreSQL + pgAdmin4
	@echo "$(GREEN)🐘 Iniciando contexto PostgreSQL...$(NC)"
	@docker compose up -d postgres pgadmin
	@echo "$(GREEN)✅ PostgreSQL disponível em: http://localhost:5432$(NC)"
	@echo "$(GREEN)✅ pgAdmin4 disponível em: http://localhost:5050$(NC)"

postgres-stop: ## 🛑 Para PostgreSQL + pgAdmin4
	@echo "$(YELLOW)🛑 Parando PostgreSQL e pgAdmin4...$(NC)"
	@docker compose stop postgres pgadmin

postgres-logs: ## 📋 Logs do PostgreSQL
	@docker compose logs -f postgres

postgres-shell: ## 🐘 Acessa shell do PostgreSQL
	@docker compose exec postgres sh -c 'psql -U "$$POSTGRES_USER" -d "$$POSTGRES_DB"'

# ===================================
# CONTEXTO MYSQL
# ===================================
mysql-start: ## 🐬 Inicia MySQL + Adminer
	@echo "$(GREEN)🐬 Iniciando contexto MySQL...$(NC)"
	@docker compose up -d mysql adminer
	@echo "$(GREEN)✅ MySQL disponível em: http://localhost:3306$(NC)"
	@echo "$(GREEN)✅ Adminer disponível em: http://localhost:8080$(NC)"

mysql-stop: ## 🛑 Para MySQL + Adminer
	@echo "$(YELLOW)🛑 Parando MySQL e Adminer...$(NC)"
	@docker compose stop mysql adminer

mysql-logs: ## 📋 Logs do MySQL
	@docker compose logs -f mysql

mysql-shell: ## 🐬 Acessa shell do MySQL
	@docker compose exec mysql mysql -u root -p

# ===================================
# CONTEXTO MARIADB
# ===================================
mariadb-start: ## 🦭 Inicia MariaDB + Adminer
	@echo "$(GREEN)🦭 Iniciando contexto MariaDB...$(NC)"
	@docker compose up -d mariadb adminer
	@echo "$(GREEN)✅ MariaDB disponível em: http://localhost:3307$(NC)"
	@echo "$(GREEN)✅ Adminer disponível em: http://localhost:8080$(NC)"

mariadb-stop: ## 🛑 Para MariaDB + Adminer
	@echo "$(YELLOW)🛑 Parando MariaDB e Adminer...$(NC)"
	@docker compose stop mariadb adminer

mariadb-logs: ## 📋 Logs do MariaDB
	@docker compose logs -f mariadb

mariadb-shell: ## 🦭 Acessa shell do MariaDB
	@docker compose exec mariadb mysql -u root -p

# ===================================
# CONTEXTO MONGODB
# ===================================
mongodb-start: ## 🍃 Inicia MongoDB + Mongo Express
	@echo "$(GREEN)🍃 Iniciando contexto MongoDB...$(NC)"
	@docker compose up -d mongodb mongo-express
	@echo "$(GREEN)✅ MongoDB disponível em: http://localhost:27017$(NC)"
	@echo "$(GREEN)✅ Mongo Express disponível em: http://localhost:8081$(NC)"

mongodb-stop: ## 🛑 Para MongoDB + Mongo Express
	@echo "$(YELLOW)🛑 Parando MongoDB e Mongo Express...$(NC)"
	@docker compose stop mongodb mongo-express

mongodb-logs: ## 📋 Logs do MongoDB
	@docker compose logs -f mongodb

mongodb-shell: ## 🍃 Acessa shell do MongoDB
	@docker compose exec mongodb mongosh

# ===================================
# CONTEXTO REDIS
# ===================================
redis-start: ## 🔴 Inicia Redis + RedisInsight
	@echo "$(GREEN)🔴 Iniciando contexto Redis...$(NC)"
	@docker compose up -d redis redisinsight
	@echo "$(GREEN)✅ Redis disponível em: http://localhost:6379$(NC)"
	@echo "$(GREEN)✅ RedisInsight disponível em: http://localhost:5540$(NC)"

redis-stop: ## 🛑 Para Redis + RedisInsight
	@echo "$(YELLOW)🛑 Parando Redis e RedisInsight...$(NC)"
	@docker compose stop redis redisinsight

redis-logs: ## 📋 Logs do Redis
	@docker compose logs -f redis

redis-shell: ## 🔴 Acessa shell do Redis
	@docker compose exec redis redis-cli

# ===================================
# CONTEXTO FIREBIRD
# ===================================
firebird-start: ## 🔥 Inicia Firebird
	@echo "$(GREEN)🔥 Iniciando contexto Firebird...$(NC)"
	@docker compose up -d firebird
	@echo "$(GREEN)✅ Firebird disponível em: http://localhost:3050$(NC)"

firebird-stop: ## 🛑 Para Firebird
	@echo "$(YELLOW)🛑 Parando Firebird...$(NC)"
	@docker compose stop firebird

firebird-logs: ## 📋 Logs do Firebird
	@docker compose logs -f firebird

# ===================================
# COMANDOS GERAIS
# ===================================
status: ## 📊 Mostra status de todos os serviços
	@echo "$(GREEN)📊 Status dos serviços:$(NC)"
	@docker compose ps

stop-all: ## 🛑 Para todos os serviços
	@echo "$(RED)🛑 Parando todos os serviços...$(NC)"
	@docker compose down

logs: ## 📋 Logs de um serviço (uso: make logs SERVICE=postgres)
	@if [ -z "$(SERVICE)" ]; then \
		echo "$(RED)❌ Especifique o serviço: make logs SERVICE=postgres$(NC)"; \
		exit 1; \
	fi
	@echo "$(GREEN)📋 Logs do $(SERVICE):$(NC)"
	@docker compose logs -f $(SERVICE)

backup: ## 💾 Backup de um contexto (uso: make backup SERVICE=postgres)
	@if [ -z "$(SERVICE)" ]; then \
		echo "$(RED)❌ Especifique o serviço: make backup SERVICE=postgres$(NC)"; \
		exit 1; \
	fi
	@echo "$(GREEN)💾 Fazendo backup do $(SERVICE)...$(NC)"
	@mkdir -p backups
	@if [ "$(SERVICE)" = "postgres" ]; then \
		docker compose exec -T postgres sh -c 'pg_dump -U "$$POSTGRES_USER" "$$POSTGRES_DB"' > backups/postgres_$(shell date +%Y%m%d_%H%M%S).sql; \
	elif [ "$(SERVICE)" = "mysql" ]; then \
		docker compose exec -T mysql sh -c 'mysqldump -u root -p"$$MYSQL_ROOT_PASSWORD" "$$MYSQL_DATABASE"' > backups/mysql_$(shell date +%Y%m%d_%H%M%S).sql; \
	elif [ "$(SERVICE)" = "mariadb" ]; then \
		docker compose exec -T mariadb sh -c 'mariadb-dump -u root -p"$$MYSQL_ROOT_PASSWORD" "$$MYSQL_DATABASE"' > backups/mariadb_$(shell date +%Y%m%d_%H%M%S).sql; \
	else \
		echo "$(RED)❌ Backup não suportado para $(SERVICE)$(NC)"; \
	fi

clean: ## 🧹 Remove containers/volumes (mantém imagens, dados em data/ e a rede)
	@echo "$(RED)🧹 Limpando containers e volumes...$(NC)"
	@./stop.sh --clean

info: ## ℹ️ Informações do ambiente
	@echo "$(GREEN)ℹ️ Informações do ambiente:$(NC)"
	@echo "Docker version: $(shell docker --version)"
	@echo "Docker Compose version: $(shell docker compose version)"
	@echo "Espaço em disco: $(shell df -h . | tail -1 | awk '{print $$4}') disponível"
	@echo "Memória: $(shell free -h | grep '^Mem:' | awk '{print $$7}') disponível"

# Aliases para facilitar
pg: postgres-start ## 🐘 Alias para postgres-start
pg-stop: postgres-stop ## 🛑 Alias para postgres-stop
