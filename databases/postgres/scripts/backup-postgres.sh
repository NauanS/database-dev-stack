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
NETLIFY_AUTH_TOKEN="${NETLIFY_AUTH_TOKEN:-}"
NETLIFY_SITE_ID="${NETLIFY_SITE_ID:-}"
NETLIFY_SITE_URL="${NETLIFY_SITE_URL:-}"
# Troca os nomes dos bancos por db-1, db-2... na cópia publicada do dashboard
DASHBOARD_MASK_DB_NAMES="${DASHBOARD_MASK_DB_NAMES:-true}"

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

append_dashboard_link() {
    local description="$1"
    if [[ -n "$NETLIFY_SITE_URL" && "$NETLIFY_SITE_URL" =~ ^https?:// ]]; then
        printf '%s\\n\\n🌐 Dashboard: %s' "$description" "$NETLIFY_SITE_URL"
    else
        printf "%s" "$description"
    fi
}

# Anonimiza os nomes dos bancos na cópia publicada (o site do Netlify é público)
mask_db_names() {
    local file="$1" idx=0 name escaped
    while IFS= read -r name; do
        [ -z "$name" ] || [ "$name" = "globals" ] && continue
        idx=$((idx + 1))
        escaped=$(printf '%s' "$name" | sed 's/[][\.*^$/]/\\&/g')
        sed -i "s/\"name\": \"${escaped}\"/\"name\": \"db-${idx}\"/g" "$file"
    done < <(grep -o '"name": "[^"]*"' "$file" | sed 's/^"name": "//; s/"$//' | sort -u)
}

# Verifica se o container está rodando
if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    error "Container '$CONTAINER_NAME' não está rodando!"
    send_discord_notification "❌ Backup Falhou" "$(append_dashboard_link "Container '$CONTAINER_NAME' não está rodando!")" 15158332
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

if ( set -o pipefail; docker exec "$CONTAINER_NAME" pg_dumpall -U "$POSTGRES_USER" --globals-only 2>/dev/null | gzip > "$GLOBALS_FILE" ); then
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
    send_discord_notification "⚠️  Backup Concluído com Aviso" "$(append_dashboard_link "Nenhum banco de dados encontrado")" 16776960
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

    # Falha do pg_dump não pode ser mascarada pelo gzip no fim do pipe
    set -o pipefail
    
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
        # Nomes com hífen precisam de aspas como identificador SQL
        TEST_DB_Q="\"${TEST_DB}\""
        
        # Cria banco temporário
        if docker exec "$CONTAINER_NAME" psql -U "$POSTGRES_USER" -c "CREATE DATABASE $TEST_DB_Q;" > /dev/null 2>&1; then
            # Restore completo; ON_ERROR_STOP faz qualquer erro de SQL virar falha (exit != 0)
            if zcat "$BACKUP_FILE" | docker exec -i "$CONTAINER_NAME" psql -U "$POSTGRES_USER" -d "$TEST_DB" -v ON_ERROR_STOP=1 -q > /dev/null 2>&1; then
                # Conta tabelas de todos os schemas de usuário
                TABLE_COUNT=$(docker exec "$CONTAINER_NAME" psql -U "$POSTGRES_USER" -d "$TEST_DB" -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema NOT IN ('pg_catalog', 'information_schema') AND table_type = 'BASE TABLE';" 2>/dev/null | xargs)
                
                if [[ "$TABLE_COUNT" =~ ^[0-9]+$ ]]; then
                    RESTORE_STATUS="✅"
                    if [ "$TABLE_COUNT" -eq 0 ]; then
                        echo "[$(date +"%Y-%m-%d %H:%M:%S")] ✓ Teste de restore OK (banco sem tabelas)"
                    else
                        echo "[$(date +"%Y-%m-%d %H:%M:%S")] ✓ Teste de restore OK ($TABLE_COUNT tabelas)"
                    fi
                else
                    RESTORE_STATUS="⚠️"
                    TABLE_COUNT=0
                    echo "[$(date +"%Y-%m-%d %H:%M:%S")] ⚠️ Restore executou mas não foi possível contar as tabelas"
                fi
            else
                RESTORE_STATUS="❌"
                echo "[$(date +"%Y-%m-%d %H:%M:%S")] ❌ Falha ao restaurar backup em banco de teste"
            fi
            
            # Limpa banco temporário
            docker exec "$CONTAINER_NAME" psql -U "$POSTGRES_USER" -c "DROP DATABASE IF EXISTS $TEST_DB_Q WITH (FORCE);" > /dev/null 2>&1
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
# Um arquivo por execução (AAAA-MM-DD_HH-MM-SS.json): vários backups no mesmo dia não se sobrescrevem
METRICS_FILE="$METRICS_DIR/${DATE_FORMAT//:/-}.json"

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

# 5. Deploy do dashboard no Netlify (não bloqueante)
NETLIFY_DEPLOY_STATUS="ignorado"
NETLIFY_DEPLOY_NOTE="Deploy não configurado"
PUBLISH_DIR="$SCRIPT_DIR/../public"
DASHBOARD_FILE="$SCRIPT_DIR/../dashboard.html"

log "🌐 Preparando deploy do dashboard..."
mkdir -p "$PUBLISH_DIR"

if [ -f "$DASHBOARD_FILE" ]; then
    cp "$DASHBOARD_FILE" "$PUBLISH_DIR/index.html"
    # Remove cópia antiga (antes o mesmo HTML era publicado duas vezes)
    rm -f "$PUBLISH_DIR/dashboard.html"

    if [ "$DASHBOARD_MASK_DB_NAMES" = "true" ]; then
        mask_db_names "$PUBLISH_DIR/index.html"
    fi

    if ! command -v netlify >/dev/null 2>&1; then
        warning "Netlify CLI não encontrada. Instale com: npm install -g netlify-cli"
        NETLIFY_DEPLOY_NOTE="Netlify CLI não encontrada"
    elif [ -z "$NETLIFY_AUTH_TOKEN" ] || [ -z "$NETLIFY_SITE_ID" ]; then
        warning "NETLIFY_AUTH_TOKEN ou NETLIFY_SITE_ID não configurados em scripts/.env"
        NETLIFY_DEPLOY_NOTE="Credenciais Netlify ausentes"
    else
        log "🚀 Publicando dashboard no Netlify (produção)..."
        if netlify deploy \
            --prod \
            --dir="$PUBLISH_DIR" \
            --site="$NETLIFY_SITE_ID" \
            --auth="$NETLIFY_AUTH_TOKEN" >> "$LOG_FILE" 2>&1; then
            NETLIFY_DEPLOY_STATUS="sucesso"
            NETLIFY_DEPLOY_NOTE="Deploy realizado com sucesso"
            log "✅ Deploy Netlify concluído"
        else
            NETLIFY_DEPLOY_STATUS="falha"
            NETLIFY_DEPLOY_NOTE="Falha no deploy do Netlify"
            warning "Falha ao publicar dashboard no Netlify"
        fi
    fi
else
    warning "Dashboard não encontrado para deploy: $DASHBOARD_FILE"
    NETLIFY_DEPLOY_NOTE="Dashboard não encontrado"
fi

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
log "  • Deploy Netlify: $NETLIFY_DEPLOY_STATUS ($NETLIFY_DEPLOY_NOTE)"
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
    TABLE="$(append_dashboard_link "$TABLE")"
    
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
    TABLE="${TABLE}\\n**Deploy Netlify:** ${NETLIFY_DEPLOY_STATUS}"
    TABLE="$(append_dashboard_link "$TABLE")"
    
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
