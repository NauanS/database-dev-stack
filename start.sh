#!/bin/bash

# Script de configuração do ambiente de desenvolvimento
# Este script NÃO inicia containers - apenas prepara o ambiente
# Use 'make CONTEXTO-start' para iniciar serviços específicos
# Autor: Infrastructure Team

set -e

echo "� Configurando ambiente de desenvolvimento..."

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Função para logging
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
}

# Verificar se Docker está rodando
if ! docker info > /dev/null 2>&1; then
    error "Docker não está rodando. Inicie o Docker primeiro."
    exit 1
fi

# Verificar se Docker Compose está instalado
if ! command -v docker > /dev/null 2>&1; then
    error "Docker não está instalado."
    exit 1
fi

# Verificar se o plugin compose está disponível
if ! docker compose version > /dev/null 2>&1; then
    error "Docker Compose plugin não está instalado. Use 'docker compose' em vez de 'docker-compose'."
    exit 1
fi

# Verificar se arquivo .env existe; se não, gera com senhas seguras
if [ ! -f .env ]; then
    warn "Arquivo .env não encontrado."
    if [ -x ./generate-passwords.sh ]; then
        log "Gerando .env com senhas seguras..."
        ./generate-passwords.sh
    else
        error "generate-passwords.sh não encontrado/executável. Não é possível gerar o .env."
        exit 1
    fi
fi

# Criar diretórios necessários
log "Criando estrutura de diretórios..."
mkdir -p data/{postgres,mysql,mariadb,mongodb,redis,redisinsight,firebird,pgadmin}
mkdir -p configs/{postgres/init,mysql/{init,conf.d},mariadb/init,mongodb/init,redis}
mkdir -p logs

# pgAdmin roda como uid 5050 no container e precisa poder escrever em data/pgadmin
# (RedisInsight roda como 1000:1000, o uid padrão do usuário Linux)
if [ "$(stat -c %u data/pgadmin)" != "5050" ]; then
    warn "data/pgadmin não pertence ao uid 5050 (pgAdmin pode falhar por permissão)."
    warn "Corrija com: sudo chown -R 5050:5050 data/pgadmin"
fi

# Criar arquivo de configuração do Redis se não existir
if [ ! -f configs/redis/redis.conf ]; then
    log "Criando configuração do Redis..."
    cat > configs/redis/redis.conf << EOF
# Configuração básica do Redis para desenvolvimento
# Acessível pela rede Docker; a porta é publicada no host pelo compose e protegida por requirepass
bind 0.0.0.0
protected-mode yes
port 6379
timeout 0
tcp-keepalive 300
daemonize no
supervised no
pidfile /var/run/redis_6379.pid
loglevel notice
logfile ""
databases 16
save 900 1
save 300 10
save 60 10000
stop-writes-on-bgsave-error yes
rdbcompression yes
rdbchecksum yes
dbfilename dump.rdb
dir /data
appendonly yes
appendfilename "appendonly.aof"
appendfsync everysec
maxmemory 256mb
maxmemory-policy allkeys-lru
no-appendfsync-on-rewrite no
auto-aof-rewrite-percentage 100
auto-aof-rewrite-min-size 64mb
aof-load-truncated yes
lua-time-limit 5000
slowlog-log-slower-than 10000
slowlog-max-len 128
latency-monitor-threshold 0
notify-keyspace-events ""
hash-max-ziplist-entries 512
hash-max-ziplist-value 64
list-max-ziplist-size -2
list-compress-depth 0
set-max-intset-entries 512
zset-max-ziplist-entries 128
zset-max-ziplist-value 64
hll-sparse-max-bytes 3000
activerehashing yes
client-output-buffer-limit normal 0 0 0
client-output-buffer-limit replica 256mb 64mb 60
client-output-buffer-limit pubsub 32mb 8mb 60
hz 10
aof-rewrite-incremental-fsync yes
EOF
fi

# Criar configuração personalizada do MySQL se não existir
if [ ! -f configs/mysql/conf.d/custom.cnf ]; then
    log "Criando configuração customizada do MySQL..."
    cat > configs/mysql/conf.d/custom.cnf << EOF
[mysqld]
# Configurações para desenvolvimento
default-authentication-plugin=mysql_native_password
character-set-server=utf8mb4
collation-server=utf8mb4_unicode_ci
default-time-zone='-03:00'

# Performance
innodb_buffer_pool_size=256M
innodb_log_file_size=64M
innodb_flush_log_at_trx_commit=2
innodb_flush_method=O_DIRECT

# Logs
general_log=0
general_log_file=/var/lib/mysql/general.log
slow_query_log=1
slow_query_log_file=/var/lib/mysql/slow.log
long_query_time=2

# Connections
max_connections=200
wait_timeout=600
interactive_timeout=600

[mysql]
default-character-set=utf8mb4

[client]
default-character-set=utf8mb4
EOF
fi

# Verificar se a rede externa existe, senão criar
log "Verificando rede Docker externa..."
NETWORK_NAME="development_environment"
if ! docker network ls | grep -q "$NETWORK_NAME"; then
    log "Criando rede externa $NETWORK_NAME..."
    docker network create $NETWORK_NAME --driver bridge --subnet 172.20.0.0/16
    log "✅ Rede $NETWORK_NAME criada com sucesso!"
else
    log "✅ Rede $NETWORK_NAME já existe"
fi

log "✅ Ambiente configurado com sucesso!"
echo ""
echo -e "${BLUE}=== COMANDOS DISPONÍVEIS POR CONTEXTO ===${NC}"
echo ""
echo -e "${GREEN}PostgreSQL:${NC}"
echo "  make postgres-start    # Inicia PostgreSQL + pgAdmin4"
echo "  make postgres-stop     # Para PostgreSQL + pgAdmin4"
echo ""
echo -e "${GREEN}MySQL:${NC}"
echo "  make mysql-start       # Inicia MySQL + Adminer"
echo "  make mysql-stop        # Para MySQL + Adminer"
echo ""
echo -e "${GREEN}MariaDB:${NC}"
echo "  make mariadb-start     # Inicia MariaDB + Adminer"
echo "  make mariadb-stop      # Para MariaDB + Adminer"
echo ""
echo -e "${GREEN}MongoDB:${NC}"
echo "  make mongodb-start     # Inicia MongoDB + Mongo Express"
echo "  make mongodb-stop      # Para MongoDB + Mongo Express"
echo ""
echo -e "${GREEN}Redis:${NC}"
echo "  make redis-start       # Inicia Redis"
echo "  make redis-stop        # Para Redis"
echo ""
echo -e "${GREEN}Firebird:${NC}"
echo "  make firebird-start    # Inicia Firebird"
echo "  make firebird-stop     # Para Firebird"
echo ""
echo -e "${GREEN}Outros comandos:${NC}"
echo "  make help              # Ver todos os comandos"
echo "  make status            # Status dos serviços"
echo "  make stop-all          # Para todos os serviços"
