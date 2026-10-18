#!/bin/bash

# Script de Restore do PostgreSQL
# Restaura um backup específico (lista os backups disponíveis ou aceita um caminho)

set -e

# Carregar variáveis de ambiente
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/.env" ]; then
    source "$SCRIPT_DIR/load-env.sh"
fi

# Configurações (com valores padrão se não definidos no .env)
BACKUP_DIR="${BACKUP_DIR:-$SCRIPT_DIR/../bkps}"
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

# Nome de banco seguro para usar como identificador SQL entre aspas
valid_db_name() {
    [[ "$1" =~ ^[A-Za-z0-9_-]+$ ]]
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

# Lista os backups disponíveis (mais recentes primeiro)
mapfile -t BACKUPS < <(find "$BACKUP_DIR" -maxdepth 1 -type f \( -name '*.sql.gz' -o -name '*.sql' \) -printf '%T@ %p\n' 2>/dev/null | sort -rn | cut -d' ' -f2-)

if [ ${#BACKUPS[@]} -gt 0 ]; then
    echo "Backups disponíveis:"
    for i in "${!BACKUPS[@]}"; do
        printf "  %2d) %s\n" "$((i + 1))" "$(basename "${BACKUPS[$i]}")"
    done
    echo ""
fi

echo -n "Digite o número do backup ou o caminho completo do arquivo: "
read -r CHOICE

if [[ "$CHOICE" =~ ^[0-9]+$ ]] && [ "$CHOICE" -ge 1 ] && [ "$CHOICE" -le ${#BACKUPS[@]} ]; then
    BACKUP_FILE="${BACKUPS[$((CHOICE - 1))]}"
else
    BACKUP_FILE="$CHOICE"
fi

# Verifica se o arquivo existe
if [ ! -f "$BACKUP_FILE" ]; then
    error "Arquivo não encontrado: $BACKUP_FILE"
    exit 1
fi

# Extrai o nome do banco do arquivo
FILENAME=$(basename "$BACKUP_FILE")
# Remove a extensão .sql/.sql.gz e extrai tudo antes do padrão _YYYY-MM-DD_HH:MM:SS
DB_NAME=$(echo "$FILENAME" | sed 's/\.sql\.gz$//' | sed 's/\.sql$//' | sed 's/_[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}_.*$//')

# Detecta se o arquivo está comprimido
IS_COMPRESSED=false
if [[ "$BACKUP_FILE" == *.gz ]]; then
    IS_COMPRESSED=true
    info "📦 Backup comprimido detectado"
fi

# Executa o SQL do backup no banco indicado ($1); lê do arquivo, descomprimindo se preciso
run_restore() {
    local target="$1"; shift
    if [ "$IS_COMPRESSED" = true ]; then
        zcat "$BACKUP_FILE" | docker exec -i "$CONTAINER_NAME" psql -U "$POSTGRES_USER" -d "$target" "$@"
    else
        docker exec -i "$CONTAINER_NAME" psql -U "$POSTGRES_USER" -d "$target" "$@" < "$BACKUP_FILE"
    fi
}

info "Arquivo de backup: $BACKUP_FILE"

# Backup de roles/globals: não é um banco; roda no banco 'postgres' e erros de
# "já existe" (roles existentes) são esperados, por isso sem ON_ERROR_STOP
if [ "$DB_NAME" = "globals" ]; then
    info "Tipo: roles e configurações globais (pg_dumpall --globals-only)"
    echo ""
    warning "Roles já existentes geram erros 'already exists' (inofensivos)."
    echo -n "Confirma a restauração dos globals? (digite 'sim' para confirmar): "
    read -r CONFIRM
    if [ "$CONFIRM" != "sim" ]; then
        log "Operação cancelada pelo usuário."
        exit 0
    fi

    log "Restaurando globals..."
    run_restore postgres || true
    echo ""
    log "Globals restaurados (revise as mensagens acima)."
    exit 0
fi

if ! valid_db_name "$DB_NAME"; then
    error "Nome de banco inválido extraído do arquivo: '$DB_NAME'"
    exit 1
fi

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

        # WITH (FORCE) encerra conexões abertas; erros agora aparecem em vez de serem escondidos
        log "Dropando banco existente '$TARGET_DB'..."
        docker exec "$CONTAINER_NAME" psql -U "$POSTGRES_USER" -c "DROP DATABASE IF EXISTS \"$TARGET_DB\" WITH (FORCE);"

        log "Criando banco '$TARGET_DB'..."
        docker exec "$CONTAINER_NAME" psql -U "$POSTGRES_USER" -c "CREATE DATABASE \"$TARGET_DB\";"
        ;;

    2)
        echo -n "Digite o nome do novo banco: "
        read -r TARGET_DB

        if [ -z "$TARGET_DB" ]; then
            error "Nome do banco não pode ser vazio!"
            exit 1
        fi

        if ! valid_db_name "$TARGET_DB"; then
            error "Nome inválido! Use apenas letras, números, '_' e '-'."
            exit 1
        fi

        log "Criando banco '$TARGET_DB'..."
        docker exec "$CONTAINER_NAME" psql -U "$POSTGRES_USER" -c "CREATE DATABASE \"$TARGET_DB\";" 2>/dev/null || {
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

if run_restore "$TARGET_DB" -v ON_ERROR_STOP=1; then
    echo ""
    log "✓ Restore concluído com sucesso!"
    info "Banco de dados: $TARGET_DB"
else
    echo ""
    error "✗ Falha ao restaurar backup!"
    exit 1
fi

echo ""
info "=========================================="
log "Processo finalizado!"
info "=========================================="
echo ""

exit 0
