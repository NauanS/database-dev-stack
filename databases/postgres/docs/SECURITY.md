# 🔒 Segurança e Preparação para GitHub

Guia de segurança para proteger dados sensíveis antes de subir no GitHub.

---

## ⚠️ Antes de Commitar

**Arquivos que NUNCA devem ser commitados:**

```
scripts/.env                    ← Webhook Discord, senhas
bkps/                           ← Backups dos bancos
*.sql                           ← Dumps de banco
*.sql.gz                        ← Backups comprimidos
*.log                           ← Logs do sistema
data/                           ← Dados dos containers
~/.config/rclone/rclone.conf   ← Tokens Google Drive
dashboard.html, public/         ← Gerados a cada backup (o dashboard publicado tem os nomes dos bancos anonimizados)
.netlify/                       ← Estado local do Netlify CLI (caminhos absolutos)
```

**Já está protegido no `.gitignore` ✅**

---

## 🔍 Verificação Automática

O `setup.sh` (etapa 5, "Verificação de Segurança") confere:

- `.env` ignorado pelo git
- Webhooks Discord expostos em arquivos públicos
- Backups `.sql` rastreados pelo git

Para rodar uma checagem manual antes de cada commit:

```bash
git check-ignore -v databases/postgres/scripts/.env     # deve listar a regra do .gitignore
git ls-files | grep -E '\.env$|\.sql|\.log'            # não deve listar nada
git grep -nE 'discord.com/api/webhooks/[0-9]'            # não deve listar nada
```

Dica: `chmod 600 databases/postgres/scripts/.env` (o arquivo contém tokens).

---

## 📤 Como Subir para GitHub

### 1. Verificar Segurança

```bash
git ls-files | grep -E '\.env$|\.sql|\.log'
git grep -nE 'discord.com/api/webhooks/[0-9]'
```

Só prossiga se os dois comandos não listarem nada.

### 2. Verificar Status

```bash
git status
```

**Deve aparecer:**

- ✅ Scripts (`.sh`)
- ✅ Documentação (`.md`)
- ✅ `.env.example`
- ✅ `.gitignore`

**NÃO deve aparecer:**

- ❌ `scripts/.env`
- ❌ `dashboard.html`, `public/`, `.netlify/`
- ❌ `bkps/`
- ❌ `*.sql` ou `*.sql.gz`
- ❌ `*.log`

### 3. Adicionar Arquivos

```bash
cd /caminho/do/projeto
git add .gitignore
git add databases/postgres/scripts/*.sh databases/postgres/backup-manager.sh
git add databases/postgres/*.md databases/postgres/dashboard.template.html
git add databases/postgres/scripts/.env.example
```

### 4. Verificar Staging

```bash
git diff --cached --name-only
```

**Certifique-se que `scripts/.env` NÃO aparece!**

### 5. Commit

```bash
git commit -m "feat: Sistema de backup PostgreSQL consolidado

- Menu interativo (backup-manager.sh)
- Setup unificado (setup.sh)
- Backup comprimido com notificações Discord
- Sync Google Drive automático
- Documentação simplificada (6 → 3 arquivos)"
```

### 6. Criar Repositório GitHub

**GitHub.com:**

1. Acesse https://github.com/new
2. Nome: `infra-local-databases` (ou outro)
3. Descrição: "Sistema de backup PostgreSQL com Discord e Google Drive"
4. Visibilidade: Público ou Privado
5. **NÃO** marque "Add a README" (você já tem)
6. Create repository

### 7. Push

```bash
git remote add origin https://github.com/SEU_USUARIO/REPO.git
git branch -M main
git push -u origin main
```

---

## 🛡️ Usar em Outro Computador

Depois de clonar o repositório:

### 1. Clonar

```bash
git clone https://github.com/SEU_USUARIO/REPO.git
cd REPO/databases/postgres
```

### 2. Configurar

```bash
cd scripts
cp .env.example .env
nano .env
```

Adicionar:

```bash
DISCORD_WEBHOOK_URL_BKP=https://discord.com/api/webhooks/SEU_WEBHOOK
```

### 3. Setup

```bash
./setup.sh
```

(ou `./backup-manager.sh`, opção 4, na pasta `databases/postgres`)

Pronto! Sistema configurado.

---

## 🚨 Se Expor Dados Sensíveis

### Antes de fazer push

```bash
# Remover do staging
git reset HEAD arquivo-sensivel.txt

# Adicionar ao .gitignore
echo "arquivo-sensivel.txt" >> .gitignore
git add .gitignore
git commit -m "Add arquivo ao gitignore"
```

### Depois de fazer push (URGENTE!)

**1. Revogar credenciais imediatamente:**

- Discord: Deletar e recriar webhook
- Google Drive: Revogar em https://myaccount.google.com/permissions
- PostgreSQL: Mudar senha

**2. Remover do histórico Git:**

```bash
# Instalar git-filter-repo
pip install git-filter-repo

# Remover arquivo
git filter-repo --path arquivo-sensivel.txt --invert-paths

# Force push (CUIDADO!)
git push origin --force --all
```

**3. Notificar a equipe** (se repositório compartilhado)

---

## ✅ Checklist Final

Antes de cada commit:

- [ ] Rodei as checagens da seção "Verificação" sem resultados
- [ ] `git status` não mostra `.env`
- [ ] `git status` não mostra arquivos `.sql` ou `.sql.gz`
- [ ] `git diff --cached` revisado
- [ ] Webhooks não aparecem em arquivos commitados
- [ ] Caminhos absolutos usam placeholders genéricos

---

## 📁 Estrutura no GitHub

**O que VAI para o GitHub:**

```
databases/postgres/
├── backup-manager.sh           ✅
├── dashboard.template.html     ✅
├── scripts/
│   ├── setup.sh                ✅
│   ├── update-dashboard.sh     ✅
│   ├── backup-postgres.sh      ✅
│   ├── restore-postgres.sh     ✅
│   ├── sync-gdrive.sh          ✅
│   ├── load-env.sh             ✅
│   └── .env.example            ✅ (template)
├── docs/
│   ├── SETUP.md                ✅
│   └── SECURITY.md             ✅ (este arquivo)
└── README.md                   ✅
```

**O que NÃO vai:**

```
scripts/.env                    ❌ (webhook real)
bkps/                           ❌ (seus backups)
*.log                           ❌ (logs)
data/                           ❌ (dados sensíveis)
```

---

## 📚 Referências

- [GitHub: Removing sensitive data](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/removing-sensitive-data-from-a-repository)
- [12 Factor App: Config](https://12factor.net/config)
- [OWASP: Secrets Management](https://cheatsheetseries.owasp.org/cheatsheets/Secrets_Management_Cheat_Sheet.html)

---

**Lembre-se:** É melhor verificar 10 vezes do que expor um webhook 1 vez! 🔒
