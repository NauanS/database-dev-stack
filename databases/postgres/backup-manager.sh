#!/bin/bash

#################################################################################
# PostgreSQL Backup Manager
# Menu interativo para gerenciar backups, restore e sync
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

# Banner
show_banner() {
    clear
    echo -e "${CYAN}"
    echo "╔═══════════════════════════════════════════════════════════╗"
    echo "║                                                           ║"
    echo "║        🐘 PostgreSQL Backup Manager 🐘                    ║"
    echo "║                                                           ║"
    echo "║        Gerenciador de Backups e Restauração              ║"
    echo "║                                                           ║"
    echo "╚═══════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# Menu principal
show_menu() {
    echo ""
    echo -e "${BLUE}┌─────────────────────────────────────────────┐${NC}"
    echo -e "${BLUE}│${NC}  ${GREEN}Escolha uma opção:${NC}                        ${BLUE}│${NC}"
    echo -e "${BLUE}├─────────────────────────────────────────────┤${NC}"
    echo -e "${BLUE}│${NC}                                             ${BLUE}│${NC}"
    echo -e "${BLUE}│${NC}  ${CYAN}1)${NC} 💾 Fazer Backup                        ${BLUE}│${NC}"
    echo -e "${BLUE}│${NC}  ${CYAN}2)${NC} 🔄 Restaurar Backup                   ${BLUE}│${NC}"
    echo -e "${BLUE}│${NC}  ${CYAN}3)${NC} ☁️  Sincronizar Google Drive           ${BLUE}│${NC}"
    echo -e "${BLUE}│${NC}                                             ${BLUE}│${NC}"
    echo -e "${BLUE}│${NC}  ${YELLOW}4)${NC} ⚙️  Setup Inicial (primeira vez)      ${BLUE}│${NC}"
    echo -e "${BLUE}│${NC}  ${YELLOW}5)${NC} 🔍 Verificar Ambiente                 ${BLUE}│${NC}"
    echo -e "${BLUE}│${NC}                                             ${BLUE}│${NC}"
    echo -e "${BLUE}│${NC}  ${RED}0)${NC} 🚪 Sair                                ${BLUE}│${NC}"
    echo -e "${BLUE}│${NC}                                             ${BLUE}│${NC}"
    echo -e "${BLUE}└─────────────────────────────────────────────┘${NC}"
    echo ""
}

# Executar backup
run_backup() {
    echo -e "${GREEN}═══════════════════════════════════════════════${NC}"
    echo -e "${GREEN}  💾 Executando Backup...${NC}"
    echo -e "${GREEN}═══════════════════════════════════════════════${NC}"
    echo ""
    
    if [ -f "$SCRIPT_DIR/scripts/backup-postgres.sh" ]; then
        bash "$SCRIPT_DIR/scripts/backup-postgres.sh"
        local exit_code=$?
        echo ""
        if [ $exit_code -eq 0 ]; then
            echo -e "${GREEN}✅ Backup concluído com sucesso!${NC}"
        else
            echo -e "${RED}❌ Erro durante o backup (código: $exit_code)${NC}"
        fi
    else
        echo -e "${RED}❌ Arquivo backup-postgres.sh não encontrado!${NC}"
    fi
    
    pause
}

# Executar restore
run_restore() {
    echo -e "${BLUE}═══════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  🔄 Restaurar Backup${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════${NC}"
    echo ""
    
    if [ -f "$SCRIPT_DIR/scripts/restore-postgres.sh" ]; then
        bash "$SCRIPT_DIR/scripts/restore-postgres.sh"
    else
        echo -e "${RED}❌ Arquivo restore-postgres.sh não encontrado!${NC}"
        pause
    fi
}

# Executar sync
run_sync() {
    echo -e "${CYAN}═══════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  ☁️  Sincronizando com Google Drive...${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════${NC}"
    echo ""
    
    if [ -f "$SCRIPT_DIR/scripts/sync-gdrive.sh" ]; then
        bash "$SCRIPT_DIR/scripts/sync-gdrive.sh"
        local exit_code=$?
        echo ""
        if [ $exit_code -eq 0 ]; then
            echo -e "${GREEN}✅ Sincronização concluída!${NC}"
        else
            echo -e "${RED}❌ Erro durante sincronização (código: $exit_code)${NC}"
        fi
    else
        echo -e "${RED}❌ Arquivo sync-gdrive.sh não encontrado!${NC}"
    fi
    
    pause
}

# Executar setup
run_setup() {
    echo -e "${YELLOW}═══════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}  ⚙️  Setup Inicial${NC}"
    echo -e "${YELLOW}═══════════════════════════════════════════════${NC}"
    echo ""
    
    if [ -f "$SCRIPT_DIR/scripts/setup.sh" ]; then
        bash "$SCRIPT_DIR/scripts/setup.sh"
    else
        echo -e "${RED}❌ Arquivo setup.sh não encontrado!${NC}"
        pause
    fi
}

# Verificar ambiente
check_environment() {
    echo -e "${MAGENTA}═══════════════════════════════════════════════${NC}"
    echo -e "${MAGENTA}  🔍 Verificação de Ambiente${NC}"
    echo -e "${MAGENTA}═══════════════════════════════════════════════${NC}"
    echo ""
    
    # Carregar .env para pegar GDRIVE_REMOTE
    if [ -f "$SCRIPT_DIR/scripts/.env" ]; then
        source "$SCRIPT_DIR/scripts/load-env.sh" 2>/dev/null || true
    fi
    
    # Verificações rápidas
    local errors=0
    local warnings=0
    
    # Docker
    if command -v docker &> /dev/null; then
        echo -e "${GREEN}✓${NC} Docker instalado"
        
        # Container PostgreSQL
        if docker ps --format '{{.Names}}' | grep -q "^postgres$"; then
            echo -e "${GREEN}✓${NC} Container PostgreSQL rodando"
        else
            echo -e "${RED}✗${NC} Container PostgreSQL não encontrado"
            ((errors++))
        fi
    else
        echo -e "${RED}✗${NC} Docker não instalado"
        ((errors++))
    fi
    
    # rclone
    if command -v rclone &> /dev/null; then
        echo -e "${GREEN}✓${NC} rclone instalado"
        
        local remote_name="${GDRIVE_REMOTE:-gdrive-backup}"
        if rclone listremotes | grep -q "^${remote_name}:$"; then
            echo -e "${GREEN}✓${NC} Remote Google Drive configurado ($remote_name)"
        else
            echo -e "${YELLOW}⚠${NC} Remote Google Drive não configurado"
            ((warnings++))
        fi
    else
        echo -e "${YELLOW}⚠${NC} rclone não instalado (opcional para Google Drive)"
        ((warnings++))
    fi
    
    # .env
    if [ -f "$SCRIPT_DIR/scripts/.env" ]; then
        echo -e "${GREEN}✓${NC} Arquivo .env existe"
        
        if grep -q "DISCORD_WEBHOOK_URL_BKP=https://" "$SCRIPT_DIR/scripts/.env" 2>/dev/null; then
            echo -e "${GREEN}✓${NC} Webhook Discord configurado"
        else
            echo -e "${YELLOW}⚠${NC} Webhook Discord não configurado"
            ((warnings++))
        fi
    else
        echo -e "${YELLOW}⚠${NC} Arquivo .env não encontrado"
        ((warnings++))
    fi
    
    # Diretório de backups
    local backup_dir="$SCRIPT_DIR/bkps"
    if [ -d "$backup_dir" ]; then
        echo -e "${GREEN}✓${NC} Diretório de backups existe"
        
        local backup_count=$(find "$backup_dir" -name "*.sql.gz" -type f 2>/dev/null | wc -l)
        echo -e "   ${CYAN}→${NC} $backup_count backup(s) encontrado(s)"
    else
        echo -e "${RED}✗${NC} Diretório de backups não existe"
        ((errors++))
    fi
    
    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════════${NC}"
    
    if [ $errors -eq 0 ] && [ $warnings -eq 0 ]; then
        echo -e "${GREEN}✅ Tudo OK! Sistema pronto para uso.${NC}"
    elif [ $errors -eq 0 ]; then
        echo -e "${YELLOW}⚠️  $warnings aviso(s). Sistema funcional.${NC}"
    else
        echo -e "${RED}❌ $errors erro(s) encontrado(s).${NC}"
        echo -e "   ${YELLOW}Execute a opção 4 (Setup Inicial)${NC}"
    fi
    
    # Pausar apenas se chamado pelo menu (parâmetro $1)
    if [ "$1" = "interactive" ]; then
        pause
    fi
}

# Pausa com Enter
pause() {
    echo ""
    read -p "Pressione ENTER para continuar..." dummy
}

# Loop principal
main() {
    while true; do
        show_banner
        show_menu
        
        read -p "$(echo -e ${CYAN}Opção:${NC}) " choice
        
        case $choice in
            1)
                run_backup
                ;;
            2)
                run_restore
                ;;
            3)
                run_sync
                ;;
            4)
                run_setup
                ;;
            5)
                check_environment "interactive"
                ;;
            0)
                echo ""
                echo -e "${GREEN}👋 Até logo!${NC}"
                echo ""
                exit 0
                ;;
            *)
                echo ""
                echo -e "${RED}❌ Opção inválida!${NC}"
                sleep 1
                ;;
        esac
    done
}

# Modo command-line (sem menu)
if [ $# -gt 0 ]; then
    case "$1" in
        backup|b)
            bash "$SCRIPT_DIR/scripts/backup-postgres.sh"
            ;;
        restore|r)
            bash "$SCRIPT_DIR/scripts/restore-postgres.sh"
            ;;
        sync|s)
            bash "$SCRIPT_DIR/scripts/sync-gdrive.sh"
            ;;
        setup)
            bash "$SCRIPT_DIR/scripts/setup.sh"
            ;;
        check|c)
            check_environment
            ;;
        *)
            echo "Uso: $0 [backup|restore|sync|setup|check]"
            echo ""
            echo "Ou execute sem argumentos para o menu interativo"
            exit 1
            ;;
    esac
else
    # Modo interativo
    main
fi
