# 🐘 Sistema de Backup PostgreSQL

Sistema automatizado de backup, restauração e sincronização para PostgreSQL com notificações Discord e Google Drive.

## 🎯 Funcionalidades

- ✅ **Backup comprimido** - economia de ~44% com gzip
- ✅ **Validação automática** - integridade verificada após cada backup
- ✅ **Dashboard visual** - métricas e gráficos em HTML (Chart.js)
- ✅ **Deploy automático Netlify** - publica dashboard em CDN via CLI
- ✅ **Notificações Discord** - tabelas formatadas com status
- ✅ **Google Drive sync** - backup remoto automático via rclone
- ✅ **Retenção inteligente** - mantém últimos 7 dias
- ✅ **Menu interativo** - interface amigável com backup-manager.sh
- ✅ **Globals backup** - roles e permissões preservados

## 📁 Estrutura

```
databases/postgres/
├── backup-manager.sh           # 🎯 Menu principal (COMECE AQUI!)
├── dashboard.html              # 📊 Dashboard visual de métricas
├── README.md                   # Esta documentação
├── docs/                       # Documentação adicional
│   ├── SETUP.md                # Guia de instalação
│   └── SECURITY.md             # Segurança e GitHub
├── scripts/                    # Scripts de backup
│   ├── setup.sh                # Configuração inicial
│   ├── backup-postgres.sh      # Backup core
│   ├── restore-postgres.sh     # Restauração interativa
│   ├── sync-gdrive.sh          # Sync Google Drive
│   ├── update-dashboard.sh     # Atualiza dashboard com métricas
│   ├── load-env.sh             # Carregador de .env
│   ├── .env                    # Configurações locais (não commitar!)
│   └── .env.example            # Template de configuração
├── public/                     # Artefato publicado no Netlify (index.html)
└── bkps/                       # Backups locais (.sql.gz)
    └── metrics/                # Métricas em JSON (não commitadas)
        └── .gitkeep            # Garante estrutura no git
```

---

## 🚀 Início Rápido

### Primeira vez no PC

```bash
cd databases/postgres
./backup-manager.sh
# Escolher opção 4 (Setup Inicial)
```

**Ou diretamente:**

```bash
cd databases/postgres/scripts
./setup.sh
```

Isso fará:

1. Verificar dependências (Docker, rclone, curl, gzip)
2. Configurar arquivo .env (webhook Discord)
3. Configurar rclone (Google Drive)
4. Configurar cron (backup automático 13h)
5. Testar sistema completo

**Documentação detalhada:** [SETUP.md](docs/SETUP.md)

### Usar o sistema

```bash
cd databases/postgres
./backup-manager.sh
```

**Menu interativo:**

```
╔═════════════════════════════════════════╗
║    🐘 GERENCIADOR DE BACKUP POSTGRESQL  ║
╚═════════════════════════════════════════╝

1) 💾 Executar backup
2) ♻️  Restaurar backup
3) ☁️  Sincronizar com Google Drive
4) ⚙️  Configurar sistema (setup completo)
5) 🔍 Verificar sistema
6) � Dashboard de métricas
7) �🚪 Sair
```

**Ou use linha de comando:**

```bash
./backup-manager.sh backup      # Backup rápido
./backup-manager.sh restore     # Restaurar
./backup-manager.sh sync        # Sync Google Drive
./backup-manager.sh check       # Verificar sistema
./backup-manager.sh metrics     # Ver dashboard de métricas
```

> 💡 **Dica:** O `backup-manager.sh` está na raiz da pasta `postgres/` para fácil acesso!

---

## 💻 Uso dos Scripts

### 1. Backup Manual

```bash
./backup-postgres.sh
```

**O que faz:**

- Backup de roles/permissões globais (globals)
- Backup de todos os bancos de dados
- Compressão gzip automática
- Validação de integridade (zcat)
- Retenção de 7 dias (remove backups antigos)
- Atualiza `dashboard.html` com as métricas do backup
- Publica dashboard no Netlify (modo produção) usando `NETLIFY_AUTH_TOKEN` e `NETLIFY_SITE_ID`
- Notificação Discord com tabela:

```
✅ Backup PostgreSQL Concluído

📊 Detalhes dos Backups
Banco          Tamanho  Status  Validado
─────────────────────────────────────────
dev_database   4.0K     ✓       ✓
globals        4.0K     ✓       ✓

Total: 8.0KB  •  Duração: 1s
```

**Arquivos criados:**

```
bkps/
├── dev_database_2026-03-21_13:00:15.sql.gz
└── globals_2026-03-21_13:00:15.sql.gz
```

### 2. Restaurar Backup

```bash
./restore-postgres.sh
```

**Fluxo interativo:**

1. Lista backups disponíveis (numerados)
2. Você escolhe o número
3. Detecta nome do banco automaticamente
4. Pede confirmação
5. Restaura (descomprime .gz automaticamente)

**Exemplo:**

```bash
Backups disponíveis:
1) dev_database_2026-03-21_13:00:15.sql.gz
2) globals_2026-03-21_13:00:15.sql.gz

Escolha o número: 1
Banco detectado: dev_database
Confirmar restauração? (s/n): s
✅ Restaurado com sucesso!
```

### 3. Sincronizar Google Drive

```bash
./sync-gdrive.sh
```

**O que faz:**

- Upload de todos os `.sql.gz` para Google Drive
- Métricas individuais de tempo e tamanho
- Notificação Discord com tabela:

```
✅ Backup Sincronizado com Google Drive

📊 Detalhes do Upload
Arquivo                         Tamanho  Tempo  Status
──────────────────────────────────────────────────────
dev_database_2026-03-21...      4.0K     2s     ✓
globals_2026-03-21...           4.0K     1s     ✓

Total: 8.0KB  •  Duração: 13s
```

### 4. Verificar Sistema

```bash
./backup-manager.sh check
```

**Verifica:**

- ✓ Docker instalado
- ✓ Container PostgreSQL rodando
- ✓ rclone instalado e configurado
- ✓ Remote Google Drive funcional
- ✓ Arquivo .env existe
- ✓ Webhook Discord configurado
- ✓ Diretório de backups criado

### 5. Dashboard de Métricas

```bash
./backup-manager.sh metrics
# ou
xdg-open dashboard.html
```

**O que mostra:**

📊 **Estatísticas Gerais:**

- Total de backups executados
- Taxa de sucesso (%)
- Tamanho total dos backups
- Tempo médio de execução

📈 **Gráficos:**

- Evolução do tamanho dos backups (últimos 30 dias)
- Tempo de execução por backup

📋 **Tabelas:**

- Detalhes por banco de dados (tamanho, tabelas, status de validação)
- Histórico completo de backups

**Como funciona:**

1. Cada backup gera um arquivo JSON em `bkps/metrics/YYYY-MM-DD.json`
2. O script `update-dashboard.sh` atualiza o `dashboard.html` com os dados
3. O dashboard é um arquivo HTML estático - abre direto no navegador!

**Atualizar manualmente:**

```bash
./scripts/update-dashboard.sh
```

**Métricas salvas:**

```json
{
  "date": "2026-03-21",
  "summary": {
    "total_backups": 1,
    "success_rate": 100.0,
    "total_size_mb": 0.001,
    "duration_seconds": 1
  },
  "databases": [
    {
      "name": "dev_database",
      "size_mb": 0.001,
      "tables_count": 2,
      "validation": { "passed": true }
    }
  ]
}
```

> 💡 **Dica:** Edite os JSONs em `bkps/metrics/` e rode `update-dashboard.sh` para testar visualizações!

### 6. Deploy do Dashboard no Netlify

O deploy é executado automaticamente no final de `./backup-postgres.sh`.

Fluxo:

1. Gera/atualiza `dashboard.html` com métricas recentes
2. Copia para `public/index.html` e `public/dashboard.html`
3. Executa `netlify deploy --prod --dir=public` em modo não interativo

Pré-requisitos:

- Netlify CLI instalada (`npm install -g netlify-cli`)
- Variáveis configuradas em `scripts/.env`:

```bash
NETLIFY_AUTH_TOKEN=seu_token_netlify
NETLIFY_SITE_ID=seu_site_id
NETLIFY_SITE_URL=https://seu-site.netlify.app
```

Comportamento em falha:

- Falha de deploy **não interrompe** o backup
- Status do deploy aparece no log e no resumo final

---

## ⏰ Automação

O setup já configura cron automático:

**Backup diário:** 13:00  
**Sync Google Drive:** 13:30

### Ver cron configurado

```bash
crontab -l | grep -A 2 "Backup PostgreSQL"
```

### Modificar horário

```bash
crontab -e
```

**Formatos:**

- `0 13 * * *` - 13:00 diariamente (atual)
- `0 */6 * * *` - A cada 6 horas
- `0 2 * * 0` - Domingos às 02:00
- `30 3 * * 1-5` - Segunda a sexta às 03:30

### Desabilitar automação

```bash
crontab -e
# Comentar as linhas com #
```

---

## ⚙️ Configuração

As configurações ficam em `scripts/.env`:

```bash
# Discord
DISCORD_WEBHOOK_URL_BKP=https://discord.com/api/webhooks/...

# PostgreSQL
POSTGRES_USER=postgres
CONTAINER_NAME=postgres

# Backup
BACKUP_DIR=../bkps
RETENTION_DAYS=7

# Google Drive
GDRIVE_REMOTE=gdrive-ns17
GDRIVE_PATH=bkps

# Netlify (dashboard CDN)
NETLIFY_AUTH_TOKEN=
NETLIFY_SITE_ID=
NETLIFY_SITE_URL=
```

**Editar:**

```bash
nano scripts/.env
```

**⚠️ Nunca commite o arquivo `.env` (contém webhook Discord)!**

---

## 🔧 Troubleshooting

### Container não encontrado

```bash
docker ps | grep postgres
docker compose up -d postgres
```

### Webhook Discord não funciona

```bash
# Testar manualmente
curl -X POST "$DISCORD_WEBHOOK_URL_BKP" \
  -H "Content-Type: application/json" \
  -d '{"content": "Teste"}'
```

### Deploy Netlify não acontece

```bash
# Verificar CLI
netlify --version

# Verificar variáveis
grep -E "NETLIFY_AUTH_TOKEN|NETLIFY_SITE_ID|NETLIFY_SITE_URL" scripts/.env
```

Se `NETLIFY_SITE_URL` estiver configurada, os alertas de erro no Discord incluem o link público do dashboard.

### rclone não autorizado

```bash
rclone config reconnect gdrive-ns17:
# Autorize no navegador novamente
```

### Permissões negadas

```bash
chmod +x scripts/*.sh
```

### Ver logs

```bash
cat bkps/backup.log
cat bkps/sync.log
```

### Espaço dos backups

```bash
du -sh bkps/
ls -lh bkps/*.sql.gz
```

---

## 📊 Logs e Monitoramento

**Logs:**

- `bkps/backup.log` - Log de backups
- `bkps/sync.log` - Log de sincronizações

**Métricas:**

- `bkps/metrics/*.json` - Métricas em JSON por data (YYYY-MM-DD.json)
- `dashboard.html` - Visualização interativa das métricas

**Listar backups:**

```bash
ls -lh bkps/*.sql.gz
```

**Ver métricas:**

```bash
cat bkps/metrics/$(date +%Y-%m-%d).json
# ou
./backup-manager.sh metrics  # Dashboard visual
```

**Espaço usado:**

```bash
du -sh bkps/
```

**Verificar no Google Drive:**

```bash
rclone ls gdrive-ns17:bkps
```

---

## 🔒 Segurança

**Arquivos locais não commitados:**

- `scripts/.env` - Webhook Discord e configurações
- `bkps/*.sql.gz` - Backups dos bancos
- `bkps/metrics/*.json` - Métricas de backup (geradas automaticamente)
- `*.log` - Logs do sistema

**Template público:**

- `scripts/.env.example` - Pode commitar (sem dados reais)

**Guia completo:** [SECURITY.md](docs/SECURITY.md)

---

## 📚 Documentação Adicional

- **[SETUP.md](docs/SETUP.md)** - Guia completo de instalação e configuração inicial
- **[SECURITY.md](docs/SECURITY.md)** - Segurança e preparação para GitHub

---

**Sistema testado e validado em:** 21/03/2026
