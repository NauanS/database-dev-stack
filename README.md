# 🚀 Ambiente de Desenvolvimento - Bancos de Dados

Ambiente Docker completo com múltiplos bancos de dados e ferramentas de administração, otimizado para desenvolvimento local com **arquitetura baseada em contextos** - execute apenas os serviços que você precisa!

## 📋 Serviços Disponíveis

| Banco de Dados | Versão | Porta | Interface Web    | Porta Interface |
| -------------- | ------ | ----- | ---------------- | --------------- |
| PostgreSQL     | 15.4   | 5432  | **pgAdmin4**     | **5050**        |
| MySQL          | 8.0    | 3306  | Adminer          | 8080            |
| MariaDB        | 10.11  | 3307  | Adminer          | 8080            |
| MongoDB        | 7.0    | 27017 | Mongo Express    | 8081            |
| Redis          | 7.2    | 6379  | **RedisInsight** | **5540**        |
| Firebird       | 3.0    | 3050  | -                | -               |

## 🎯 Conceito de Contextos

Este ambiente utiliza uma **arquitetura baseada em contextos**, onde cada banco de dados pode ser iniciado individualmente junto com suas ferramentas de administração específicas. Isso permite:

- ✅ **Economia de recursos**: Execute apenas o que você precisa
- ✅ **Isolamento**: Cada contexto é independente
- ✅ **Flexibilidade**: Combine diferentes contextos conforme necessário
- ✅ **Performance**: Menor consumo de memória e CPU

## 🚀 Início Rápido

### Pré-requisitos

Certifique-se de ter instalado:

- Docker Engine 20.10+
- Docker Compose 2.0+
- Make
- Bash

### 1. Configuração Inicial

```bash
# Clone o repositório
git clone <seu-repo>
cd dabases

# Execute a configuração inicial (OBRIGATÓRIO na primeira vez)
./start.sh

# Isso irá:
# ✅ Criar a rede externa 'development_environment'
# ✅ Gerar arquivo .env com senhas seguras
# ✅ Criar diretórios necessários
```

### 2. Primeiro Uso - Exemplo Completo

```bash
# Iniciar PostgreSQL com pgAdmin4
make postgres-start

# Aguardar alguns segundos para inicialização
sleep 10

# Verificar se está funcionando
make status

# Acessar pgAdmin4: http://localhost:5050
# Acessar PostgreSQL: localhost:5432

# Quando terminar
make postgres-stop
```

### 2. Comandos por Contexto

> **💡 Dica**: Cada contexto inicia o banco de dados junto com sua interface de administração específica.

#### PostgreSQL + pgAdmin4

```bash
make postgres-start    # Inicia PostgreSQL + pgAdmin4
make postgres-stop     # Para PostgreSQL + pgAdmin4

# URLs:
# PostgreSQL: localhost:5432
# pgAdmin4: http://localhost:5050
```

#### MySQL + Adminer

```bash
make mysql-start       # Inicia MySQL + Adminer
make mysql-stop        # Para MySQL + Adminer

# URLs:
# MySQL: localhost:3306
# Adminer: http://localhost:8080
```

#### MariaDB + Adminer

```bash
make mariadb-start     # Inicia MariaDB + Adminer
make mariadb-stop      # Para MariaDB + Adminer

# URLs:
# MariaDB: localhost:3307
# Adminer: http://localhost:8080
```

#### MongoDB + Mongo Express

```bash
make mongodb-start     # Inicia MongoDB + Mongo Express
make mongodb-stop      # Para MongoDB + Mongo Express

# URLs:
# MongoDB: localhost:27017
# Mongo Express: http://localhost:8081
```

#### Redis + RedisInsight

```bash
make redis-start       # Inicia Redis + RedisInsight
make redis-stop        # Para Redis + RedisInsight

# URLs:
# Redis: localhost:6379
# RedisInsight: http://localhost:5540
```

#### Firebird

```bash
make firebird-start    # Inicia Firebird
make firebird-stop     # Para Firebird

# URL: localhost:3050
```

### 3. Comandos Gerais

```bash
make help              # Ver todos os comandos disponíveis
make setup             # Configuração inicial do ambiente
make status            # Status de todos os serviços
make stop-all          # Para todos os serviços ativos
make logs SERVICE=nome # Ver logs de um serviço específico
make clean             # Limpeza completa (preserva rede externa)
```

## 🔐 Credenciais de Acesso

Todas as credenciais são geradas automaticamente e armazenadas no arquivo `.env`.

### Visualizar credenciais:

```bash
cat .env | grep -E "(USER|PASSWORD|DATABASE)"
```

### Conectar via linha de comando:

**PostgreSQL:**

```bash
# Usar credenciais do .env automaticamente
make postgres-shell

# Ou conectar manualmente
psql -h localhost -p 5432 -U postgres -d dev_database
```

**MySQL:**

```bash
# Usar credenciais do .env automaticamente
make mysql-shell

# Ou conectar manualmente
mysql -h localhost -P 3306 -u mysql_user -p
```

**MariaDB:**

```bash
# Usar credenciais do .env automaticamente
make mariadb-shell

# Ou conectar manualmente
mysql -h localhost -P 3307 -u mariadb_user -p
```

**MongoDB:**

```bash
# Usar credenciais do .env automaticamente
make mongodb-shell

# Ou conectar manualmente
mongosh "mongodb://admin:senha@localhost:27017"
```

**Redis:**

```bash
# Usar credenciais do .env automaticamente
make redis-shell

# Ou conectar manualmente
redis-cli -h localhost -p 6379 -a sua_senha
```

## 🌐 Interfaces Web

| Interface         | URL                   | Suporta        | Credenciais                       |
| ----------------- | --------------------- | -------------- | --------------------------------- |
| **pgAdmin4**      | http://localhost:5050 | PostgreSQL     | Ver arquivo .env                  |
| **Adminer**       | http://localhost:8080 | MySQL, MariaDB | Sistema/servidor/usuário do banco |
| **Mongo Express** | http://localhost:8081 | MongoDB        | Ver arquivo .env                  |
| **RedisInsight**  | http://localhost:5540 | Redis          | Conexão automática configurada    |

### Como acessar as interfaces:

**pgAdmin4 (PostgreSQL):**

- URL: http://localhost:5050
- Email: Definido em `PGADMIN_EMAIL` (.env)
- Senha: Definida em `PGADMIN_PASSWORD` (.env)

**Adminer (MySQL/MariaDB):**

- URL: http://localhost:8080
- Sistema: MySQL ou MariaDB
- Servidor: mysql ou mariadb
- Usuário: Conforme definido no .env
- Senha: Conforme definido no .env

**Mongo Express (MongoDB):**

- URL: http://localhost:8081
- Usuário: Definido em `MONGO_EXPRESS_USER` (.env)
- Senha: Definida em `MONGO_EXPRESS_PASSWORD` (.env)

**RedisInsight (Redis):**

- URL: http://localhost:5540
- Conexão: Configurada automaticamente para conectar no Redis
- Autenticação: Usa a senha definida em `REDIS_PASSWORD` (.env)

## 📁 Estrutura de Arquivos

```
dabases/
├── docker-compose.yml    # Definições dos serviços
├── Makefile             # Comandos por contexto
├── start.sh             # Script de configuração inicial
├── stop.sh              # Script para parar serviços
├── generate-passwords.sh # Gerador de senhas seguras
├── .env                 # Variáveis de ambiente (auto-gerado)
├── .env.example         # Modelo de configuração
├── .gitignore           # Arquivos ignorados pelo Git
├── configs/             # Configurações dos bancos
│   ├── mysql/conf.d/
│   └── redis/
└── data/                # Dados persistentes (ignorado pelo Git)
    ├── postgres/
    ├── mysql/
    ├── mariadb/
    ├── mongodb/
    ├── redis/
    ├── redisinsight/
    ├── firebird/
    └── pgadmin/
```

## 🔧 Configuração Avançada

### Regenerar Senhas

```bash
# Gerar novas senhas seguras
make passwords
# ou
./generate-passwords.sh
```

### Variáveis de Ambiente Personalizadas

Edite o arquivo `.env` para personalizar:

- Portas dos serviços
- Credenciais de acesso
- Configurações específicas dos bancos

### Rede Externa

O projeto utiliza uma rede externa `development_environment` que é compartilhada entre aplicações:

- Criada automaticamente pelo `./start.sh`
- Preservada durante limpezas (`make clean`)
- Permite comunicação entre diferentes projetos Docker

## 🐛 Resolução de Problemas

### Porta já em uso

```bash
# Verificar quais serviços estão rodando
make status

# Parar serviços conflitantes
make stop-all

# Verificar processos nas portas
lsof -i :5432  # PostgreSQL
lsof -i :3306  # MySQL
lsof -i :27017 # MongoDB
```

### Logs de depuração

```bash
# Ver logs de um serviço específico
make logs SERVICE=postgres

# Ver logs em tempo real
docker compose logs -f postgres

# Ver logs de todos os serviços
docker compose logs
```

### Resetar ambiente

```bash
# Parar todos os serviços e limpar (preserva rede)
make clean

# Reconfigurar do zero
./start.sh

# Regenerar senhas
make passwords
```

### Problemas de permissão

```bash
# Corrigir permissões dos diretórios de dados
sudo chown -R $USER:$USER data/

# Verificar se o Docker está funcionando
docker --version
docker compose --version
```

## 📚 Exemplos de Uso

### Desenvolvimento Full-Stack

```bash
# Backend com PostgreSQL + Frontend com cache Redis
make postgres-start
make redis-start
```

### Testes de Migração

```bash
# Testar migração MySQL → PostgreSQL
make mysql-start
make postgres-start
```

### Desenvolvimento Mobile

```bash
# API com MongoDB
make mongodb-start
```

## 🚦 Status e Monitoramento

```bash
# Ver status geral
make status

# Verificar saúde dos serviços
docker compose ps

# Monitorar recursos
docker stats
```

## ⚙️ Requisitos do Sistema

- **Docker Engine**: 20.10 ou superior
- **Docker Compose**: 2.0 ou superior
- **Make**: Para executar comandos
- **Bash**: Shell para scripts
- **Memória RAM**: 2GB+ disponível
- **Espaço em disco**: 5GB+ para dados dos bancos

### Verificar Requisitos

```bash
# Verificar versões instaladas
docker --version
docker compose --version
make --version

# Verificar recursos do sistema
free -h              # Memória disponível
df -h .              # Espaço em disco
```

## 🤝 Contribuindo

1. Fork o projeto
2. Crie uma branch para sua feature
3. Commit suas mudanças
4. Push para a branch
5. Abra um Pull Request

## 📄 Licença

Este projeto está sob a licença MIT. Veja o arquivo `LICENSE` para detalhes.

---

## 🎯 Resumo Rápido

1. **Primeira vez**: `./start.sh` (configura tudo)
2. **Usar PostgreSQL**: `make postgres-start` → http://localhost:5050
3. **Usar MySQL**: `make mysql-start` → http://localhost:8080
4. **Ver status**: `make status`
5. **Parar tudo**: `make stop-all`
6. **Ajuda**: `make help`

**💡 Dica**: Use `make help` para ver todos os comandos disponíveis a qualquer momento!
