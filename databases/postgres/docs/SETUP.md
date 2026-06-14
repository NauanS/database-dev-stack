# 🐘 Guia de Instalação - Sistema de Backup PostgreSQL

Guia passo a passo para configurar o sistema pela primeira vez.

---

## 📋 Pré-requisitos

### Verificar dependências

```bash
docker --version    # Precisa estar instalado
docker ps          # Container PostgreSQL rodando
curl --version     # Já vem na maioria dos sistemas
gzip --version     # Já vem na maioria dos sistemas
netlify --version  # Netlify CLI para deploy do dashboard
```

Se algo faltar:

```bash
# Ubuntu/Debian
sudo apt install docker.io curl gzip

# macOS
brew install docker curl

# Netlify CLI (npm)
npm install -g netlify-cli
```

---

## 🚀 Instalação Automática (Recomendado)

**Execute o setup completo:**

```bash
cd databases/postgres/scripts
./setup.sh
```

Este script irá:

1. ✓ Verificar todas as dependências
2. ✓ Configurar arquivo .env (webhook Discord)
3. ✓ Instalar e configurar rclone (Google Drive)
4. ✓ Configurar cron (backup automático 13h)
5. ✓ Verificar segurança (dados sensíveis)
6. ✓ Testar sistema completo

**Siga as instruções na tela e pronto!**

---

## 🔧 Instalação Manual (Passo a Passo)

Se preferir fazer cada etapa manualmente:

### 1. Configurar Webhook Discord

**Criar webhook:**

1. Discord → Servidor → Configurações do Canal
2. Integrações → Webhooks → Criar Webhook
3. Copiar URL do Webhook

**Criar arquivo .env:**

```bash
cd databases/postgres/scripts
nano .env
```

**Adicionar:**

```bash
DISCORD_WEBHOOK_URL_BKP=https://discord.com/api/webhooks/SEU_WEBHOOK_AQUI
POSTGRES_USER=postgres
CONTAINER_NAME=postgres
BACKUP_DIR=../bkps
RETENTION_DAYS=7
GDRIVE_REMOTE=gdrive-backup
GDRIVE_PATH=bkps
NETLIFY_AUTH_TOKEN=SEU_TOKEN_NETLIFY
NETLIFY_SITE_ID=SEU_SITE_ID
NETLIFY_SITE_URL=https://seu-site.netlify.app
```

**Salvar:** Ctrl+O, Enter, Ctrl+X

### 2. Instalar rclone

**Ubuntu/Debian:**

```bash
sudo apt install rclone
```

**macOS:**

```bash
brew install rclone
```

**Ou instalador oficial:**

```bash
curl https://rclone.org/install.sh | sudo bash
```

### 3. Configurar Google Drive

```bash
rclone config
```

**Passos:**

- **n** (New remote)
- **Nome:** gdrive-backup
- **Storage:** 18 (Google Drive)
- **client_id:** (deixe em branco) Enter
- **client_secret:** (deixe em branco) Enter
- **scope:** 1 (Full access)
- **root_folder_id:** (deixe em branco) Enter
- **service_account_file:** (deixe em branco) Enter
- **Edit advanced config?** n
- **Use auto config?** y (abre navegador)
- **Configure this as a team drive?** n
- **Yes this is OK** y

**Testar:**

```bash
rclone lsd gdrive-backup:
```

**Criar pasta de backups:**

```bash
rclone mkdir gdrive-backup:bkps
```

### 4. Dar Permissões

```bash
chmod +x *.sh
```

### 5. Testar Scripts

```bash
# Teste 1: Backup
./backup-postgres.sh

# Teste 2: Sync Google Drive
./sync-gdrive.sh

# Teste 3: Verificação do sistema
./backup-manager.sh check
```

No teste de backup, o script também:

1. Atualiza o `dashboard.html`
2. Copia para `public/index.html`
3. Faz deploy em produção no Netlify (`--prod`)

### 6. Configurar Automação (Cron)

```bash
crontab -e
```

**Adicionar no final:**

```bash
# Backup PostgreSQL automático
0 13 * * * cd /caminho/completo/databases/postgres/scripts && ./backup-postgres.sh >> ../bkps/backup.log 2>&1

# Sync Google Drive automático
30 13 * * * cd /caminho/completo/databases/postgres/scripts && ./sync-gdrive.sh >> ../bkps/sync.log 2>&1
```

**Substitua `/caminho/completo/` pelo caminho real!**

Para descobrir o caminho:

```bash
cd databases/postgres/scripts
pwd
```

---

## ✅ Checklist de Instalação

Use esta lista para garantir que tudo está funcionando:

### Dependências

- [ ] Docker instalado
- [ ] Container PostgreSQL rodando
- [ ] curl instalado
- [ ] gzip instalado
- [ ] rclone instalado
- [ ] Netlify CLI instalada

### Configuração

- [ ] Arquivo `.env` criado em `scripts/.env`
- [ ] Webhook Discord configurado em `.env`
- [ ] rclone configurado (remote: `gdrive-backup`)
- [ ] Pasta `bkps` criada no Google Drive
- [ ] Scripts com permissão de execução (`chmod +x`)
- [ ] `NETLIFY_AUTH_TOKEN` configurado em `scripts/.env`
- [ ] `NETLIFY_SITE_ID` configurado em `scripts/.env`
- [ ] `NETLIFY_SITE_URL` configurado em `scripts/.env`

### Testes

- [ ] `./backup-postgres.sh` executou sem erros
- [ ] Arquivos `.sql.gz` criados em `bkps/`
- [ ] Notificação recebida no Discord
- [ ] `./sync-gdrive.sh` executou sem erros
- [ ] Arquivos aparecem no Google Drive
- [ ] `./backup-manager.sh check` mostra tudo OK
- [ ] Dashboard publicado no Netlify após backup
- [ ] Alertas de erro no Discord mostram link de `NETLIFY_SITE_URL`

### Automação

- [ ] Cron configurado (se desejado)
- [ ] `crontab -l` mostra jobs de backup
- [ ] Aguardar 13h para testar automático (ou ajustar horário)

---

## 🔍 Verificação Pós-Instalação

### Testar sistema completo

```bash
cd databases/postgres/scripts
./backup-manager.sh check
```

**Resultado esperado:**

```
✓ Docker instalado
✓ Container PostgreSQL rodando
✓ rclone instalado
✓ Remote Google Drive configurado
✓ Arquivo .env existe
✓ Webhook Discord configurado
✓ Diretório de backups existe

✅ Tudo OK! Sistema pronto para uso.
```

### Ver backups criados

```bash
ls -lh ../bkps/*.sql.gz
```

### Ver arquivos no Google Drive

```bash
rclone ls gdrive-backup:bkps
```

### Testar notificação Discord

```bash
curl -X POST "$DISCORD_WEBHOOK_URL_BKP" \
  -H "Content-Type: application/json" \
  -d '{"content": "✅ Sistema de backup configurado com sucesso!"}'
```

---

## 🆘 Problemas Comuns

### ❌ "rclone: command not found"

```bash
# Instalar rclone
curl https://rclone.org/install.sh | sudo bash
```

### ❌ "empty token found"

```bash
# Reautorizar Google Drive
rclone config reconnect gdrive-backup:
```

### ❌ "Container não encontrado"

```bash
# Verificar containers
docker ps

# Iniciar PostgreSQL
docker compose up -d postgres
```

### ❌ "Permissão negada"

```bash
chmod +x databases/postgres/scripts/*.sh
```

### ❌ "Webhook não chega no Discord"

1. Verificar URL em `.env`
2. Testar manualmente com curl (comando acima)
3. Verificar permissões do webhook no Discord

### ❌ "Deploy Netlify não executa"

```bash
# Verificar se CLI está instalada
netlify --version

# Verificar variáveis no arquivo correto
cd databases/postgres/scripts
grep -E "NETLIFY_AUTH_TOKEN|NETLIFY_SITE_ID|NETLIFY_SITE_URL" .env
```

Se `NETLIFY_AUTH_TOKEN` ou `NETLIFY_SITE_ID` estiverem vazios, o backup continua, mas o deploy é ignorado com aviso no log.

---

## 📚 Próximos Passos

Após a instalação bem-sucedida:

1. **Usar o sistema:**

   ```bash
   ./backup-manager.sh
   ```

2. **Ler documentação completa:**
   - [README.md](../README.md) - Uso diário
   - [SECURITY.md](SECURITY.md) - Antes de subir no GitHub

3. **Ajustar configurações (opcional):**
   ```bash
   nano .env
   ```

---

**Instalação concluída?** Use `./backup-manager.sh` para gerenciar seus backups!

**Problemas?** Consulte [README.md](../README.md#🔧-troubleshooting) para mais ajuda.

```bash
cd databases/postgres/scripts/
./backup-postgres.sh
```

**O que acontece:**

1. Faz backup de roles/globals
2. Lista todos os bancos (exceto templates, postgres)
3. Para cada banco:
   - Cria dump comprimido
   - Valida integridade (zcat)
   - Registra status
4. Aplica política de retenção
5. Envia notificação Discord

### Sincronização Manual

```bash
./sync-gdrive.sh
```

**O que acontece:**

1. Lista arquivos `.sql.gz` em `../bkps/`
2. Para cada arquivo:
   - Faz upload para Google Drive
   - Mede tempo de upload
   - Registra status
3. Envia notificação Discord com tabela

### Restauração Interativa

```bash
./restore-postgres.sh
```

**Passo a passo:**

1. Lista backups disponíveis (numerados)
2. Você escolhe o número
3. Mostra nome do banco detectado
4. Pede confirmação
5. Descomprime (se `.gz`) e restaura

**Exemplo:**

```bash
Backups disponíveis:
1) dev_database_2026-03-21_11:09:03.sql.gz
2) globals_2026-03-21_11:09:03.sql.gz

Escolha o número do backup: 1
Banco detectado: dev_database
Deseja restaurar? (s/n): s
```

---

## ⏰ Automação com Cron

### Configurar Cron

```bash
cd databases/postgres/scripts/
./setup-backup-cron.sh
```

**Opções:**

- **b** - Apenas backup diário às 13h
- **s** - Backup + Sync (13h backup, 13:30 sync)
- **n** - Não configurar sync

**O que o script faz:**

1. Detecta caminho absoluto do projeto
2. Lê webhook do arquivo `.env`
3. Cria cron jobs com variável de ambiente
4. Adiciona ao crontab do usuário

**Cron criado (exemplo):**

```cron
# Backup PostgreSQL diário
0 13 * * * DISCORD_WEBHOOK_URL_BKP='https://...' /caminho/completo/backup-postgres.sh >> /caminho/completo/../bkps/backup.log 2>&1

# Sync Google Drive (opcional)
30 13 * * * DISCORD_WEBHOOK_URL_BKP='https://...' /caminho/completo/sync-gdrive.sh >> /caminho/completo/../bkps/sync.log 2>&1
```

### Ver Cron Configurado

```bash
crontab -l | grep -A 2 "Backup PostgreSQL"
```

### Remover Cron

```bash
crontab -e
# Deletar as linhas do backup
```

---

## 📂 Estrutura de Arquivos

```
databases/postgres/
├── scripts/
│   ├── backup-postgres.sh       # Script principal de backup
│   ├── restore-postgres.sh      # Script de restauração interativa
│   ├── sync-gdrive.sh          # Sincronização com Google Drive
│   ├── setup-backup-cron.sh    # Configuração de automação
│   ├── install-rclone.sh       # Instalação/configuração rclone
│   ├── load-env.sh             # Helper para carregar .env
│   └── .env.example            # Exemplo de variáveis de ambiente
├── bkps/                       # Backups locais (.sql.gz)
│   ├── globals_YYYY-MM-DD_HH:MM:SS.sql.gz
│   ├── nome_banco_YYYY-MM-DD_HH:MM:SS.sql.gz
│   ├── backup.log              # Log do backup
│   └── sync.log                # Log do sync
├── docs/                       # Documentação
│   ├── SETUP.md                # Este arquivo (guia de instalação)
│   └── SECURITY.md             # Guia de segurança e GitHub
└── README.md                   # Documentação completa de uso
```

---

## 🔧 Troubleshooting

### Problema: "rclone: command not found"

**Solução:**

```bash
./install-rclone.sh
```

### Problema: "empty token found - please run rclone config reconnect"

**Solução:**

```bash
rclone config reconnect gdrive-backup:
# Autorize novamente no navegador
```

### Problema: "DISCORD_WEBHOOK_URL_BKP não configurado"

**Solução:**

```bash
# Editar .env na raiz do projeto
nano /caminho/do/projeto/.env

# Adicionar:
DISCORD_WEBHOOK_URL_BKP=https://discord.com/api/webhooks/...

# Exportar manualmente (para testes):
export DISCORD_WEBHOOK_URL_BKP='https://...'
```

### Problema: Container PostgreSQL não encontrado

**Solução:**

```bash
# Verificar se container está rodando
docker ps | grep postgres

# Se não estiver, iniciar compose
cd /caminho/do/projeto/
docker compose up -d
```

### Problema: Backup falha com "permission denied"

**Solução:**

```bash
# Dar permissão aos scripts
chmod +x databases/postgres/scripts/*.sh

# Verificar permissão da pasta bkps
ls -la databases/postgres/bkps/
```

### Problema: Notificação não chega no Discord

**Solução:**

1. Verificar se webhook está correto
2. Testar manualmente:

```bash
curl -X POST "https://discord.com/api/webhooks/..." \
  -H "Content-Type: application/json" \
  -d '{"content": "Teste"}'
```

### Problema: Sync Google Drive muito lento

**Motivo:** rclone faz upload arquivo por arquivo para capturar métricas individuais

**Alternativa rápida:**

```bash
# Sync em lote (sem métricas individuais)
rclone sync ../bkps gdrive-backup:bkps --include "*.sql.gz" --progress
```

### Problema: Tabela quebrada no Discord

**Verificar:**

- Nomes de arquivo muito longos são truncados em 36 caracteres
- Usar fonte monoespaçada no Discord (já aplicado com \`\`\`)
- Verificar se espaçamento está correto (2 espaços entre colunas)

---

## 📊 Exemplo de Notificações

### Backup PostgreSQL

```
✅ Backup PostgreSQL Concluído

📊 Detalhes dos Backups
Banco                 Tamanho   Status  Validado
────────────────────────────────────────────────
dev_database          4.0K      ✓       ✓
test_db_1             4.0K      ✓       ✓
test_db_2             4.0K      ✓       ✓

Total: 0MB  •  Duração: 1s  •  Data: 21/03/2026 11:09:04
```

### Sync Google Drive

```
✅ Backup Sincronizado com Google Drive

📊 Detalhes do Upload
Arquivo                              Tamanho  Tempo  Status
───────────────────────────────────────────────────────────
dev_database_2026-03-21_11:09:03...  373B     1s     ✓
globals_2026-03-21_11:09:03.sql.gz   457B     1s     ✓
test_db_2_2026-03-21_11:09:03.sq...  374B     2s     ✓

Total: 0MB  •  Duração: 5s  •  Data: 21/03/2026 11:39:57
```

---

## 🔐 Segurança

### Variáveis Sensíveis

- **Webhook Discord**: Armazenado em `.env` (gitignored)
- **Token rclone**: Armazenado em `~/.config/rclone/rclone.conf`
- **Senha PostgreSQL**: Via Docker (variável de ambiente ou secrets)

### Recomendações

1. Nunca commitar `.env` no git
2. Usar `.env.example` como template
3. Proteger webhook do Discord (renovar se exposto)
4. Backups locais em `bkps/` também estão no `.gitignore`
5. Google Drive com autenticação OAuth (mais seguro que service account)

---

## 📝 Changelog

### v1.0 - 2026-03-21

- ✅ Backup comprimido com gzip
- ✅ Validação de integridade
- ✅ Notificações Discord com tabelas
- ✅ Sync Google Drive com rclone
- ✅ Política de retenção 7 dias
- ✅ Restauração interativa
- ✅ Automação via cron
- ✅ Backup de roles/globals
- ✅ Documentação completa

---

## 🆘 Suporte

**Em caso de problemas:**

1. Verificar logs em `bkps/backup.log` e `bkps/sync.log`
2. Testar scripts manualmente antes de configurar cron
3. Verificar se Docker está rodando: `docker ps`
4. Verificar configuração rclone: `rclone config show`
5. Testar webhook Discord manualmente com curl

---

## 📜 Licença

Projeto de uso interno - configuração específica para backup PostgreSQL.

---

**Última atualização:** 21/03/2026
