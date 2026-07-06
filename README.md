# 🏀 Estatísticas Jogadores NBA (API)

Uma API robusta e de alta performance para extração, monitoramento e consulta de dados estatísticos da NBA. O sistema utiliza uma arquitetura híbrida, combinando a agilidade e facilidade de construção de APIs do **Python (FastAPI)** com a performance bruta e concorrência do **Rust** para processamento pesado e integração com o banco de dados.

Este projeto demonstra conceitos avançados de engenharia de software, incluindo integrações entre múltiplas linguagens, processamento assíncrono, autenticação segura e agendamento de tarefas em background (workers), servindo como uma excelente demonstração de arquitetura de backend.

---

## 🚀 Arquitetura do Sistema

O sistema é dividido em duas camadas principais:

1. **Backend API (Python / FastAPI):**
   - Gerencia a autenticação de usuários (JWT, senhas criptografadas com Bcrypt).
   - Disponibiliza os endpoints RESTful para consumo das estatísticas (perfis, totais de carreira, médias de temporada, rankings e comparações).
   - Possui um serviço de agendamento (`APScheduler`) que executa um monitoramento automático a cada minuto para atualizar dados de jogos ao vivo.
   - Serve como ponte de comunicação entre o usuário final e o banco de dados.

2. **Data Extraction & Processing Pipelines (Rust):**
   - Scripts compilados otimizados com `Tokio` (async) e `reqwest` para consumir a API pública de status da NBA de forma concorrente.
   - Responsável pelo fluxo pesado de extração (ETL): busca de jogos, perfis de jogadores, gamelogs históricos e estatísticas de temporada (regular e playoffs).
   - Utiliza `SQLx` para interagir diretamente e de forma segura com o banco de dados PostgreSQL, implementando rotinas de `UPSERT` para evitar duplicação de dados.

A comunicação entre a API Python e os módulos Rust é feita via subprocessos (execução dos binários compilados), com os dados sendo trafegados de forma estruturada via `stdout` no formato JSON ou inseridos diretamente no banco.

---

## 🛠️ Tecnologias Utilizadas

### Python (API & Regras de Negócio)
- **[FastAPI](https://fastapi.tiangolo.com/):** Framework web de alta performance.
- **[SQLAlchemy](https://www.sqlalchemy.org/):** ORM para consultas no banco de dados.
- **[Pydantic](https://docs.pydantic.dev/):** Validação de dados e tipagem.
- **[Passlib & Python-jose]:** Hashing de senhas e geração/verificação de tokens JWT.
- **[APScheduler]:** Agendamento de rotinas automatizadas em background.

### Rust (Workers de Extração)
- **[Tokio](https://tokio.rs/):** Runtime assíncrono para I/O e concorrência.
- **[Reqwest](https://docs.rs/reqwest/latest/reqwest/):** Cliente HTTP assíncrono.
- **[SQLx](https://github.com/launchbadge/sqlx):** Toolkit assíncrono para PostgreSQL.
- **[Serde](https://serde.rs/):** Serialização e desserialização de dados JSON.

---

## ⚙️ Configuração e Instalação

### Pré-requisitos
- **Python** >= 3.10
- **Rust** e Cargo (Toolchain atualizada)
- Banco de dados **PostgreSQL** ativo.

### 1. Clonando e Configurando o Ambiente

```bash
# Clone o repositório
git clone <url-do-repositorio>
cd estatisticas-jogadores-nba

# Crie e ative um ambiente virtual Python
python -m venv venv
source venv/bin/activate  # Linux/Mac
venv\Scripts\activate  # Windows

# Instale as dependências do Python
pip install -e .

2. Compilando os Módulos em Rust
Os binários de extração precisam ser compilados antes de executar a API.

Bash
cargo build --release
Isso irá gerar os binários na pasta target/release/, que serão invocados pela API Python.

3. Variáveis de Ambiente
Crie um arquivo .env na raiz do projeto contendo as seguintes variáveis:

Ini, TOML
# Configurações de Segurança e JWT
SECRET_KEY=sua_chave_secreta_aqui
ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=30

# Banco de Dados
DATABASE_URL=postgresql://usuario:senha@localhost:5432/nba_db
DATABASE_URL_RUST=postgres://usuario:senha@localhost:5432/nba_db

# Integração Email (Opcional, conforme uso no código)
RESEND_API_KEY=sua_chave_resend
4. Executando a API
Inicie o servidor localmente com Uvicorn:

Bash
uvicorn api.main:app --reload
A API estará disponível em http://localhost:8000. A documentação interativa (Swagger UI) pode ser acessada em http://localhost:8000/docs.

📡 Principais Endpoints
Autenticação (/auth)
POST /auth/criar_conta: Criação de novo usuário com validação de força de senha.

POST /auth/login: Autenticação e retorno de access_token e refresh_token.

GET /auth/refresh: Atualização do token de acesso.

Dados da NBA (/nba_dados)
(Nota: a maioria das rotas requer autenticação via token Bearer)

Consultas e Estatísticas:

GET /perfil_jogadores: Lista o perfil de todos os jogadores armazenados.

GET /player_stats/career_total/{id}: Retorna a somatória consolidada das estatísticas de toda a carreira de um jogador (Temporada Regular + Playoffs).

GET /player_stats/ranking: Gera um ranking dinâmico com base em métricas específicas (pontos, assistências, rebotes, etc.), temporada e etapa (Regular, Playoffs ou Total).

GET /player_stats/compare: Permite a comparação direta de desempenho entre dois jogadores em uma temporada específica, apontando quem tem vantagem em cada métrica.

GET /player_stats/timeline: Busca a linha do tempo dos últimos 10 jogos de um atleta.

Pipelines de Atualização de Banco (ETL Triggers):

POST /update_db/players: Aciona o pipeline Rust para buscar novos jogadores ativos.

POST /update_db/profiles: Atualiza os dados biográficos dos jogadores.

POST /update_db/statistics: Baixa e sincroniza as estatísticas pendentes de carreira.

👨‍💻 Autores
Tiago Moroni Silva Ferreira

Thiago Ianarelli Linhares Couto

Licenciado sob a Licença MIT.
