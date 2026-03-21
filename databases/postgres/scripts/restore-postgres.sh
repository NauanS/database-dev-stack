#!/bin/bash

# Script de Restore do PostgreSQL
# Restaura um backup específico

set -e

# Carregar variáveis de ambiente
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/.env" ]; then
    source "$SCRIPT_DIR/load-env.sh"
fi

# Configurações (com valores padrão se não definidos no .env)
CONTAINER_NAME="${CONTAINER_NAME:-postgres}"
POSTGRES_USER="${POSTGRES_USER:-postgres}"

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Função de log
log() {
    echo -e "${GREEN}[$(date +"%Y-%m-%d %H:%M:%S")]${NC} $1"
}

error() {
    echo -e "${RED}[$(date +"%Y-%m-%d %H:%M:%S")] ERRO:${NC} $1"
}

warning() {
    echo -e "${YELLOW}[$(date +"%Y-%m-%d %H:%M:%S")] AVISO:${NC} $1"
}

info() {
    echo -e "${BLUE}$1${NC}"
}

# Banner
echo ""
info "=========================================="
info "    RESTORE DE BACKUP - PostgreSQL"
info "=========================================="
echo ""

# Verifica se o container está rodando
if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    error "Container '$CONTAINER_NAME' não está rodando!"
    exit 1
fi

# Solicita o caminho do arquivo de backup
echo -n "Digite o caminho completo do arquivo de backup: "
read -r BACKUP_FILE

# Verifica se o arquivo existe
if [ ! -f "$BACKUP_FILE" ]; then
    error "Arquivo não encontrado: $BACKUP_FILE"
    exit 1
fi

# Extrai o nome do banco do arquivo
FILENAME=$(basename "$BACKUP_FILE")
# Remove a extensão .sql/.sql.gz  e extrai tudo antes do padrão _YYYY-MM-DD_HH:MM:SS
DB_NAME=$(echo "$FILENAME" | sed 's/\.sql\.gz$//' | sed 's/\.sql$//' | sed 's/_[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}_.*$//')

# Detecta se o arquivo está comprimido
IS_COMPRESSED=false
if [[ "$BACKUP_FILE" == *.gz ]]; then
    IS_COMPRESSED=true
    info "📦 Backup comprimido detectado"
fi

info "Arquivo de backup: $BACKUP_FILE"
info "Nome do banco: $DB_NAME"
echo ""

# Pergunta se quer criar um novo banco ou sobrescrever
echo "O que deseja fazer?"
echo "1) Restaurar em banco existente '$DB_NAME' (sobrescrever dados)"
echo "2) Criar novo banco com outro nome"
echo "3) Cancelar"
echo ""
echo -n "Escolha uma opção [1-3]: "
read -r OPTION

case $OPTION in
    1)
        TARGET_DB="$DB_NAME"
        warning "ATENÇÃO: Todos os dados atuais do banco '$TARGET_DB' serão perdidos!"
        echo -n "Confirma a operação? (digite 'sim' para confirmar): "
        read -r CONFIRM
        
        if [ "$CONFIRM" != "sim" ]; then
            log "Operação cancelada pelo usuário."
            exit 0
        fi
        
        log "Dropando banco existente '$TARGET_DB'..."
        docker exec "$CONTAINER_NAME" psql -U "$POSTGRES_USER" -c "DROP DATABASE IF EXISTS $TARGET_DB;" 2>/dev/null || true
        
        log "Criando banco '$TARGET_DB'..."
        docker exec "$CONTAINER_NAME" psql -U "$POSTGRES_USER" -c "CREATE DATABASE $TARGET_DB;"
        ;;
        
    2)
        echo -n "Digite o nome do novo banco: "
        read -r TARGET_DB
        
        if [ -z "$TARGET_DB" ]; then
            error "Nome do banco não pode ser vazio!"
            exit 1
        fi
        
        log "Criando banco '$TARGET_DB'..."
        docker exec "$CONTAINER_NAME" psql -U "$POSTGRES_USER" -c "CREATE DATABASE $TARGET_DB;" 2>/dev/null || {
            error "Banco '$TARGET_DB' já existe ou não pôde ser criado!"
            exit 1
        }
        ;;
        
    3)
        log "Operação cancelada pelo usuário."
        exit 0
        ;;
        
    *)
        error "Opção inválida!"
        exit 1
        ;;
esac

# Executa o restore
log "Restaurando backup em '$TARGET_DB'..."
echo ""

# Descomprime e restaura se necessário
if [ "$IS_COMPRESSED" = true ]; then
    if zcat "$BACKUP_FILE" | docker exec -i "$CONTAINER_NAME" psql -U "$POSTGRES_USER" -d "$TARGET_DB"; then
        echo ""
        log "✓ Restore concluído com sucesso!"
        info "Banco de dados: $TARGET_DB"
    else
        echo ""
        error "✗ Falha ao restaurar backup!"
        exit 1
    fi
else
    if docker exec -i "$CONTAINER_NAME" psql -U "$POSTGRES_USER" -d "$TARGET_DB" < "$BACKUP_FILE"; then
        echo ""
        log "✓ Restore concluído com sucesso!"
        info "Banco de dados: $TARGET_DB"
    else
        echo ""
        error "✗ Falha ao restaurar backup!"
        exit 1
    fi
fi

echo ""
info "=========================================="
log "Processo finalizado!"
info "=========================================="
echo ""

exit 0
