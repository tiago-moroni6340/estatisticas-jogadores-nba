from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from api.dependencies import pegar_session
from api.models import DadosJogador, EstatisticasJogadorCarreira, EstatisticasJogadorTemporada

nba_router = APIRouter(prefix='/nba_dados')

@nba_router.get("/")
async def status_api():
    return {'Mensagem': 'API está ativa'}

@nba_router.get("/perfil_jogadores")
async def listar_perfil_jogadores(session: Session = Depends(pegar_session)):
    jogadores = session.query(DadosJogador).all()

    return {"players_personal_data": jogadores}

@nba_router.get("/perfil_jogadores/{nba_player_id}")
async def listar_perfil_jogador(nba_player_id: int, session: Session = Depends(pegar_session)):
    jogador = session.query(DadosJogador).filter(DadosJogador.nba_player_id == nba_player_id).first()
    if not jogador:
        raise HTTPException(status_code=400, detail='Jogador não encontrado')

    return {"player_personal_data": jogador}

@nba_router.get("/player_stats/carreira/{nba_player_id}")
async def estatistica_carreira_jogador(nba_player_id: int, session: Session = Depends(pegar_session)):
    jogador = session.query(EstatisticasJogadorCarreira).filter(EstatisticasJogadorCarreira.nba_player_id == nba_player_id).first()
    if not jogador:
        raise HTTPException(status_code=400, detail='Jogador não encontrado')

    return {"player_personal_data": jogador}

@nba_router.get("/player_stats/temporada/{nba_player_id}")
async def estatistica_temporada_jogador(nba_player_id: int, session: Session = Depends(pegar_session)):
    # 1. Busca todas as temporadas do jogador
    temporadas = session.query(EstatisticasJogadorTemporada).filter(
        EstatisticasJogadorTemporada.nba_player_id == nba_player_id
    ).all()
    
    # 2. Se a lista vier vazia, lança a exceção
    if not temporadas:
        raise HTTPException(status_code=404, detail='Estatísticas do jogador não encontradas')

    # 3. Transforma cada objeto em um dicionário contendo apenas as colunas da tabela
    # Isso ignora completamente os relationships que causam a recursão infinita
    dados_formatados = []
    for temporada in temporadas:
        dados_temporada = {coluna.name: getattr(temporada, coluna.name) for coluna in temporada.__table__.columns}
        dados_formatados.append(dados_temporada)

    # 4. Retorna a lista limpa
    return {"player_season_stats": dados_formatados}

