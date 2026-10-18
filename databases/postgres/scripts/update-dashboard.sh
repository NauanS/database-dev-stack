#!/bin/bash

# Gera dashboard.html a partir do dashboard.template.html (versionado) e das
# métricas JSON (bkps/metrics). O dashboard.html gerado NÃO é versionado.
# Embute os últimos 30 registros em ordem cronológica (mais antigo primeiro).

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="$SCRIPT_DIR/../bkps"
METRICS_DIR="$BACKUP_DIR/metrics"
TEMPLATE_FILE="$SCRIPT_DIR/../dashboard.template.html"
DASHBOARD_FILE="$SCRIPT_DIR/../dashboard.html"

# Cores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Verifica se o template existe
if [ ! -f "$TEMPLATE_FILE" ]; then
    echo -e "${RED}❌ Template não encontrado: $TEMPLATE_FILE${NC}"
    exit 1
fi

# Verifica se há métricas
if ! compgen -G "$METRICS_DIR/*.json" > /dev/null; then
    echo -e "${YELLOW}⚠️  Nenhuma métrica encontrada em: $METRICS_DIR${NC}"
    exit 0
fi

# Últimos 30 registros; os nomes (AAAA-MM-DD[_HH-MM-SS].json) ordenam cronologicamente
json_data="["
first=true

while IFS= read -r json_file; do
    if [ "$first" = false ]; then
        json_data+=","
    fi
    json_data+=$(cat "$json_file")
    first=false
done < <(find "$METRICS_DIR" -maxdepth 1 -name '*.json' -type f | sort | tail -30)

json_data+="]"

# Cria arquivo temporário
temp_file=$(mktemp)

# Substitui dados no HTML entre os marcadores @@METRICS_DATA_START@@ e @@METRICS_DATA_END@@
# (ENVIRON evita que o awk interprete sequências de escape do JSON)
METRICS_JSON="$json_data" awk '
BEGIN { skip=0 }
/@@METRICS_DATA_START@@/ {
    print
    print "      const metricsData = " ENVIRON["METRICS_JSON"] ";"
    skip=1
    next
}
/@@METRICS_DATA_END@@/ {
    skip=0
    print
    next
}
!skip
' "$TEMPLATE_FILE" > "$temp_file"

if [ -s "$temp_file" ]; then
    mv "$temp_file" "$DASHBOARD_FILE"
    chmod 644 "$DASHBOARD_FILE"
    echo -e "${GREEN}✅ Dashboard gerado: $DASHBOARD_FILE${NC}"

    metric_count=$(find "$METRICS_DIR" -maxdepth 1 -name '*.json' -type f | wc -l)
    echo -e "${GREEN}   Métricas carregadas: $metric_count arquivo(s) (últimos 30 embutidos)${NC}"
else
    echo -e "${RED}❌ Erro ao gerar dashboard${NC}"
    rm -f "$temp_file"
    exit 1
fi
