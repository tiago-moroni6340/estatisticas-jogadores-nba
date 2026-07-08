import asyncio
import json
import subprocess
import platform
from datetime import datetime
from cachetools import TTLCache
from sqlalchemy.orm import Session
from api.dependencies.dependencies import pegar_session
from contextlib import contextmanager
from api.models.models import StatsRegularSeason, StatsTotalRegularSeason, StatsSeasonPlayoff, StatsTotalPlayoff
from nba_api.stats.endpoints import scoreboardv2
from pathlib import Path



pegar_session_ctx = contextmanager(pegar_session)

cache_jogos = TTLCache(maxsize=120, ttl=3600)
cache_linha_tempo = TTLCache(maxsize=200, ttl=600)

datas_em_execucao = set()
jogadores_em_execucao = set()

rotinas_em_execucao = {
    "estatisticas": False,
    "jogadores": False,
    "perfis": False
}

def resource_path(*path_segments: str) -> Path:
    
    BASE_DIR = Path(__file__).resolve().parents[2]
    
    return BASE_DIR.joinpath(*path_segments)

def obter_sufixo_sistema() -> str:
    return ".exe" if platform.system() == "Windows" else ""

sufixo = obter_sufixo_sistema()

async def executar_rust_partidas(data_str: str) -> list:
    
    if data_str in datas_em_execucao:
        print(f"[{datetime.now()}] Aviso: Extração para {data_str} já está rodando. Pulando.")
        return []

    try:
        caminho_modulo_rust = resource_path("target", "release", f"buscar_partidas{sufixo}")

        datas_em_execucao.add(data_str)
       
        def rodar_subprocesso():
            return subprocess.run(
                [str(caminho_modulo_rust), data_str],
                capture_output=True,
                text=True, 
                encoding="utf-8",
                check=False
            )

     
        process = await asyncio.to_thread(rodar_subprocesso)
        
        if process.returncode != 0:
            print(f"Erro no módulo Rust: {process.stderr.strip()}")
            return []
            
        saida = process.stdout.strip()
        if not saida or saida == "[]":
            return []
            
        return json.loads(saida)
        
    finally:
        datas_em_execucao.remove(data_str)
        
async def executar_rust_linha_tempo(player_id: int, temporada: str = "2025-26") -> dict:
    
    chave_execucao = f"{player_id}_{temporada}"

    
    if chave_execucao in jogadores_em_execucao:
        print(f"[{datetime.now()}] Aviso: Busca para Player {player_id} ({temporada}) já está rodando. Pulando.")
        return {}

    try:
        jogadores_em_execucao.add(chave_execucao)
        
        player_id_str = str(player_id)
        
        caminho_modulo_rust = resource_path("target", "release", f"buscar_historico_partidas_jogadores{sufixo}")

        def rodar_subprocesso():
            return subprocess.run(
                [str(caminho_modulo_rust), player_id_str, temporada],
                capture_output=True,
                text=True, 
                encoding="utf-8",
                check=False
            )

        
        process = await asyncio.to_thread(rodar_subprocesso)
        
        
        if process.returncode != 0:
            print(f"Erro no módulo Rust (Linha do Tempo): {process.stderr.strip()}")
            return {}
            
        saida = process.stdout.strip()
        if not saida or saida == "[]":
            return {}
            
        return json.loads(saida)
        
    finally:
        jogadores_em_execucao.remove(chave_execucao)

async def executar_rust_buscar_jogadores() -> dict:
    """Executa o pipeline Rust de busca de jogadores ativos."""
    if rotinas_em_execucao["jogadores"]:
        return {"status": "ocupado", "mensagem": "A atualização de jogadores já está em andamento."}
    
    try:
        rotinas_em_execucao["jogadores"] = True
        caminho_modulo_rust = resource_path("target", "release", f"buscar_jogadores{sufixo}")

        def rodar_subprocesso():
            return subprocess.run(
                [str(caminho_modulo_rust)],
                capture_output=True,
                text=True,
                encoding="utf-8", 
                check=False
            )

        process = await asyncio.to_thread(rodar_subprocesso)
        
        if process.returncode != 0:
            print(f"Erro no módulo Rust (Jogadores): {process.stderr.strip()}")
            return {"status": "erro", "detalhe": process.stderr.strip()}
            
        return {"status": "sucesso", "log": process.stdout.strip()}
        
    finally:
        rotinas_em_execucao["jogadores"] = False

async def executar_rust_buscar_perfis() -> dict:
    """Executa o pipeline Rust de busca de perfis dos jogadores."""
    if rotinas_em_execucao["perfis"]:
        return {"status": "ocupado", "mensagem": "A atualização de perfis já está em andamento."}
    
    try:
        rotinas_em_execucao["perfis"] = True

        caminho_modulo_rust = resource_path("target", "release", f"buscar_perfis{sufixo}")

        def rodar_subprocesso():
            return subprocess.run(
                [str(caminho_modulo_rust)],
                capture_output=True,
                text=True,
                encoding="utf-8", 
                check=False
            )

        
        process = await asyncio.to_thread(rodar_subprocesso)
        
        
        if process.returncode != 0:
            print(f"Erro no módulo Rust (Perfis): {process.stderr.strip()}")
            return {"status": "erro", "detalhe": process.stderr.strip()}
            
        return {"status": "sucesso", "log": process.stdout.strip()}
        
    finally:
        rotinas_em_execucao["perfis"] = False

async def executar_rust_buscar_estatisticas() -> dict:
    """Executa o pipeline Rust de atualização de estatísticas (PostSeason/RegularSeason)."""
    if rotinas_em_execucao["estatisticas"]:
        return {"status": "ocupado", "mensagem": "A atualização de estatísticas já está em andamento."}
    
    try:
        rotinas_em_execucao["estatisticas"] = True
        
        caminho_modulo_rust = resource_path("target", "release", f"buscar_estatisticas{sufixo}")

        def rodar_subprocesso():
            return subprocess.run(
                [str(caminho_modulo_rust)],
                capture_output=True,
                text=True,
                encoding="utf-8", 
                check=False
            )

       
        process = await asyncio.to_thread(rodar_subprocesso)
        
        
        if process.returncode != 0:
            print(f"Erro no módulo Rust (Estatísticas): {process.stderr.strip()}")
            return {"status": "erro", "detalhe": process.stderr.strip()}
            
        return {"status": "sucesso", "log": process.stdout.strip()}
        
    finally:
        rotinas_em_execucao["estatisticas"] = False

