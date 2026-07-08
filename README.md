# 🏀 NBA Player Statistics API

![Python](https://img.shields.io/badge/Python-3.10+-blue)
![Rust](https://img.shields.io/badge/Rust-Latest-orange)
![FastAPI](https://img.shields.io/badge/FastAPI-green)
![PostgreSQL](https://img.shields.io/badge/PostgreSQL-blue)
![License](https://img.shields.io/badge/License-MIT-yellow)

Uma API robusta para extração, processamento e consulta de estatísticas da NBA, combinando **FastAPI** e **Rust** para alta performance.

---

## 📑 Índice
- Funcionalidades
- Arquitetura
- Tecnologias
- Instalação
- Configuração
- Execução
- Endpoints
- Estrutura
- Autores
- Licença

## ✨ Funcionalidades

- 🔐 Autenticação JWT
- 👤 Perfis de jogadores
- 📊 Estatísticas de carreira
- 🏆 Rankings dinâmicos
- ⚖️ Comparação entre jogadores
- 📈 Timeline dos últimos jogos
- 🔄 Atualização automática via APScheduler
- ⚡ ETL concorrente em Rust

---

## 🚀 Arquitetura

| Camada | Responsabilidade |
|--------|------------------|
| FastAPI | API REST, autenticação e regras de negócio |
| Rust | ETL, scraping e processamento concorrente |
| PostgreSQL | Persistência dos dados |
| APScheduler | Atualizações automáticas |

```mermaid
flowchart LR
Cliente --> FastAPI
FastAPI --> PostgreSQL
FastAPI --> RustWorkers
RustWorkers --> NBAAPI[NBA Stats API]
```

---

## 🛠 Tecnologias

### Python
- FastAPI
- SQLAlchemy
- Pydantic
- Passlib
- python-jose
- APScheduler

### Rust
- Tokio
- Reqwest
- SQLx
- Serde

---

## ⚙️ Instalação

### Clone o repositório

```bash
git clone <url-do-repositorio>
cd estatisticas-jogadores-nba
```

### Ambiente virtual

```bash
python -m venv venv
```

Linux/macOS

```bash
source venv/bin/activate
```

Windows

```powershell
venv\Scripts\activate
```

### Dependências

```bash
pip install -e .
```

### Compile os workers Rust

```bash
cargo build --release
```

Os binários serão gerados em:

```text
target/release/
```

---

## 🔐 Configuração

Crie um arquivo `.env`:

```ini
SECRET_KEY=sua_chave_secreta
ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=30

DATABASE_URL=postgresql://usuario:senha@localhost:5432/nba_db
DATABASE_URL_RUST=postgres://usuario:senha@localhost:5432/nba_db

RESEND_API_KEY=sua_chave
```

---

## ▶️ Executando

```bash
uvicorn api.main:app --reload
```

API:

`http://localhost:8000`

Swagger:

`http://localhost:8000/docs`

---

## 📡 Endpoints

### Autenticação

| Método | Endpoint | Descrição |
|--------|----------|-----------|
| POST | `/auth/criar_conta` | Criar usuário |
| POST | `/auth/login` | Login |
| GET | `/auth/refresh` | Renovar token |

### Estatísticas

| Método | Endpoint |
|--------|----------|
| GET | `/perfil_jogadores` |
| GET | `/player_stats/career_total/{id}` |
| GET | `/player_stats/ranking` |
| GET | `/player_stats/compare` |
| GET | `/player_stats/timeline` |

### Atualização do banco

| Método | Endpoint |
|--------|----------|
| POST | `/update_db/players` |
| POST | `/update_db/profiles` |
| POST | `/update_db/statistics` |

---

## 📁 Estrutura do Projeto

```text
projeto/
├── api/
├── database/
├── models/
├── routers/
├── rust/
│   ├── update_players/
│   ├── update_profiles/
│   └── update_statistics/
├── tests/
├── .env
└── README.md
```

---

## 👨‍💻 Autores

- Tiago Moroni Silva Ferreira
- Thiago Ianarelli Linhares Couto

---

## 📄 Licença

Distribuído sob a licença MIT.
