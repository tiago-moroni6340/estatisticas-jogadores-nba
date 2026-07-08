from fastapi import FastAPI
from api.routes.stats_routes import nba_router
from api.routes.auth_routes import auth_router
from fastapi.middleware.cors import CORSMiddleware

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"], 
)

app.include_router(nba_router)
app.include_router(auth_router)
