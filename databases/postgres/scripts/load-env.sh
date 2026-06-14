#!/bin/bash

# Script helper para carregar variáveis de ambiente do .env
# Use: source load-env.sh

# Detecta diretório do script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/.env"

if [ -f "$ENV_FILE" ]; then
    # Exporta todas as variáveis do .env (ignorando linhas vazias e comentários)
    set -a
    source <(grep -v '^#' "$ENV_FILE" | grep -v '^$' | sed 's/\r$//')
    set +a
    
    echo "✓ Variáveis carregadas de $ENV_FILE"
else
    echo "⚠️  Arquivo .env não encontrado em $SCRIPT_DIR"
    echo "   Copie .env.example para .env e configure suas credenciais"
fi
