#!/bin/bash

# Script de Sincronização com Google Drive
# Usa rclone para enviar backups para Google Drive

set -e

# Carregar variáveis de ambiente
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/.env" ]; then
    source "$SCRIPT_DIR/load-env.sh"
fi

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configurações (com valores padrão se não definidos no .env)
BACKUP_DIR="${BACKUP_DIR:-$SCRIPT_DIR/../bkps}"
GDRIVE_REMOTE="${GDRIVE_REMOTE:-gdrive-backup}"
GDRIVE_PATH="${GDRIVE_PATH:-bkps}"
LOG_FILE="$BACKUP_DIR/sync.log"

# Garante que o diretório de logs exista antes do primeiro tee
mkdir -p "$BACKUP_DIR"

# Discord Webhook (variável de ambiente)
DISCORD_WEBHOOK="${DISCORD_WEBHOOK_URL_BKP:-}"
NETLIFY_SITE_URL="${NETLIFY_SITE_URL:-}"

log() {
    echo -e "${GREEN}[$(date +"%Y-%m-%d %H:%M:%S")]${NC} $1" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[$(date +"%Y-%m-%d %H:%M:%S")] ERRO:${NC} $1" | tee -a "$LOG_FILE"
}

info() {
    echo -e "${BLUE}[$(date +"%Y-%m-%d %H:%M:%S")]${NC} $1" | tee -a "$LOG_FILE"
}

send_discord_notification() {
    local title="$1"
    local description="$2"
    local color="$3"
    
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
      "text": "Google Drive Sync - $(hostname)"
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
        printf "%s\\n\\n🌐 Dashboard: %s" "$description" "$NETLIFY_SITE_URL"
    else
        printf "%s" "$description"
    fi
}

# Verifica se rclone está instalado
if ! command -v rclone &> /dev/null; then
    error "rclone não está instalado!"
    echo ""
    echo -e "${YELLOW}Para instalar o rclone:${NC}"
    echo "  curl https://rclone.org/install.sh | sudo bash"
    echo ""
    echo -e "${YELLOW}Após instalar, configure o Google Drive:${NC}"
    echo "  rclone config"
    echo "  - Escolha 'n' para novo remote"
    echo "  - Nome: gdrive"
    echo "  - Storage: Google Drive (opção 18)"
    echo "  - Siga as instruções de autenticação"
    echo ""
    send_discord_notification "❌ Sync Falhou" "$(append_dashboard_link "rclone não instalado no servidor")" 15158332
    exit 1
fi

# Verifica se o remote está configurado
if ! rclone listremotes | grep -q "^${GDRIVE_REMOTE}:$"; then
    error "Remote '$GDRIVE_REMOTE' não configurado no rclone!"
    echo ""
    echo -e "${YELLOW}Configure o Google Drive:${NC}"
    echo "  rclone config"
    echo ""
    send_discord_notification "❌ Sync Falhou" "$(append_dashboard_link "Remote Google Drive não configurado")" 15158332
    exit 1
fi

log "=========================================="
log "Iniciando sincronização com Google Drive..."
log "=========================================="

START_TIME=$(date +%s)

# Array para armazenar detalhes dos uploads
declare -a UPLOAD_DETAILS

# Conta arquivos para sincronizar
FILE_COUNT=$(find "$BACKUP_DIR" -name "*.sql.gz" -type f | wc -l)

if [ "$FILE_COUNT" -eq 0 ]; then
    info "Nenhum arquivo para sincronizar"
    exit 0
fi

log "📤 Arquivos para sincronizar: $FILE_COUNT"

# Sincroniza arquivo por arquivo para capturar detalhes
UPLOAD_SUCCESS=0
UPLOAD_FAILED=0
TOTAL_SIZE=0

while IFS= read -r file; do
    filename=$(basename "$file")
    filesize=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null)
    TOTAL_SIZE=$((TOTAL_SIZE + filesize))
    
    # Formata tamanho
    if [ $filesize -lt 1024 ]; then
        size_display="${filesize}B"
    elif [ $filesize -lt 1048576 ]; then
        size_display="$((filesize / 1024))KB"
    else
        size_display="$((filesize / 1048576))MB"
    fi
    
    log "📤 Enviando '$filename'..."
    
    # Marca tempo de upload
    upload_start=$(date +%s)
    
    if rclone copy "$file" "${GDRIVE_REMOTE}:${GDRIVE_PATH}" --progress 2>&1 | grep -v "Transferred:" | grep -v "Elapsed time:" ; then
        upload_end=$(date +%s)
        upload_time=$((upload_end - upload_start))
        
        log "✓ Upload de '$filename' concluído: ${size_display} em ${upload_time}s"
        UPLOAD_SUCCESS=$((UPLOAD_SUCCESS + 1))
        UPLOAD_DETAILS+=("${filename}|${size_display}|${upload_time}s|✓")
    else
        log "✗ Falha no upload de '$filename'"
        UPLOAD_FAILED=$((UPLOAD_FAILED + 1))
        UPLOAD_DETAILS+=("${filename}|${size_display}|0s|✗")
    fi
done < <(find "$BACKUP_DIR" -name "*.sql.gz" -type f)

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))
TOTAL_SIZE_MB=$((TOTAL_SIZE / 1024 / 1024))

log "=========================================="
log "✅ Sincronização concluída!"
log "=========================================="
log "  • Arquivos enviados: $UPLOAD_SUCCESS"
[ $UPLOAD_FAILED -gt 0 ] && log "  • Falhas: $UPLOAD_FAILED"
log "  • Tamanho total: ${TOTAL_SIZE_MB}MB"
log "  • Duração: ${DURATION}s"
log "=========================================="

# Notificação Discord
if [ $UPLOAD_FAILED -eq 0 ]; then
    # Constrói tabela simplificada
    TABLE="**📊 Detalhes do Upload**\\n\`\`\`"
    TABLE="${TABLE}Arquivo                              Tamanho  Tempo  Status"
    TABLE="${TABLE}\\n───────────────────────────────────────────────────────────"
    
    for detail in "${UPLOAD_DETAILS[@]}"; do
        IFS='|' read -r filename filesize upload_time status <<< "$detail"
        
        # Trunca nome se muito longo
        if [ ${#filename} -gt 36 ]; then
            short_name="${filename:0:33}..."
        else
            short_name="$filename"
        fi
        
        printf -v line "%-36s  %-7s  %-5s  %s" "$short_name" "$filesize" "$upload_time" "$status"
        TABLE="${TABLE}\\n${line}"
    done
    
    TABLE="${TABLE}\`\`\`"
    TABLE="${TABLE}\\n**Total:** ${TOTAL_SIZE_MB}MB  •  **Duração:** ${DURATION}s  •  **Data:** $(date '+%d/%m/%Y %H:%M:%S')"
    
    send_discord_notification \
        "✅ Backup Sincronizado com Google Drive" \
        "$TABLE" \
        3066993
else
    # Constrói tabela incluindo erros
    TABLE="**📊 Detalhes do Upload**\\n\`\`\`"
    TABLE="${TABLE}Arquivo                              Tamanho  Tempo  Status"
    TABLE="${TABLE}\\n───────────────────────────────────────────────────────────"
    
    for detail in "${UPLOAD_DETAILS[@]}"; do
        IFS='|' read -r filename filesize upload_time status <<< "$detail"
        
        # Trunca nome se muito longo
        if [ ${#filename} -gt 36 ]; then
            short_name="${filename:0:33}..."
        else
            short_name="$filename"
        fi
        
        printf -v line "%-36s  %-7s  %-5s  %s" "$short_name" "$filesize" "$upload_time" "$status"
        TABLE="${TABLE}\\n${line}"
    done
    
    TABLE="${TABLE}\`\`\`"
    TABLE="${TABLE}\\n**Sucessos:** $UPLOAD_SUCCESS  •  **Falhas:** $UPLOAD_FAILED  •  **Duração:** ${DURATION}s"
    TABLE="$(append_dashboard_link "$TABLE")"
    
    send_discord_notification \
        "⚠️  Sincronização Concluída com Erros" \
        "$TABLE" \
        16776960
fi

exit 0
