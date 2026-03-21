#!/bin/bash

# Script para atualizar dashboard.html com dados das métricas JSON
# Lê todos os arquivos JSON de métricas e embute no HTML

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="$SCRIPT_DIR/../bkps"
METRICS_DIR="$BACKUP_DIR/metrics"
DASHBOARD_FILE="$SCRIPT_DIR/../dashboard.html"

# Cores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Verifica se dashboard existe
if [ ! -f "$DASHBOARD_FILE" ]; then
    echo -e "${RED}❌ Dashboard não encontrado: $DASHBOARD_FILE${NC}"
    exit 1
fi

# Verifica se há métricas
if [ ! -d "$METRICS_DIR" ] || [ -z "$(ls -A $METRICS_DIR/*.json 2>/dev/null)" ]; then
    echo -e "${YELLOW}⚠️  Nenhuma métrica encontrada em: $METRICS_DIR${NC}"
    exit 0
fi

# Coleta últimos 30 dias de métricas em ordem cronológica inversa (mais recente primeiro)
json_data="["
first=true

for json_file in $(ls -t "$METRICS_DIR"/*.json 2>/dev/null | head -30); do
    if [ -f "$json_file" ]; then
        if [ "$first" = false ]; then
            json_data+=","
        fi
        json_data+=$(cat "$json_file")
        first=false
    fi
done

json_data+="]"

# Cria arquivo temporário
temp_file=$(mktemp)

# Substitui dados no HTML entre os marcadores @@METRICS_DATA_START@@ e @@METRICS_DATA_END@@
awk -v data="$json_data" '
BEGIN { skip=0 }
/@@METRICS_DATA_START@@/ {
    print
    print "      const metricsData = " data ";"
    skip=1
    next
}
/@@METRICS_DATA_END@@/ {
    skip=0
    print
    next
}
!skip
' "$DASHBOARD_FILE" > "$temp_file"

# Substitui arquivo original
if [ -s "$temp_file" ]; then
    mv "$temp_file" "$DASHBOARD_FILE"
    echo -e "${GREEN}✅ Dashboard atualizado: $DASHBOARD_FILE${NC}"
    
    # Conta quantos dias de métricas foram incluídos
    metric_count=$(ls -1 "$METRICS_DIR"/*.json 2>/dev/null | wc -l)
    echo -e "${GREEN}   Métricas carregadas: $metric_count arquivo(s)${NC}"
else
    echo -e "${RED}❌ Erro ao atualizar dashboard${NC}"
    rm -f "$temp_file"
    exit 1
fi
