#!/bin/bash

# Script para parar o ambiente de desenvolvimento de bancos de dados
# Este script para APENAS os containers definidos no docker-compose.yml local
# Não afeta outros containers Docker em execução no sistema
# Autor: Infrastructure Team

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

# Função para listar containers do projeto
list_project_containers() {
    echo -e "${GREEN}Containers do projeto 'databases':${NC}"
    docker compose ps --format 'table {{.Name}}\t{{.Service}}\t{{.Status}}' 2>/dev/null || echo "Nenhum container encontrado"
    echo ""
}

echo "🛑 Parando ambiente de desenvolvimento de bancos de dados..."

# Opção para apenas listar containers
if [ "$1" == "--list" ] || [ "$1" == "-l" ]; then
    log "Containers do projeto 'databases':"
    list_project_containers
    exit 0
fi

# Verificar se Docker está rodando
if ! docker info > /dev/null 2>&1; then
    warn "Docker não está rodando."
    exit 0
fi

# Verificar se o arquivo docker-compose.yml existe
if [ ! -f "docker-compose.yml" ]; then
    warn "Arquivo docker-compose.yml não encontrado no diretório atual."
    warn "Execute este script no diretório que contém o docker-compose.yml dos bancos de dados."
    exit 1
fi

# Verificar se estamos no diretório correto (deve conter serviços de banco)
if ! grep -q "postgres\|mysql\|mongodb\|redis" docker-compose.yml 2>/dev/null; then
    warn "Este não parece ser o docker-compose.yml dos bancos de dados."
    warn "Certifique-se de estar no diretório correto."
    exit 1
fi

# Verificar containers em execução antes de parar
log "Verificando containers do projeto..."
list_project_containers

RUNNING_CONTAINERS=$(docker compose ps -q 2>/dev/null || echo "")
if [ -z "$RUNNING_CONTAINERS" ]; then
    log "Nenhum container do projeto está em execução."
    exit 0
else
    CONTAINER_COUNT=$(echo "$RUNNING_CONTAINERS" | wc -l)
    log "Encontrados $CONTAINER_COUNT containers do projeto para parar."
fi

# Parar todos os serviços do projeto atual
log "Parando serviços de bancos de dados..."
docker compose down

# Opcional: remover volumes (descomentar se necessário)
if [ "$1" == "--volumes" ]; then
    warn "Removendo volumes do projeto (DADOS SERÃO PERDIDOS)..."
    docker compose down -v
fi

# Opcional: remover imagens (descomentar se necessário)
if [ "$1" == "--images" ]; then
    warn "Removendo imagens do projeto..."
    docker compose down --rmi all
fi

# Limpeza completa
if [ "$1" == "--clean" ]; then
    warn "Limpeza do projeto (containers, volumes e órfãos; imagens são mantidas, use --images para removê-las)..."
    docker compose down -v --remove-orphans
    
    # IMPORTANTE: NÃO removemos a rede 'development_environment' pois é compartilhada
    # entre múltiplas aplicações e deve ser gerenciada pelo start.sh
    log "Rede 'development_environment' preservada (compartilhada entre aplicações)"
    
    # Limpar diretórios de dados locais se solicitado
    if [ "$2" == "--data" ] || [ "$1" == "--data" ]; then
        warn "Removendo diretórios de dados locais..."
        rm -rf data/ 2>/dev/null || true
        log "Diretórios de dados removidos."
    fi
fi

log "✅ Ambiente de bancos de dados parado com sucesso!"
echo ""
echo "Opções disponíveis:"
echo "  ./stop.sh                    - Para apenas os containers do projeto"
echo "  ./stop.sh --list             - Lista containers do projeto sem parar"
echo "  ./stop.sh --volumes          - Para containers e remove volumes do projeto"
echo "  ./stop.sh --images           - Para containers e remove imagens do projeto"
echo "  ./stop.sh --clean            - Remove containers/volumes/órfãos (mantém imagens e rede externa)"
echo "  ./stop.sh --clean --data     - Idem + remove dados locais (data/)"
echo ""
echo "ℹ️  Nota: A rede 'development_environment' é preservada (compartilhada entre aplicações)."
