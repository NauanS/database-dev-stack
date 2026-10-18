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
RETENTION_DAYS=7
GDRIVE_REMOTE=gdrive-backup
GDRIVE_PATH=bkps
NETLIFY_AUTH_TOKEN=SEU_TOKEN_NETLIFY
NETLIFY_SITE_ID=SEU_SITE_ID
NETLIFY_SITE_URL=https://seu-site.netlify.app
DASHBOARD_MASK_DB_NAMES=true
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
../backup-manager.sh check
```

No teste de backup, o script também:

1. Gera o `dashboard.html` (a partir de `dashboard.template.html`)
2. Copia para `public/index.html`, anonimizando os nomes dos bancos (`DASHBOARD_MASK_DB_NAMES=true`)
3. Faz deploy em produção no Netlify (`--prod`)

### 6. Configurar Automação (Cron)

```bash
crontab -e
```

**Adicionar no final:**

```bash
# Backup PostgreSQL automático (o script já grava em bkps/backup.log; não redirecione de novo)
0 13 * * * cd /caminho/completo/databases/postgres/scripts && ./backup-postgres.sh > /dev/null 2>&1

# Sync Google Drive automático (grava em bkps/sync.log)
30 13 * * * cd /caminho/completo/databases/postgres/scripts && ./sync-gdrive.sh > /dev/null 2>&1
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
cd databases/postgres
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
