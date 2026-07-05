from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import func, desc
from sqlalchemy.orm import Session
from api.dependencies.dependencies import pegar_session, verificar_token
from api.models.models import Usuario, DadosJogador, StatsRegularSeason, StatsSeasonPlayoff, StatsTotalPlayoff, StatsTotalRegularSeason, StatsGame
from typing import Literal

nba_router = APIRouter(prefix='/nba_dados')

@nba_router.get("/")
async def status_api():
    return {'Mensagem': 'API está ativa'}

@nba_router.get("/perfil_jogadores")
async def listar_perfil_jogadores(session: Session = Depends(pegar_session), usuario: Usuario = Depends(verificar_token)):
    jogadores = session.query(DadosJogador).all()

    return {"players_personal_data": jogadores}

@nba_router.get("/perfil_jogadores/{nba_player_id}")
async def listar_perfil_jogador(nba_player_id: int, session: Session = Depends(pegar_session), usuario: Usuario = Depends(verificar_token)):
    jogador = session.query(DadosJogador).filter(DadosJogador.nba_player_id == nba_player_id).first()
    if not jogador:
        raise HTTPException(status_code=400, detail='Jogador não encontrado')

    return {"player_personal_data": jogador}

@nba_router.get("/player_stats/career_regular_season/{nba_player_id}")
async def estatistica_total_regular_season(nba_player_id: int, session: Session = Depends(pegar_session), usuario: Usuario = Depends(verificar_token)):
    stats_regular_season = session.query(StatsTotalRegularSeason).filter(StatsTotalRegularSeason.nba_player_id == nba_player_id).first()
    if not stats_regular_season:
        raise HTTPException(status_code=400, detail='Jogador não encontrado')

    return {"player_stats_regular_season": stats_regular_season}

@nba_router.get("/player_stats/career_playoffs/{nba_player_id}")
async def estatistica_total_playoffs(nba_player_id: int, session: Session = Depends(pegar_session), usuario: Usuario = Depends(verificar_token)):
    stats_playoffs = session.query(StatsTotalPlayoff).filter(StatsTotalPlayoff.nba_player_id == nba_player_id).first()
    if not stats_playoffs:
        raise HTTPException(status_code=400, detail='Jogador não encontrado')

    return {"player_stats_playoffs": stats_playoffs}

@nba_router.get("/player_stats/career_total/{nba_player_id}")
async def estatistica_total_carreira(
    nba_player_id: int, 
    session: Session = Depends(pegar_session), 
    usuario: Usuario = Depends(verificar_token)
):
    
    reg_stats = session.query(
        func.sum(StatsTotalRegularSeason.pts).label("pontos"),
        func.sum(StatsTotalRegularSeason.ast).label("assistencias"),
        func.sum(StatsTotalRegularSeason.reb).label("rebotes"),
        func.sum(StatsTotalRegularSeason.min).label("minutos"),
        func.sum(StatsTotalRegularSeason.gs).label("jogos_iniciados"),
        func.sum(StatsTotalRegularSeason.gp).label("jogos_disputados")
       
    ).filter(StatsTotalRegularSeason.nba_player_id == nba_player_id).first()

   
    playoff_stats = session.query(
        func.sum(StatsTotalPlayoff.pts).label("pontos"),
        func.sum(StatsTotalPlayoff.ast).label("assistencias"),
        func.sum(StatsTotalPlayoff.reb).label("rebotes"),
        func.sum(StatsTotalPlayoff.min).label("minutos"),
        func.sum(StatsTotalPlayoff.gs).label("jogos_iniciados"),
        func.sum(StatsTotalPlayoff.gp).label("jogos_disputados")
        
    ).filter(StatsTotalPlayoff.nba_player_id == nba_player_id).first()

    if not reg_stats.pontos and not playoff_stats.pontos:
        raise HTTPException(status_code=404, detail='Estatísticas do jogador não encontradas')

    total_stats = {
        "pontos": (reg_stats.pontos or 0) + (playoff_stats.pontos or 0),
        "assistencias": (reg_stats.assistencias or 0) + (playoff_stats.assistencias or 0),
        "rebotes": (reg_stats.rebotes or 0) + (playoff_stats.rebotes or 0),
        "minutos": (reg_stats.minutos or 0) + (playoff_stats.minutos or 0),
        "jogos_iniciados": (reg_stats.jogos_iniciados or 0) + (playoff_stats.jogos_iniciados or 0),
        "jogos_disputados": (reg_stats.jogos_disputados or 0) + (playoff_stats.jogos_disputados or 0),
    }

    return {"player_stats_total": total_stats}

@nba_router.get("/player_stats/regular_season/{nba_player_id}/{season}")
async def estatistica_regular_season_jogador(
    nba_player_id: int, 
    season: str, 
    session: Session = Depends(pegar_session),
    usuario: Usuario = Depends(verificar_token)
):
    temporadas = session.query(StatsRegularSeason).filter(
        StatsRegularSeason.nba_player_id == nba_player_id,
        StatsRegularSeason.season_id == season
    ).all()
    
    if not temporadas:
        raise HTTPException(status_code=404, detail='Estatísticas do jogador não encontradas')

    
    dados_formatados = [
        {coluna.name: getattr(temp, coluna.name) for coluna in temp.__table__.columns}
        for temp in temporadas
    ]
   
    return {"player_season_stats_regular_season": dados_formatados}

@nba_router.get("/player_stats/playoffs/{nba_player_id}/{season}")
async def estatistica_playoff_jogador(
    nba_player_id: int, 
    season: str, 
    session: Session = Depends(pegar_session),
    usuario: Usuario = Depends(verificar_token)
):
    temporadas = session.query(StatsSeasonPlayoff).filter(
        StatsSeasonPlayoff.nba_player_id == nba_player_id,
        StatsSeasonPlayoff.season_id == season
    ).all()
    
    if not temporadas:
        raise HTTPException(status_code=404, detail='Estatísticas do jogador não encontradas')

    
    dados_formatados = [
        {coluna.name: getattr(temp, coluna.name) for coluna in temp.__table__.columns}
        for temp in temporadas
    ]
   
    return {"player_season_stats_playoff": dados_formatados}

@nba_router.get("/player_stats/ranking")
async def ranking_estatisticas(
    season: str = Query(..., description="Ex: '2023-24'"),
    etapa: Literal["regular", "playoffs", "all"] = Query(..., description="Etapa da temporada"),
    tipo_estatistica: Literal["pts", "ast", "reb", "min"] = Query(..., description="Métrica do ranking"),
    limit: int = Query(10, description="Quantidade de jogadores no ranking"),
    session: Session = Depends(pegar_session),
    usuario: Usuario = Depends(verificar_token)
):
    
    colunas_validas = ["pts", "ast", "reb", "min"]
    if tipo_estatistica not in colunas_validas:
        raise HTTPException(status_code=400, detail="Estatística inválida.")

    
    if etapa == "regular":
        coluna_stat = getattr(StatsRegularSeason, tipo_estatistica)
        
        ranking = session.query(
            DadosJogador.nome_completo,
            DadosJogador.time_atual,
            coluna_stat.label("valor")
        ).join(
            StatsRegularSeason, StatsRegularSeason.nba_player_id == DadosJogador.nba_player_id
        ).filter(
            StatsRegularSeason.season_id == season
        ).order_by(
            desc(coluna_stat)
        ).limit(limit).all()

    elif etapa == "playoffs":
        coluna_stat = getattr(StatsSeasonPlayoff, tipo_estatistica)
        
        ranking = session.query(
            DadosJogador.nome_completo,
            DadosJogador.time_atual,
            coluna_stat.label("valor")
        ).join(
            StatsSeasonPlayoff, StatsSeasonPlayoff.nba_player_id == DadosJogador.nba_player_id
        ).filter(
            StatsSeasonPlayoff.season_id == season
        ).order_by(
            desc(coluna_stat)
        ).limit(limit).all()

    elif etapa == "all":
        
        coluna_reg = getattr(StatsRegularSeason, tipo_estatistica)
        coluna_play = getattr(StatsSeasonPlayoff, tipo_estatistica)

        
        ranking = session.query(
            DadosJogador.nome_completo,
            DadosJogador.time_atual,
            (func.coalesce(coluna_reg, 0) + func.coalesce(coluna_play, 0)).label("valor")
        ).outerjoin(
            StatsRegularSeason, StatsRegularSeason.nba_player_id == DadosJogador.nba_player_id
        ).outerjoin(
            StatsSeasonPlayoff, (StatsSeasonPlayoff.nba_player_id == DadosJogador.nba_player_id) & 
                                (StatsSeasonPlayoff.season_id == season)
        ).filter(
            StatsRegularSeason.season_id == season
        ).order_by(
            desc("valor")
        ).limit(limit).all()

    
    resultado_formatado = [
        {
            "posicao": index + 1,
            "nome": jogador.nome_completo,
            "time": jogador.time_atual,
            tipo_estatistica: jogador.valor
        }
        
        for index, jogador in enumerate(ranking)
    ]

    return {
        "season": season,
        "etapa": etapa,
        "tipo_estatistica": tipo_estatistica,
        "ranking": resultado_formatado
    }

@nba_router.get("/player_stats/compare")
async def comparar_jogadores(
    player_id_1: int = Query(..., description="ID do primeiro jogador"),
    player_id_2: int = Query(..., description="ID do segundo jogador"),
    season: str = Query(..., description="Temporada da comparação (Ex: '2023-24')"),
    etapa: Literal["regular", "playoffs", "all"] = Query(..., description="Etapa da temporada"),
    session: Session = Depends(pegar_session),
    usuario: Usuario = Depends(verificar_token)
):
    if player_id_1 == player_id_2:
        raise HTTPException(status_code=400, detail="Selecione dois jogadores diferentes para a comparação.")

    
    perfis = session.query(DadosJogador).filter(
        DadosJogador.nba_player_id.in_([player_id_1, player_id_2])
    ).all()
    
    if len(perfis) < 2:
        raise HTTPException(status_code=404, detail="Um ou ambos os jogadores não foram encontrados.")

    
    perfis_dict = {p.nba_player_id: {"nome": p.nome_completo, "time": p.time_atual} for p in perfis}


    metricas = ["gp", "gs", "min", "pts", "ast", "reb"]
    
    
    dados_jogadores = {
        player_id_1: {m: 0 for m in metricas},
        player_id_2: {m: 0 for m in metricas}
    }

    
    if etapa in ["regular", "all"]:
        stats_reg = session.query(StatsRegularSeason).filter(
            StatsRegularSeason.nba_player_id.in_([player_id_1, player_id_2]),
            StatsRegularSeason.season_id == season
        ).all()
        
        for s in stats_reg:
            for m in metricas:
                dados_jogadores[s.nba_player_id][m] += getattr(s, m, 0) or 0

    if etapa in ["playoffs", "all"]:
        stats_play = session.query(StatsSeasonPlayoff).filter(
            StatsSeasonPlayoff.nba_player_id.in_([player_id_1, player_id_2]),
            StatsSeasonPlayoff.season_id == season
        ).all()
        
        for s in stats_play:
            for m in metricas:
                dados_jogadores[s.nba_player_id][m] += getattr(s, m, 0) or 0

    
    comparacao_metricas = []
    for m in metricas:
        val1 = dados_jogadores[player_id_1][m]
        val2 = dados_jogadores[player_id_2][m]
        
        comparacao_metricas.append({
            "metrica": m.upper(),
            "jogador_1": val1,
            "jogador_2": val2,
            
            "vantagem": 1 if val1 > val2 else (2 if val2 > val1 else 0)
        })

    return {
        "season": season,
        "etapa": etapa,
        "jogadores": {
            "jogador_1": perfis_dict[player_id_1],
            "jogador_2": perfis_dict[player_id_2]
        },
        "estatisticas": comparacao_metricas
    }