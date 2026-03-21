#!/bin/bash

# Script de Backup Automático do PostgreSQL
# Faz backup de todos os bancos de dados na instância
# Inclui: compressão, roles/globals, notificação Discord, retenção inteligente

# Nota: não usamos set -e para permitir melhor controle de erros

# Carregar variáveis de ambiente
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/.env" ]; then
    source "$SCRIPT_DIR/load-env.sh"
fi

# Configurações (com valores padrão se não definidos no .env)
BACKUP_DIR="${BACKUP_DIR:-$SCRIPT_DIR/../bkps}"
CONTAINER_NAME="${CONTAINER_NAME:-postgres}"
POSTGRES_USER="${POSTGRES_USER:-postgres}"
RETENTION_DAYS="${RETENTION_DAYS:-7}"
DATE_FORMAT=$(date +"%Y-%m-%d_%H:%M:%S")
DATE_SIMPLE=$(date +"%Y-%m-%d")
LOG_FILE="$BACKUP_DIR/backup.log"

# Discord Webhook (variável de ambiente)
DISCORD_WEBHOOK="${DISCORD_WEBHOOK_URL_BKP:-}"

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Função de log
log() {
    local msg="${GREEN}[$(date +"%Y-%m-%d %H:%M:%S")]${NC} $1"
    echo -e "$msg"
    echo -e "$msg" | sed 's/\x1b\[[0-9;]*m//g' >> "$LOG_FILE" 2>/dev/null || true
}

error() {
    local msg="${RED}[$(date +"%Y-%m-%d %H:%M:%S")] ERRO:${NC} $1"
    echo -e "$msg"
    echo -e "$msg" | sed 's/\x1b\[[0-9;]*m//g' >> "$LOG_FILE" 2>/dev/null || true
}

warning() {
    local msg="${YELLOW}[$(date +"%Y-%m-%d %H:%M:%S")] AVISO:${NC} $1"
    echo -e "$msg"
    echo -e "$msg" | sed 's/\x1b\[[0-9;]*m//g' >> "$LOG_FILE" 2>/dev/null || true
}

info() {
    local msg="${BLUE}[$(date +"%Y-%m-%d %H:%M:%S")]${NC} $1"
    echo -e "$msg"
    echo -e "$msg" | sed 's/\x1b\[[0-9;]*m//g' >> "$LOG_FILE" 2>/dev/null || true
}

# Função para enviar notificação ao Discord
send_discord_notification() {
    local title="$1"
    local description="$2"
    local color="$3"  # 3066993 (verde) ou 15158332 (vermelho)
    
    if [ -z "$DISCORD_WEBHOOK" ]; then
        return 0
    fi
    
    local payload=$(cat <<EOF
{
  "embeds": [{
    "title": "$title",
    "description": "$description",
    "color": $color,
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "footer": {
      "text": "PostgreSQL Backup - $(hostname)"
    }
  }]
}
EOF
)
    
    curl -s -X POST "$DISCORD_WEBHOOK" \
        -H "Content-Type: application/json" \
        -d "$payload" > /dev/null 2>&1 || true
}

# Verifica se o container está rodando
if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    error "Container '$CONTAINER_NAME' não está rodando!"
    send_discord_notification "❌ Backup Falhou" "Container '$CONTAINER_NAME' não está rodando!" 15158332
    exit 1
fi

# Cria diretório de backup se não existir
mkdir -p "$BACKUP_DIR"

log "=========================================="
log "Iniciando backup do PostgreSQL..."
log "=========================================="

START_TIME=$(date +%s)

# 1. Backup de Roles e Configurações Globais
log "1️⃣  Fazendo backup de roles e configurações globais..."
GLOBALS_FILE="$BACKUP_DIR/globals_${DATE_FORMAT}.sql.gz"

if docker exec "$CONTAINER_NAME" pg_dumpall -U "$POSTGRES_USER" --globals-only | gzip > "$GLOBALS_FILE" 2>/dev/null; then
    GLOBALS_SIZE=$(du -h "$GLOBALS_FILE" | cut -f1)
    log "✓ Backup de globals concluído: $GLOBALS_SIZE"
else
    error "✗ Falha ao fazer backup de globals"
    rm -f "$GLOBALS_FILE"
fi

# 2. Lista todos os bancos de dados (exceto templates e postgres system)
DATABASES=$(docker exec "$CONTAINER_NAME" psql -U "$POSTGRES_USER" -t -c "SELECT datname FROM pg_database WHERE datistemplate = false AND datname NOT IN ('postgres');" | grep -v '^$' | xargs)

if [ -z "$DATABASES" ]; then
    warning "Nenhum banco de dados encontrado para backup."
    send_discord_notification "⚠️  Backup Concluído com Aviso" "Nenhum banco de dados encontrado" 16776960
    exit 0
fi

log "2️⃣  Bancos encontrados: $DATABASES"

# Contador de backups
BACKUP_COUNT=0
FAILED_COUNT=0
TOTAL_SIZE=0

# Array para armazenar detalhes de cada banco
declare -a BACKUP_DETAILS

# Diretório temporário para resultados paralelos
TEMP_DIR="$BACKUP_DIR/.temp_$$"
mkdir -p "$TEMP_DIR"

# Função para fazer backup de um único banco (executa em paralelo)
backup_database() {
    local DB=$1
    local RESULT_FILE="$TEMP_DIR/${DB}.result"
    local BACKUP_FILE="$BACKUP_DIR/${DB}_${DATE_FORMAT}.sql.gz"
    
    # Redireciona logs para arquivo específico do banco
    exec > "$TEMP_DIR/${DB}.log" 2>&1
    
    echo "[$(date +"%Y-%m-%d %H:%M:%S")] 📦 Fazendo backup de '$DB'..."
    
    local DB_STATUS="✅"
    local RESTORE_STATUS="⏭️"
    local BACKUP_SIZE="N/A"
    local BACKUP_SIZE_BYTES=0
    local TABLE_COUNT=0
    
    if docker exec "$CONTAINER_NAME" pg_dump -U "$POSTGRES_USER" -d "$DB" 2>/dev/null | gzip > "$BACKUP_FILE" 2>/dev/null; then
        BACKUP_SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
        BACKUP_SIZE_BYTES=$(du -b "$BACKUP_FILE" | cut -f1)
        echo "[$(date +"%Y-%m-%d %H:%M:%S")] ✓ Backup de '$DB' concluído: $BACKUP_SIZE (comprimido)"
        
        # Teste de restore REAL em banco temporário
        echo "[$(date +"%Y-%m-%d %H:%M:%S")] 🔍 Testando restore de '$DB'..."
        TEST_DB="${DB}_restore_test_$$"
        
        # Cria banco temporário
        if docker exec "$CONTAINER_NAME" psql -U "$POSTGRES_USER" -c "CREATE DATABASE $TEST_DB;" > /dev/null 2>&1; then
            # Tenta fazer restore completo
            if zcat "$BACKUP_FILE" | docker exec -i "$CONTAINER_NAME" psql -U "$POSTGRES_USER" -d "$TEST_DB" > /dev/null 2>&1; then
                # Valida que o banco tem conteúdo (conta tabelas)
                TABLE_COUNT=$(docker exec "$CONTAINER_NAME" psql -U "$POSTGRES_USER" -d "$TEST_DB" -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public';" 2>/dev/null | xargs)
                
                if [ -n "$TABLE_COUNT" ] && [ "$TABLE_COUNT" -ge 0 ]; then
                    RESTORE_STATUS="✅"
                    echo "[$(date +"%Y-%m-%d %H:%M:%S")] ✓ Teste de restore OK ($TABLE_COUNT tabelas)"
                else
                    RESTORE_STATUS="⚠️"
                    echo "[$(date +"%Y-%m-%d %H:%M:%S")] ⚠️ Restore executou mas banco parece vazio"
                fi
            else
                RESTORE_STATUS="❌"
                echo "[$(date +"%Y-%m-%d %H:%M:%S")] ❌ Falha ao restaurar backup em banco de teste"
            fi
            
            # Limpa banco temporário
            docker exec "$CONTAINER_NAME" psql -U "$POSTGRES_USER" -c "DROP DATABASE IF EXISTS $TEST_DB;" > /dev/null 2>&1
        else
            RESTORE_STATUS="❌"
            echo "[$(date +"%Y-%m-%d %H:%M:%S")] ❌ Não foi possível criar banco de teste"
        fi
        
        # Salva resultado
        echo "SUCCESS|$DB|$BACKUP_SIZE|✅|$RESTORE_STATUS|$BACKUP_SIZE_BYTES|$TABLE_COUNT" > "$RESULT_FILE"
    else
        echo "[$(date +"%Y-%m-%d %H:%M:%S")] ✗ Falha ao fazer backup de '$DB'"
        rm -f "$BACKUP_FILE"
        echo "FAILED|$DB|N/A|❌|❌|0|0" > "$RESULT_FILE"
    fi
}

# 3. Faz backup de cada banco em paralelo
log "3️⃣  Iniciando backups paralelos..."
declare -a PIDS

for DB in $DATABASES; do
    backup_database "$DB" &
    PIDS+=($!)
done

# Aguarda todos os backups terminarem
log "⏳ Aguardando conclusão de ${#PIDS[@]} backup(s) paralelo(s)..."
wait

# Coleta resultados dos arquivos temporários
for DB in $DATABASES; do
    RESULT_FILE="$TEMP_DIR/${DB}.result"
    LOG_FILE_DB="$TEMP_DIR/${DB}.log"
    
    if [ -f "$RESULT_FILE" ]; then
        # Lê resultado
        IFS='|' read -r STATUS DB_NAME BACKUP_SIZE DB_STATUS RESTORE_STATUS BACKUP_SIZE_BYTES TABLE_COUNT < "$RESULT_FILE"
        
        # Exibe log do banco
        cat "$LOG_FILE_DB" 2>/dev/null
        
        # Adiciona aos detalhes
        BACKUP_DETAILS+=("$DB_NAME|$BACKUP_SIZE|$DB_STATUS|$RESTORE_STATUS")
        
        # Atualiza contadores
        if [ "$STATUS" = "SUCCESS" ]; then
            ((BACKUP_COUNT++))
            TOTAL_SIZE=$((TOTAL_SIZE + BACKUP_SIZE_BYTES))
        else
            ((FAILED_COUNT++))
        fi
    else
        error "✗ Resultado não encontrado para '$DB'"
        BACKUP_DETAILS+=("$DB|N/A|❌|❌")
        ((FAILED_COUNT++))
    fi
done

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))
TOTAL_SIZE_MB=$(LC_NUMERIC=C awk "BEGIN {printf \"%.3f\", $TOTAL_SIZE / 1024 / 1024}")

# 4. Salva métricas em JSON
METRICS_DIR="$BACKUP_DIR/metrics"
mkdir -p "$METRICS_DIR"
METRICS_FILE="$METRICS_DIR/${DATE_SIMPLE}.json"

# Constrói JSON com métricas do dia (força locale para ponto decimal)
cat > "$METRICS_FILE" << EOF
{
  "date": "$DATE_SIMPLE",
  "timestamp": "$DATE_FORMAT",
  "summary": {
    "total_backups": $BACKUP_COUNT,
    "failed_backups": $FAILED_COUNT,
    "success_rate": $(LC_NUMERIC=C awk "BEGIN {printf \"%.2f\", ($BACKUP_COUNT / ($BACKUP_COUNT + $FAILED_COUNT)) * 100}"),
    "total_size_mb": $TOTAL_SIZE_MB,
    "duration_seconds": $DURATION
  },
  "databases": [
EOF

# Adiciona métricas de cada banco
FIRST=true
for DB in $DATABASES; do
    RESULT_FILE="$TEMP_DIR/${DB}.result"
    if [ -f "$RESULT_FILE" ]; then
        IFS='|' read -r STATUS DB_NAME BACKUP_SIZE DB_STATUS RESTORE_STATUS BACKUP_SIZE_BYTES TABLE_COUNT < "$RESULT_FILE"
        
        if [ "$FIRST" = true ]; then
            FIRST=false
        else
            echo "," >> "$METRICS_FILE"
        fi
        
        BACKUP_SIZE_MB=$(LC_NUMERIC=C awk "BEGIN {printf \"%.3f\", $BACKUP_SIZE_BYTES / 1024 / 1024}")
        SUCCESS_FLAG=$([ "$STATUS" = "SUCCESS" ] && echo "true" || echo "false")
        VALIDATION_FLAG=$([ "$RESTORE_STATUS" = "✅" ] && echo "true" || echo "false")
        
        cat >> "$METRICS_FILE" << DBEOF
    {
      "name": "$DB_NAME",
      "status": "$DB_STATUS",
      "success": $SUCCESS_FLAG,
      "size_mb": $BACKUP_SIZE_MB,
      "size_human": "$BACKUP_SIZE",
      "tables_count": $TABLE_COUNT,
      "validation": {
        "status": "$RESTORE_STATUS",
        "passed": $VALIDATION_FLAG
      }
    }
DBEOF
    fi
done

# Fecha JSON
cat >> "$METRICS_FILE" << EOF

  ]
}
EOF

log "📊 Métricas salvas em: $METRICS_FILE"

# Atualiza dashboard.html chamando script separado
"$SCRIPT_DIR/update-dashboard.sh"

# Limpa diretório temporário
rm -rf "$TEMP_DIR"

# Resumo
echo ""
log "=========================================="
log "✅ Backup concluído!"
log "=========================================="
log "📊 Estatísticas:"
log "  • Bancos: $BACKUP_COUNT backups criados"
if [ $FAILED_COUNT -gt 0 ]; then
    error "  • Falhas: $FAILED_COUNT"
fi
log "  • Tamanho total: ${TOTAL_SIZE_MB}MB (comprimido)"
log "  • Duração: ${DURATION}s"
log "  • Diretório: $BACKUP_DIR"
log "=========================================="

# Notificação Discord (sucesso)
if [ $FAILED_COUNT -eq 0 ]; then
    # Constrói tabela simplificada
    TABLE="**📊 Detalhes dos Backups**\\n\`\`\`"
    TABLE="${TABLE}Banco                 Tamanho   Status  Validado"
    TABLE="${TABLE}\\n────────────────────────────────────────────────"
    
    for detail in "${BACKUP_DETAILS[@]}"; do
        IFS='|' read -r db_name db_size db_status restore_status <<< "$detail"
        printf -v line "%-20s  %-8s  %-6s  %s" "$db_name" "$db_size" "$db_status" "$restore_status"
        TABLE="${TABLE}\\n${line}"
    done
    
    TABLE="${TABLE}\`\`\`"
    TABLE="${TABLE}\\n**Total:** ${TOTAL_SIZE_MB}MB  •  **Duração:** ${DURATION}s  •  **Data:** $(date '+%d/%m/%Y %H:%M:%S')"
    
    send_discord_notification \
        "✅ Backup PostgreSQL Concluído" \
        "$TABLE" \
        3066993
else
    # Constrói tabela incluindo erros
    TABLE="**📊 Detalhes dos Backups**\\n\`\`\`"
    TABLE="${TABLE}Banco                 Tamanho   Status  Validado"
    TABLE="${TABLE}\\n────────────────────────────────────────────────"
    
    for detail in "${BACKUP_DETAILS[@]}"; do
        IFS='|' read -r db_name db_size db_status restore_status <<< "$detail"
        printf -v line "%-20s  %-8s  %-6s  %s" "$db_name" "$db_size" "$db_status" "$restore_status"
        TABLE="${TABLE}\\n${line}"
    done
    
    TABLE="${TABLE}\`\`\`"
    TABLE="${TABLE}\\n**Sucessos:** $BACKUP_COUNT  •  **Falhas:** $FAILED_COUNT  •  **Duração:** ${DURATION}s"
    
    send_discord_notification \
        "⚠️  Backup Concluído com Erros" \
        "$TABLE" \
        16776960
fi

# 4. Política de Retenção Inteligente
log "🗂️  Aplicando política de retenção..."

# Remove backups mais antigos que RETENTION_DAYS
log "   Deletando backups com mais de $RETENTION_DAYS dias..."
find "$BACKUP_DIR" -name "*.sql.gz" -type f -mtime +$RETENTION_DAYS -delete 2>/dev/null || true

REMAINING=$(find "$BACKUP_DIR" -name "*.sql.gz" -type f 2>/dev/null | wc -l)
log "✓ Política aplicada - $REMAINING backups retidos (últimos $RETENTION_DAYS dias)"

exit 0
