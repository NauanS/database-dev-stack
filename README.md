# Ambiente de Bancos de Dados (Docker)

Ambiente local com vários bancos de dados e suas interfaces de administração, organizado por **contextos**: cada banco sobe junto com a sua UI e você roda só o que precisa. Inclui um **sistema de backup do PostgreSQL** com restore de teste, métricas, dashboard, notificações no Discord e sync com o Google Drive.

Pensado para desenvolvimento local. Nenhum serviço sobe sozinho (`restart: 'no'`).

## Serviços

| Banco      | Versão       | Porta | Interface web       | Porta da UI |
| ---------- | ------------ | ----- | ------------------- | ----------- |
| PostgreSQL | 18-alpine    | 5432  | pgAdmin4 7.8        | 5050        |
| MySQL      | 8.0.34       | 3306  | Adminer 4.8.1       | 8080        |
| MariaDB    | 10.11.5      | 3307  | Adminer 4.8.1       | 8080        |
| MongoDB    | 7.0.2        | 27017 | Mongo Express 1.0.2 | 8081        |
| Redis      | 7.2.1-alpine | 6379  | RedisInsight 2.54   | 5540        |
| Firebird   | 3.0.10       | 3050  | -                   | -           |

As portas podem ser trocadas no `.env`.

## Pré-requisitos

Docker Engine 20.10+, Docker Compose 2.0+, Make e Bash.

## Início rápido

```bash
git clone https://github.com/NauanS/database-dev-stack.git
cd database-dev-stack

./start.sh              # cria a rede, data/, configs e o .env com senhas aleatórias
make postgres-start     # PostgreSQL + pgAdmin4
make status             # ver o que está rodando
make postgres-stop      # parar
```

Se o `start.sh` avisar sobre `data/pgadmin`, corrija a permissão (o pgAdmin roda como uid 5050):

```bash
sudo chown -R 5050:5050 data/pgadmin
```

## Comandos

| Contexto   | Iniciar               | Parar                | Shell                 |
| ---------- | --------------------- | -------------------- | --------------------- |
| PostgreSQL | `make postgres-start` | `make postgres-stop` | `make postgres-shell` |
| MySQL      | `make mysql-start`    | `make mysql-stop`    | `make mysql-shell`    |
| MariaDB    | `make mariadb-start`  | `make mariadb-stop`  | `make mariadb-shell`  |
| MongoDB    | `make mongodb-start`  | `make mongodb-stop`  | `make mongodb-shell`  |
| Redis      | `make redis-start`    | `make redis-stop`    | `make redis-shell`    |
| Firebird   | `make firebird-start` | `make firebird-stop` | -                     |

Cada `*-start` sobe o banco junto com a interface dele. Para subir só o banco, use `docker compose up -d postgres`; para derrubar só a UI, `docker compose stop pgadmin`.

Comandos gerais:

```bash
make help                    # lista tudo
make status                  # status dos serviços
make stop-all                # derruba todos os serviços
make logs SERVICE=postgres   # logs de um serviço
make backup SERVICE=postgres # dump simples em backups/ (postgres, mysql, mariadb)
make passwords               # gera novas senhas
make clean                   # remove containers e volumes (mantém imagens, data/ e a rede)
```

`./stop.sh` aceita `--list`, `--volumes`, `--images` e `--clean [--data]` (o `--data` apaga `data/`).

## Credenciais e acesso

As senhas são geradas em `.env` (não versionado). Para ver os nomes das variáveis sem expor os valores:

```bash
grep -E "USER|PASSWORD|DATABASE" .env | sed 's/=.*/=…/'
```

- **pgAdmin4:** `http://localhost:5050` com `PGADMIN_EMAIL` e `PGADMIN_PASSWORD`.
- **Adminer:** `http://localhost:8080`; informe sistema (MySQL/MariaDB/PostgreSQL), servidor (`mysql`, `mariadb`, `postgres`), usuário e senha.
- **Mongo Express:** `http://localhost:8081` com `MONGO_EXPRESS_USER` e `MONGO_EXPRESS_PASSWORD`.
- **RedisInsight:** `http://localhost:5540`; o Redis exige `REDIS_PASSWORD`.

Conexão manual, por exemplo:

```bash
psql -h localhost -p 5432 -U postgres -d dev_database
mysql -h 127.0.0.1 -P 3306 -u mysql_user -p
mongosh "mongodb://admin:<senha>@localhost:27017"
redis-cli -h localhost -p 6379 -a <senha>
```

## Backup do PostgreSQL

Fica em `databases/postgres/`. O menu interativo reúne tudo:

```bash
cd databases/postgres
./backup-manager.sh            # menu
./backup-manager.sh backup     # backup agora
./backup-manager.sh restore    # restaurar
./backup-manager.sh sync       # enviar ao Google Drive
./backup-manager.sh check      # verificar ambiente
./backup-manager.sh metrics    # abrir o dashboard
```

O que o backup faz:

1. Salva roles e configurações globais (`pg_dumpall --globals-only`).
2. Faz `pg_dump` comprimido de cada banco, em paralelo.
3. **Testa o restore** de cada dump em um banco temporário.
4. Grava métricas em `bkps/metrics/` (um JSON por execução) e gera o dashboard.
5. Publica o dashboard no Netlify (nomes dos bancos anonimizados), avisa no Discord e apaga backups com mais de `RETENTION_DAYS` (padrão 7).

O sync com o Google Drive (via rclone) envia só o que ainda não está lá e aplica a mesma retenção no Drive.

Configuração (`databases/postgres/scripts/.env`, copiado do `.env.example`): webhook do Discord, remote do rclone, retenção, credenciais do Netlify e `DASHBOARD_MASK_DB_NAMES`. O `setup.sh` (opção 4 do menu) configura o rclone e o cron (backup 13:00, sync 13:30).

Documentação detalhada: [databases/postgres/README.md](databases/postgres/README.md), [SETUP.md](databases/postgres/docs/SETUP.md) e [SECURITY.md](databases/postgres/docs/SECURITY.md).

## Estrutura

```
docker-compose.yml        serviços (rede externa development_environment)
Makefile                  comandos por contexto
start.sh / stop.sh        preparar / parar o ambiente
generate-passwords.sh     gera o .env
configs/                  redis.conf, mysql/conf.d, */init/
databases/postgres/       sistema de backup (scripts, dashboard, docs)
data/                     dados dos bancos (criado pelo start.sh, não versionado)
AGENTS.md                 instruções para agentes de código (CLAUDE.md e GEMINI.md apontam para ele)
```

## Documentação

- [databases/postgres/README.md](databases/postgres/README.md): sistema de backup do PostgreSQL (uso, automação, troubleshooting).
- [databases/postgres/docs/SETUP.md](databases/postgres/docs/SETUP.md): instalação e configuração passo a passo (Discord, rclone, Netlify, cron).
- [databases/postgres/docs/SECURITY.md](databases/postgres/docs/SECURITY.md): segurança e checagens antes de commitar.
- [AGENTS.md](AGENTS.md): instruções para agentes de código; o [CLAUDE.md](CLAUDE.md) e o [GEMINI.md](GEMINI.md) apontam para ele.

## Solução de problemas

- **Porta em uso:** `make status`, depois `make stop-all` ou `lsof -i :5432`.
- **PostgreSQL 18, erro de "unused mount/volume":** o volume deve ser montado em `/var/lib/postgresql` (já está assim no compose). Se for um ambiente descartável, `docker compose down` e suba de novo; se precisa dos dados antigos, migre com `pg_upgrade`.
- **Permissão em `data/`:** `sudo chown -R $USER:$USER data/` (exceto `data/pgadmin`, que deve ser `5050:5050`).
- **Redis pede senha:** use `REDIS_PASSWORD` do `.env` (`redis-cli -a <senha>`).
- **Logs:** `make logs SERVICE=nome` ou `docker compose logs -f nome`.

## Segurança

- `.env` e `databases/postgres/scripts/.env` guardam senhas, token do Netlify e webhook do Discord e **nunca** devem ser commitados (já estão no `.gitignore`, assim como backups, logs e métricas).
- As portas dos bancos são publicadas em todas as interfaces, o que é aceitável para uso local. Em redes compartilhadas, publique em `127.0.0.1` (ex.: `'127.0.0.1:5432:5432'`).

## Licença

MIT. Veja o arquivo [LICENSE](LICENSE).
