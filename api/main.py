from fastapi import FastAPI
from api.routes.stats_routes import nba_router
from api.routes.auth_routes import auth_router
from contextlib import asynccontextmanager
from apscheduler.schedulers.asyncio import AsyncIOScheduler
from api.utils.extracao_dados_rust import loop_monitoramento_automatico
from fastapi.middleware.cors import CORSMiddleware

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Permite requisições de qualquer origem (inclusive do Flutter Web)
    allow_credentials=True,
    allow_methods=["*"],  # Libera todos os métodos (GET, POST, OPTIONS, DELETE, etc)
    allow_headers=["*"],  # Libera todos os cabeçalhos (Headers)
)

@asynccontextmanager
async def lifespan(app: FastAPI):
    
    scheduler = AsyncIOScheduler()
    
    scheduler.add_job(loop_monitoramento_automatico, 'interval', minutes=1)
    scheduler.start()
    print("Sistema de monitoramento automático (1 min) inicializado.")
    yield
    scheduler.shutdown()

app.include_router(nba_router)
app.include_router(auth_router)