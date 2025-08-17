#!/bin/bash

# Script para gerar senhas seguras e atualizar arquivo .env
# Autor: Infrastructure Team

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

# Função para gerar senha segura
generate_password() {
    local length=${1:-16}
    # Gera senha com letras, números e símbolos seguros
    openssl rand -base64 $((length*3/4)) | tr -d "=+/" | cut -c1-${length}
}

# Função para gerar senha alfanumérica (mais compatível)
generate_alphanumeric_password() {
    local length=${1:-16}
    cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w ${length} | head -n 1
}

echo -e "${BLUE}🔐 Gerador de Senhas Seguras para Ambiente de Desenvolvimento${NC}"
echo ""

# Verificar se .env existe
if [ -f .env ]; then
    warn "Arquivo .env já existe. Deseja sobrescrever? (y/N)"
    read -r response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        echo "Operação cancelada."
        exit 0
    fi
    # Fazer backup
    cp .env .env.backup.$(date +%Y%m%d_%H%M%S)
    log "Backup criado: .env.backup.$(date +%Y%m%d_%H%M%S)"
fi

# Copiar do template
if [ -f .env.example ]; then
    cp .env.example .env
else
    log "Criando arquivo .env..."
    touch .env
fi

log "Gerando senhas seguras..."

# Gerar senhas
POSTGRES_PASSWORD=$(generate_alphanumeric_password 20)
PGADMIN_PASSWORD=$(generate_alphanumeric_password 20)
MYSQL_PASSWORD=$(generate_alphanumeric_password 20)
MYSQL_ROOT_PASSWORD=$(generate_alphanumeric_password 20)
MARIADB_PASSWORD=$(generate_alphanumeric_password 20)
MARIADB_ROOT_PASSWORD=$(generate_alphanumeric_password 20)
REDIS_PASSWORD=$(generate_alphanumeric_password 20)
MONGODB_ROOT_PASSWORD=$(generate_alphanumeric_password 20)
MONGO_EXPRESS_PASSWORD=$(generate_alphanumeric_password 16)
FIREBIRD_PASSWORD=$(generate_alphanumeric_password 16)

# Criar arquivo .env completo
cat > .env << EOF
# ===================================
# CONFIGURAÇÕES DO AMBIENTE DE DESENVOLVIMENTO
# ===================================
# GERADO AUTOMATICAMENTE EM: $(date '+%Y-%m-%d %H:%M:%S')
# IMPORTANTE: Nunca commitar este arquivo!

# ===================================
# REDE
# ===================================
NETWORK_NAME=development_environment

# ===================================
# POSTGRESQL
# ===================================
POSTGRES_DB=dev_database
POSTGRES_USER=postgres
POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
POSTGRES_PORT=5432

# ===================================
# PGADMIN4 - Interface Web PostgreSQL
# ===================================
PGADMIN_EMAIL=admin@admin.com
PGADMIN_PASSWORD=${PGADMIN_PASSWORD}
PGADMIN_PORT=5050

# ===================================
# MYSQL
# ===================================
MYSQL_DATABASE=dev_database
MYSQL_USER=mysql_user
MYSQL_PASSWORD=${MYSQL_PASSWORD}
MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD}
MYSQL_PORT=3306

# ===================================
# MARIADB
# ===================================
MARIADB_DATABASE=dev_database
MARIADB_USER=mariadb_user
MARIADB_PASSWORD=${MARIADB_PASSWORD}
MARIADB_ROOT_PASSWORD=${MARIADB_ROOT_PASSWORD}
MARIADB_PORT=3307

# ===================================
# REDIS
# ===================================
REDIS_PASSWORD=${REDIS_PASSWORD}
REDIS_PORT=6379

# ===================================
# REDISINSIGHT - Interface Web Redis
# ===================================
REDISINSIGHT_PORT=5540

# ===================================
# MONGODB
# ===================================
MONGODB_DATABASE=dev_database
MONGODB_ROOT_USER=admin
MONGODB_ROOT_PASSWORD=${MONGODB_ROOT_PASSWORD}
MONGODB_PORT=27017

# ===================================
# MONGO EXPRESS - Interface Web MongoDB
# ===================================
MONGO_EXPRESS_USER=admin
MONGO_EXPRESS_PASSWORD=${MONGO_EXPRESS_PASSWORD}
MONGO_EXPRESS_PORT=8081

# ===================================
# FIREBIRD
# ===================================
FIREBIRD_PASSWORD=${FIREBIRD_PASSWORD}
FIREBIRD_PORT=3050

# ===================================
# ADMINER - Interface Web SQL
# ===================================
ADMINER_PORT=8080
EOF

log "✅ Arquivo .env criado com senhas seguras!"
echo ""
echo -e "${BLUE}=== CREDENCIAIS GERADAS ===${NC}"
echo ""
echo -e "${GREEN}PostgreSQL:${NC}"
echo "  User: postgres"
echo "  Password: ${POSTGRES_PASSWORD}"
echo ""
echo -e "${GREEN}pgAdmin4:${NC}"
echo "  Email: admin@admin.com"
echo "  Password: ${PGADMIN_PASSWORD}"
echo "  URL: http://localhost:5050"
echo ""
echo -e "${GREEN}MySQL:${NC}"
echo "  User: mysql_user"
echo "  Password: ${MYSQL_PASSWORD}"
echo "  Root Password: ${MYSQL_ROOT_PASSWORD}"
echo ""
echo -e "${GREEN}MariaDB:${NC}"
echo "  User: mariadb_user"  
echo "  Password: ${MARIADB_PASSWORD}"
echo "  Root Password: ${MARIADB_ROOT_PASSWORD}"
echo ""
echo -e "${GREEN}Redis:${NC}"
echo "  Password: ${REDIS_PASSWORD}"
echo ""
echo -e "${GREEN}MongoDB:${NC}"
echo "  User: admin"
echo "  Password: ${MONGODB_ROOT_PASSWORD}"
echo ""
echo -e "${GREEN}Mongo Express:${NC}"
echo "  User: admin"
echo "  Password: ${MONGO_EXPRESS_PASSWORD}"
echo ""
echo -e "${GREEN}Firebird:${NC}"
echo "  Password: ${FIREBIRD_PASSWORD}"
echo ""
echo -e "${YELLOW}⚠️  IMPORTANTE: Salve essas credenciais em um local seguro!${NC}"
echo -e "${YELLOW}⚠️  O arquivo .env não deve ser commitado no Git!${NC}"
echo ""
echo -e "${GREEN}Para iniciar o ambiente: ./start.sh${NC}"
