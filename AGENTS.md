# AGENTS.md

Instruções para agentes de código (Claude Code, Gemini CLI, Codex etc.) que trabalham neste repositório.
O `CLAUDE.md` e o `GEMINI.md` apontam para este arquivo: mantenha o conteúdo só aqui.

## O que é o projeto

Ambiente local de bancos de dados com Docker Compose, organizado por **contextos** (cada banco sobe junto com a sua UI de administração), mais um **sistema de backup do PostgreSQL** (`databases/postgres/`) com restore de teste, métricas, dashboard no Netlify, notificações no Discord e sync com o Google Drive.

Uso exclusivamente local/desenvolvimento. Os serviços não sobem sozinhos: todos têm `restart: 'no'` e isso deve ser mantido.

## Idioma e estilo

- Documentação, mensagens de log, comentários e commits em **português (pt-BR)**.
- Commits no formato do histórico: `feat:`, `fix:`, etc.
- Scripts em Bash, com o estilo dos existentes (funções `log`/`error`/`warning`/`info`, cores ANSI, `SCRIPT_DIR`). Siga o que já está lá em vez de introduzir outro padrão.

## Estrutura

```
docker-compose.yml        10 serviços, rede externa development_environment
Makefile                  comandos por contexto (make postgres-start, ...)
start.sh                  prepara o ambiente (diretórios, configs, rede, .env); não sobe containers
stop.sh                   para o ambiente (--list, --volumes, --images, --clean [--data])
generate-passwords.sh     gera o .env com senhas aleatórias
configs/                  redis.conf, mysql/conf.d/custom.cnf, */init/ (conteúdo ignorado pelo git)
databases/postgres/
  backup-manager.sh       menu/CLI: backup, restore, sync, setup, check, metrics
  dashboard.template.html template versionado do dashboard (Chart.js via CDN)
  dashboard.html          GERADO por scripts/update-dashboard.sh (ignorado)
  public/index.html       GERADO e publicado no Netlify (ignorado)
  scripts/                backup-postgres.sh, restore-postgres.sh, sync-gdrive.sh,
                          update-dashboard.sh, setup.sh, load-env.sh, .env(.example)
  bkps/                   backups .sql.gz, logs e metrics/*.json (tudo ignorado)
  docs/                   SETUP.md e SECURITY.md
```

## Comandos úteis

```bash
./start.sh                    # primeira vez: cria data/, configs, rede e .env
make postgres-start           # postgres + pgadmin     (stop: make postgres-stop)
make redis-start              # redis + redisinsight
make mysql-start | mariadb-start | mongodb-start | firebird-start
make status | stop-all | logs SERVICE=nome
docker compose config -q      # valida o compose

cd databases/postgres && ./backup-manager.sh   # menu de backup
```

Portas padrão: Postgres 5432, pgAdmin 5050, MySQL 3306, MariaDB 3307, Adminer 8080, MongoDB 27017, Mongo Express 8081, Redis 6379, RedisInsight 5540, Firebird 3050.

## Como validar mudanças

Não há suíte de testes. Valide assim:

- Scripts: `bash -n arquivo.sh` (e `shellcheck` se disponível; há avisos antigos SC2155 que são aceitos).
- Compose: `docker compose config -q`.
- Backup/restore/sync: teste de ponta a ponta com um Postgres **descartável** (`docker run -d --name postgres -e POSTGRES_PASSWORD=x postgres:18-alpine`) e uma **cópia** de `databases/postgres` **sem** `scripts/.env`. Apague o container e a cópia ao terminar. Para o sync, use um `rclone` falso no `PATH`.
- Redis e outros serviços: `docker compose up -d --wait <serviço>`; derrube depois. Se criar `data/` como teste, remova (arquivos de container podem ser de outro dono: use um container `alpine` para apagar).

## Cuidados importantes

- **Segredos:** `.env` e `databases/postgres/scripts/.env` têm senhas, token do Netlify e webhook do Discord. Nunca imprima os valores, nunca commite, nunca copie para docs/logs. Para listar, mostre só os nomes das variáveis.
- **Efeitos externos:** rodar `backup-postgres.sh` ou `sync-gdrive.sh` com o `scripts/.env` real envia mensagens ao Discord, publica no Netlify (`--prod`) e envia ao Google Drive. Só faça isso se o usuário pedir.
- **Dados:** `stop.sh --clean --data` e `make clean` removem dados/volumes; `restore-postgres.sh` opção 1 apaga o banco alvo. Confirme com o usuário antes.
- **Arquivos gerados** (`dashboard.html`, `public/`, `bkps/`, `.netlify/`) não são versionados. Edite o `dashboard.template.html`, nunca o HTML gerado. O dashboard publicado tem os nomes dos bancos anonimizados (`DASHBOARD_MASK_DB_NAMES=true`).
- `databases/postgres/postgres/` é uma cópia aninhada acidental, ignorada pelo git. Não é fonte da verdade.
- `start-claude.sh` é do usuário e não é versionado. Não altere nem commite.

## Armadilhas conhecidas

- **PostgreSQL 18:** o volume é montado em `/var/lib/postgresql` (não em `/var/lib/postgresql/data`).
- **pgAdmin** roda como uid 5050: `data/pgadmin` precisa pertencer a `5050:5050` (`sudo chown -R 5050:5050 data/pgadmin`, ou um container `alpine`). O RedisInsight roda como `1000:1000`.
- **Redis** carrega `configs/redis/redis.conf` (com `bind 0.0.0.0`) e recebe `--requirepass` pelo compose. O healthcheck usa a senha.
- **Nomes de banco com hífen** (ex.: `dav-coffcode`) exigem aspas como identificador SQL; os scripts já fazem isso, mantenha.
- Falhas de `pg_dump | gzip` só são detectadas com `pipefail`; o `backup-postgres.sh` usa `set -o pipefail` localmente (não global, para não quebrar `docker ps | grep -q`).
- Os scripts do backup já gravam em `bkps/backup.log` e `bkps/sync.log`; o cron redireciona a saída para `/dev/null` para não duplicar linhas.
- Métricas: um JSON por execução (`AAAA-MM-DD_HH-MM-SS.json`); o dashboard embute os últimos 30 em ordem cronológica.
- Portas dos bancos publicam em `0.0.0.0` e os `.env` têm permissão ampla. Isso é uma escolha consciente do dono do projeto (ambiente local); não "corrija" sem pedirem.

## Commits e PRs

- Faça commit ou push **somente quando o usuário pedir**.
- Não inclua `Co-Authored-By` nem qualquer atribuição a agentes/IA nas mensagens de commit ou descrições de PR.
- Antes de commitar, confira que nada de `.env`, `*.sql*`, `*.log`, `bkps/`, `public/` ou `dashboard.html` entrou no stage.
