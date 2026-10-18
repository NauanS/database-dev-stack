#!/bin/bash

#################################################################################
# Setup Completo - PostgreSQL Backup System
# Configura todo o ambiente: rclone, cron, .env, verificações
#################################################################################

set -e

# Detectar diretório do script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Configurações
REMOTE_NAME="gdrive-backup"
GDRIVE_FOLDER="bkps"
BACKUP_HOUR="13"
BACKUP_MINUTE="00"
SYNC_HOUR="13"
SYNC_MINUTE="30"

# Contadores
ERRORS=0
WARNINGS=0

# Banner
banner() {
    clear
    echo -e "${CYAN}"
    echo "╔═══════════════════════════════════════════════════════════╗"
    echo "║                                                           ║"
    echo "║        🚀 Setup Completo - Backup PostgreSQL 🚀           ║"
    echo "║                                                           ║"
    echo "║     Configuração automática de todo o ambiente           ║"
    echo "║                                                           ║"
    echo "╚═══════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
}

# Funções de log
info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

success() {
    echo -e "${GREEN}[OK]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[AVISO]${NC} $1"
    ((WARNINGS++))
}

error() {
    echo -e "${RED}[ERRO]${NC} $1"
    ((ERRORS++))
}

step() {
    echo ""
    echo -e "${MAGENTA}═══════════════════════════════════════════════════════${NC}"
    echo -e "${MAGENTA}  $1${NC}"
    echo -e "${MAGENTA}═══════════════════════════════════════════════════════${NC}"
    echo ""
}

# 1. Verificar dependências
check_dependencies() {
    step "1️⃣  Verificando Dependências"
    
    # Docker
    if command -v docker &> /dev/null; then
        success "Docker instalado: $(docker --version | head -1)"
    else
        error "Docker NÃO instalado"
        info "Instale: curl -fsSL https://get.docker.com | sh"
        return 1
    fi
    
    # Container PostgreSQL
    if docker ps --format '{{.Names}}' | grep -q "^postgres$"; then
        success "Container PostgreSQL rodando"
    else
        error "Container PostgreSQL não encontrado"
        info "Inicie: docker-compose up -d postgres"
        return 1
    fi
    
    # Ferramentas básicas
    for cmd in grep sed find curl; do
        if command -v $cmd &> /dev/null; then
            success "$cmd disponível"
        else
            error "$cmd NÃO instalado"
        fi
    done
    
    return 0
}

# 2. Configurar .env
setup_env() {
    step "2️⃣  Configurando Arquivo .env"
    
    if [ -f "$SCRIPT_DIR/.env" ]; then
        info "Arquivo .env já existe"
        
        # Verificar se webhook está configurado
        if grep -q "DISCORD_WEBHOOK_URL_BKP=https://" "$SCRIPT_DIR/.env" 2>/dev/null; then
            success "Webhook Discord já configurado"
        else
            warning "Webhook Discord não configurado no .env"
            echo ""
            read -p "Deseja configurar o webhook agora? (s/N): " configure_webhook
            if [[ "$configure_webhook" =~ ^[Ss]$ ]]; then
                echo ""
                echo "Cole o webhook URL do Discord:"
                read -r webhook_url
                
                if [ -n "$webhook_url" ]; then
                    sed -i "s|DISCORD_WEBHOOK_URL_BKP=.*|DISCORD_WEBHOOK_URL_BKP=$webhook_url|" "$SCRIPT_DIR/.env"
                    success "Webhook configurado!"
                fi
            fi
        fi
    else
        info "Criando .env a partir do .env.example..."
        
        if [ -f "$SCRIPT_DIR/.env.example" ]; then
            cp "$SCRIPT_DIR/.env.example" "$SCRIPT_DIR/.env"
            success "Arquivo .env criado!"
            
            echo ""
            warning "Configure o webhook Discord no arquivo .env"
            echo "  Caminho: $SCRIPT_DIR/.env"
            echo "  Obter webhook: Discord > Server Settings > Integrations > Webhooks"
        else
            error ".env.example não encontrado!"
            return 1
        fi
    fi
    
    return 0
}

# 3. Instalar e configurar rclone
setup_rclone() {
    step "3️⃣  Configurando rclone (Google Drive)"
    
    # Verificar se rclone está instalado
    if command -v rclone &> /dev/null; then
        success "rclone já instalado: $(rclone --version | head -1)"
    else
        info "Instalando rclone..."
        
        if curl https://rclone.org/install.sh | sudo bash; then
            success "rclone instalado com sucesso!"
        else
            error "Falha ao instalar rclone"
            return 1
        fi
    fi
    
    # Verificar se remote já existe
    if rclone listremotes | grep -q "^${REMOTE_NAME}:$"; then
        success "Remote '$REMOTE_NAME' já configurado"
        
        # Testar conexão
        if rclone lsd "${REMOTE_NAME}:" &> /dev/null; then
            success "Conexão com Google Drive OK"
        else
            warning "OAuth pode ter expirado"
            echo ""
            read -p "Deseja reconectar? (s/N): " reconnect
            if [[ "$reconnect" =~ ^[Ss]$ ]]; then
                rclone config reconnect "${REMOTE_NAME}:"
            fi
        fi
    else
        info "Configurando Google Drive..."
        echo ""
        echo -e "${YELLOW}Siga as instruções para autenticar no Google Drive:${NC}"
        echo ""
        
        rclone config create "$REMOTE_NAME" drive \
            scope drive.file \
            config_is_local false
        
        if [ $? -eq 0 ]; then
            success "Remote '$REMOTE_NAME' configurado!"
        else
            error "Falha ao configurar remote"
            return 1
        fi
    fi
    
    # Criar pasta no Drive
    info "Verificando pasta '$GDRIVE_FOLDER' no Google Drive..."
    
    if rclone lsd "${REMOTE_NAME}:" | grep -q "$GDRIVE_FOLDER"; then
        success "Pasta '$GDRIVE_FOLDER' já existe"
    else
        info "Criando pasta '$GDRIVE_FOLDER'..."
        rclone mkdir "${REMOTE_NAME}:${GDRIVE_FOLDER}"
        success "Pasta '$GDRIVE_FOLDER' criada!"
    fi
    
    # Atualizar variável no .env
    if [ -f "$SCRIPT_DIR/.env" ]; then
        if grep -q "GDRIVE_REMOTE=" "$SCRIPT_DIR/.env"; then
            sed -i "s|GDRIVE_REMOTE=.*|GDRIVE_REMOTE=$REMOTE_NAME|" "$SCRIPT_DIR/.env"
            success "Variável GDRIVE_REMOTE atualizada no .env"
        fi
    fi
    
    return 0
}

# 4. Configurar cron
setup_cron() {
    step "4️⃣  Configurando Agendamento (Cron)"
    
    # Verificar se cron está disponível
    if ! command -v crontab &> /dev/null; then
        error "crontab não disponível"
        info "Instale: sudo apt install cron"
        return 1
    fi
    
    # Caminho absoluto do script
    local backup_script="$SCRIPT_DIR/backup-postgres.sh"
    local sync_script="$SCRIPT_DIR/sync-gdrive.sh"
    
    # Verificar se já existe no cron
    if crontab -l 2>/dev/null | grep -q "backup-postgres.sh"; then
        warning "Agendamento de backup já existe no cron"
        echo ""
        read -p "Deseja reconfigurar? (s/N): " reconfigure
        if [[ ! "$reconfigure" =~ ^[Ss]$ ]]; then
            return 0
        fi
    fi
    
    info "Configurando horários de backup..."
    echo "  Backup: ${BACKUP_HOUR}:${BACKUP_MINUTE} (diariamente)"
    echo "  Sync:   ${SYNC_HOUR}:${SYNC_MINUTE} (diariamente)"
    echo ""
    
    # Criar arquivo temporário com cron jobs
    local temp_cron=$(mktemp)
    crontab -l 2>/dev/null | grep -v "backup-postgres.sh" | grep -v "sync-gdrive.sh" > "$temp_cron" || true
    
    # Adicionar novos jobs
    echo "# PostgreSQL Backup Automático" >> "$temp_cron"
    # Os scripts já gravam em bkps/backup.log e bkps/sync.log; redirecionar de novo duplicaria as linhas
    echo "$BACKUP_MINUTE $BACKUP_HOUR * * * cd $SCRIPT_DIR && bash $backup_script > /dev/null 2>&1" >> "$temp_cron"
    echo "" >> "$temp_cron"
    echo "# Sincronização Google Drive" >> "$temp_cron"
    echo "$SYNC_MINUTE $SYNC_HOUR * * * cd $SCRIPT_DIR && bash $sync_script > /dev/null 2>&1" >> "$temp_cron"
    
    # Instalar no cron
    if crontab "$temp_cron"; then
        rm "$temp_cron"
        success "Agendamento configurado!"
        echo "  Backup: ${BACKUP_HOUR}:${BACKUP_MINUTE} diariamente"
        echo "  Sync:   ${SYNC_HOUR}:${SYNC_MINUTE} diariamente"
    else
        rm "$temp_cron"
        error "Falha ao configurar cron"
        return 1
    fi
    
    return 0
}

# 5. Verificar segurança
check_security() {
    step "5️⃣  Verificação de Segurança"
    
    local security_errors=0
    
    # Verificar .env no .gitignore
    if git check-ignore "$SCRIPT_DIR/.env" &> /dev/null; then
        success ".env está no .gitignore"
    else
        error ".env NÃO está no .gitignore!"
        ((security_errors++))
    fi
    
    # Verificar webhooks em arquivos públicos
    if grep -r "discord.com/api/webhooks/[0-9]" "$SCRIPT_DIR/../" \
        --exclude="*.env" \
        --exclude=".env.example" \
        --exclude="*.log" 2>/dev/null | grep -v "setup.sh:" > /dev/null; then
        error "Webhooks encontrados em arquivos públicos!"
        ((security_errors++))
    else
        success "Nenhum webhook exposto em arquivos públicos"
    fi
    
    # Verificar backups no git
    if git ls-files "$SCRIPT_DIR/../bkps/" 2>/dev/null | grep -q "\.sql"; then
        error "Backups .sql sendo trackeados no git!"
        ((security_errors++))
    else
        success "Backups não estão sendo trackeados pelo git"
    fi
    
    if [ $security_errors -eq 0 ]; then
        success "Verificação de segurança OK!"
    else
        error "Encontrados $security_errors problema(s) de segurança"
    fi
    
    return $security_errors
}

# 6. Teste final
final_test() {
    step "6️⃣  Teste Final do Sistema"
    
    info "Testando backup..."
    if bash "$SCRIPT_DIR/backup-postgres.sh"; then
        success "Teste de backup OK!"
    else
        error "Teste de backup FALHOU"
        return 1
    fi
    
    # Verificar se arquivos foram criados
    local backup_count=$(find "$SCRIPT_DIR/../bkps" -name "*.sql.gz" -type f -mmin -5 2>/dev/null | wc -l)
    
    if [ $backup_count -gt 0 ]; then
        success "Encontrados $backup_count backup(s) recém-criado(s)"
    else
        warning "Nenhum backup novo encontrado"
    fi
    
    # Teste de sync (se rclone configurado)
    if command -v rclone &> /dev/null && rclone listremotes | grep -q "${REMOTE_NAME}:"; then
        echo ""
        read -p "Deseja testar sincronização com Google Drive? (s/N): " test_sync
        if [[ "$test_sync" =~ ^[Ss]$ ]]; then
            info "Testando sync com Google Drive..."
            if bash "$SCRIPT_DIR/sync-gdrive.sh"; then
                success "Teste de sync OK!"
            else
                error "Teste de sync FALHOU"
            fi
        fi
    fi
    
    return 0
}

# Resumo final
show_summary() {
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  📊 RESUMO DA CONFIGURAÇÃO${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
    echo ""
    
    if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
        echo -e "${GREEN}✅ Setup concluído com SUCESSO!${NC}"
        echo ""
        echo "Sistema pronto para uso!"
        echo ""
        echo "Próximos passos:"
        echo "  1. Os backups rodarão automaticamente às ${BACKUP_HOUR}:${BACKUP_MINUTE}"
        echo "  2. O sync com Google Drive às ${SYNC_HOUR}:${SYNC_MINUTE}"
        echo "  3. Use './backup-manager.sh' para gerenciar backups"
    elif [ $ERRORS -eq 0 ]; then
        echo -e "${YELLOW}⚠️  Setup concluído com $WARNINGS aviso(s)${NC}"
        echo ""
        echo "Sistema funcional, mas revise os avisos acima."
    else
        echo -e "${RED}❌ Setup concluído com $ERRORS erro(s)${NC}"
        if [ $WARNINGS -gt 0 ]; then
            echo -e "${YELLOW}   E $WARNINGS aviso(s)${NC}"
        fi
        echo ""
        echo "Corrija os erros e execute novamente."
    fi
    
    echo ""
}

# Main
main() {
    banner
    
    info "Iniciando setup completo..."
    echo ""
    
    # Executar etapas
    check_dependencies || true
    setup_env || true
    setup_rclone || true
    setup_cron || true
    check_security || true
    final_test || true
    
    # Mostrar resumo
    show_summary
    
    echo ""
    read -p "Pressione ENTER para continuar..." dummy
}

main
