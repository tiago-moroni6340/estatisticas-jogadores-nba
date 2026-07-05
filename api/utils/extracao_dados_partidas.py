import asyncio
import json
from datetime import datetime
from cachetools import TTLCache
from sqlalchemy.orm import Session
from api.dependencies.dependencies import pegar_session
from contextlib import contextmanager
from api.models.models import StatsRegularSeason, StatsTotalRegularSeason, StatsSeasonPlayoff, StatsTotalPlayoff
from nba_api.stats.endpoints import scoreboardv2


pegar_session_ctx = contextmanager(pegar_session)

cache_jogos = TTLCache(maxsize=120, ttl=3600)
cache_linha_tempo = TTLCache(maxsize=200, ttl=600)


datas_em_execucao = set()
jogadores_em_execucao = set()

async def executar_rust_partidas(data_str: str) -> list:
    """Executa o binário compilado em Rust e captura o JSON retornado no stdout."""
    if data_str in datas_em_execucao:
        print(f"[{datetime.now()}] Aviso: Extração para {data_str} já está rodando. Pulando.")
        return []
    
    try:
        datas_em_execucao.add(data_str)
        process = await asyncio.create_subprocess_exec(
            r"C:\Users\moron\Documents\nba_stats\target\release\seu_programa_rust.exe", 
            data_str,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE
        )
        
        stdout, stderr = await process.communicate()
        
        if process.returncode != 0:
            print(f"Erro no módulo Rust: {stderr.decode().strip()}")
            return []
            
        saida = stdout.decode().strip()
        if not saida or saida == "[]":
            return []
            
        return json.loads(saida)
        
    finally:
        datas_em_execucao.remove(data_str)
        
async def executar_rust_linha_tempo(player_id: int, temporada: str = "2025-26") -> dict:
    """
    Executa o binário Rust passando o Player ID e a Temporada como argumentos,
    retornando o dicionário JSON gerado pelo stdout.
    """
    chave_execucao = f"{player_id}_{temporada}"
    
    if chave_execucao in jogadores_em_execucao:
        print(f"[{datetime.now()}] Aviso: Busca para Player {player_id} ({temporada}) já está rodando. Pulando.")
        return {}

    try:
        jogadores_em_execucao.add(chave_execucao)
        
        
        player_id_str = str(player_id)
        
     
        caminho_binario = r"C:\Users\moron\Documents\nba_stats\target\release\seu_programa_rust.exe"
        
        process = await asyncio.create_subprocess_exec(
            caminho_binario, 
            player_id_str,
            temporada,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE
        )
        
        stdout, stderr = await process.communicate()
        
        if process.returncode != 0:
            print(f"Erro no módulo Rust (Linha do Tempo): {stderr.decode().strip()}")
            return {}
            
        saida = stdout.decode().strip()
        if not saida or saida == "[]":
            return {}
            
        return json.loads(saida)
        
    finally:
        jogadores_em_execucao.remove(chave_execucao)

def verificar_se_ha_jogos_hoje() -> bool:
    """Usa a nba_api para verificar se o calendário de hoje possui partidas."""
    try:
        data_hoje = datetime.now().strftime("%Y-%m-%d")
        sb = scoreboardv2.ScoreboardV2(game_date=data_hoje, league_id="00", day_offset="0")
        jogos = sb.game_header.get_dict()
        
        
        return len(jogos.get("data", [])) > 0
    except Exception as e:
        print(f"Erro ao consultar a nba_api: {e}")
        
        return True

async def loop_monitoramento_automatico():
    """Tarefa agendada que roda a cada 1 minuto para monitorar jogos ativos."""
    agora = datetime.now()
    data_hoje = agora.strftime("%m/%d/%Y")
    
    
    if not (19 <= agora.hour or agora.hour <= 3):
        return

    
    if not verificar_se_ha_jogos_hoje():
        print(f"[{agora}] Calendário checado via nba_api: Sem jogos para hoje.")
        return

    print(f"[{agora}] Jogos detectados no calendário. Iniciando ciclo de atualização...")
    
    
    dados_atualizados = await executar_rust_partidas(data_hoje)
    
    if dados_atualizados:
        
        cache_jogos[data_hoje] = dados_atualizados

        with pegar_session_ctx() as db_session:
            
            processar_atualizacao_automatica(db_session, dados_atualizados)


live_game_tracker = {}

def parse_minutos_para_inteiro(minutos_str: str) -> int:
    """
    Converte a string de minutos do JSON (ex: "35:00") para inteiro (35).
    """
    if not minutos_str or ':' not in minutos_str:
        return 0
    minutos, _ = minutos_str.split(':')
    return int(minutos)

def processar_atualizacao_automatica(session: Session, json_rust: dict):
    """
    Recebe a sessão do banco e o JSON do Rust.
    Atualiza as estatísticas de Temporada e Carreira apenas aplicando a diferença (delta).
    """
    jogos = json_rust.get("jogos", []) 
    
    for jogo in jogos:
        game_id = jogo.get("game_id") 
        season = jogo.get("season") 
        tipo_jogo = jogo.get("tipo_jogo") 

        
        if tipo_jogo == "Regular": 
            TabelaTemporada = StatsRegularSeason
            TabelaCarreira = StatsTotalRegularSeason
        elif tipo_jogo == "Playoffs": 
            TabelaTemporada = StatsSeasonPlayoff
            TabelaCarreira = StatsTotalPlayoff
        else:
            continue 

        for jogador in jogo.get("jogadores", []): 
            player_id = jogador.get("nba_player_id") 
            team_abbr = jogador.get("time_jogador") 
            
            pts_atuais = jogador.get("pts", 0) 
            ast_atuais = jogador.get("ast", 0) 
            reb_atuais = jogador.get("reb", 0) 
            
           
            min_atuais = parse_minutos_para_inteiro(jogador.get("minutos", "0:0")) 

            
            chave_tracker = (game_id, player_id)
            stats_anteriores = live_game_tracker.get(chave_tracker, {"pts": 0, "ast": 0, "reb": 0, "min": 0, "gp": 0})
            
            delta_pts = pts_atuais - stats_anteriores["pts"]
            delta_ast = ast_atuais - stats_anteriores["ast"]
            delta_reb = reb_atuais - stats_anteriores["reb"]
            delta_min = min_atuais - stats_anteriores["min"]
            
            
            delta_gp = 1 if stats_anteriores["gp"] == 0 else 0

            
            if delta_pts == 0 and delta_ast == 0 and delta_reb == 0 and delta_min == 0 and delta_gp == 0:
                continue

           
            live_game_tracker[chave_tracker] = {
                "pts": pts_atuais, "ast": ast_atuais, "reb": reb_atuais, "min": min_atuais, "gp": 1
            }

            
            stat_temp = session.query(TabelaTemporada).filter_by(
                nba_player_id=player_id, 
                season_id=season, 
                team_abbreviation=team_abbr
            ).first()

            if not stat_temp:
                stat_temp = TabelaTemporada(
                    nba_player_id=player_id, season_id=season, team_abbreviation=team_abbr,
                    player_age=0, gp=0, gs=0, min=0, pts=0, ast=0, reb=0
                )
                session.add(stat_temp)

            stat_temp.pts += delta_pts
            stat_temp.ast += delta_ast
            stat_temp.reb += delta_reb
            stat_temp.min += delta_min
            stat_temp.gp += delta_gp

            
            stat_carreira = session.query(TabelaCarreira).filter_by(nba_player_id=player_id).first()
            
            if not stat_carreira:
                stat_carreira = TabelaCarreira(
                    nba_player_id=player_id, gp=0, gs=0, min=0, pts=0, ast=0, reb=0
                )
                session.add(stat_carreira)

            stat_carreira.pts += delta_pts
            stat_carreira.ast += delta_ast
            stat_carreira.reb += delta_reb
            stat_carreira.min += delta_min
            stat_carreira.gp += delta_gp

    
    session.commit()