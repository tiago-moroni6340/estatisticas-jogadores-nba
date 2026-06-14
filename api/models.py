from sqlalchemy import create_engine, Column, String, Integer, Float,Boolean, ForeignKey, JSON, Numeric, Enum as sqlalchemy_Enum
from sqlalchemy.orm import declarative_base

db = create_engine("sqlite:///nba_dados.db")

Base = declarative_base()

class DadosJogador(Base):
    __tablename__ = 'jogadores_perfil'
    
    id = Column('id', Integer, primary_key=True, autoincrement=True)
    nba_player_id = Column('nba_player_id', Integer, unique=True)
    nome_completo = Column('nome_completo', String)
    data_nascimento = Column('data_nascimento', String)
    escola = Column('escola', String)
    pais = Column('pais', String)
    altura = Column('altura', String)
    peso = Column('peso', String)
    posicao = Column('posicao', String)
    numero_camisa = Column('numero_camisa', String)
    anos_experiencia = Column('anos_experiencia', String)
    time_atual = Column('time_atual', String)

class EstatisticasJogadorCarreira(Base):
    __tablename__ = 'totais_carreira_regular'
    
    id = Column('id', Integer, primary_key=True, autoincrement=True)
    nba_player_id = Column('nba_player_id', Integer, unique=True)
    gp = Column('gp', Integer)
    gs = Column('gs', Integer)
    min = Column('min', Integer)
    pts = Column('pts', Integer)
    ast = Column('ast', Integer)
    reb = Column('reb', Integer)

class EstatisticasJogadorTemporada(Base):
    __tablename__ = 'stats_temporada_regular'
    
    id = Column('id', Integer, primary_key=True, autoincrement=True)
    nba_player_id = Column('nba_player_id', Integer, unique=True)
    season_id = Column('season_id', String, unique=True)
    team_abbreviation = Column('team_abbreviation', String, unique=True)
    player_age = Column('player_age', Integer)
    gp = Column('gp', Integer)
    gs = Column('gs', Integer)
    min = Column('min', Integer)
    pts = Column('pts', Integer)
    ast = Column('ast', Integer)
    reb = Column('reb', Integer)

    