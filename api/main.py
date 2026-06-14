from fastapi import FastAPI
from api.routes import nba_router

app = FastAPI()

app.include_router(nba_router)