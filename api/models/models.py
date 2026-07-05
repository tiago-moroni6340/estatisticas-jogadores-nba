from sqlalchemy import create_engine, Column, String, Integer, Float,Boolean, ForeignKey, JSON, Numeric, Enum as sqlalchemy_Enum
from sqlalchemy.orm import declarative_base

db = create_engine("sqlite:///nba_dados.db")

Base = declarative_base()

class Usuario(Base):
    __tablename__ = 'usuarios'

    id = Column('id', Integer, primary_key=True, autoincrement=True)
    nome = Column('nome', String)
    email = Column('email', String, nullable=False)
    data_nascimento = Column('data_nascimento',String)
    cidade = Column('cidade', String)
    estado = Column('estado', String)
    pais = Column('pais',String)
    celular = Column('celular',String)
    equipe = Column('equipe',String)
    cargo = Column('cargo', String)
    senha = Column('senha', String)
    ativo = Column('ativo', Boolean)
    is_verified = Column('is_verified', Boolean, default=False)
    verification_code = Column('verification_code', String)

    def __init__(self, 
                 nome, 
                 email, 
                 data_nascimento, 
                 cidade, 
                 estado, 
                 pais, 
                 celular, 
                 equipe, 
                 cargo, 
                 senha, 
                 is_verified = False, 
                 ativo=True):
        
        self.nome = nome
        self.email = email
        self.data_nascimento = data_nascimento
        self.cidade = cidade
        self.estado = estado
        self.pais = pais
        self.celular = celular
        self.equipe = equipe
        self.cargo = cargo
        self.senha = senha
        self.is_verified = is_verified
        self.ativo = ativo

class DadosJogador(Base):
    __tablename__ = 'jogadores_perfil'
    
    id = Column('id', Integer, primary_key=True, autoincrement=True)
    nba_player_id = Column('nba_player_id', Integer)
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

class StatsTotalRegularSeason(Base):
    __tablename__ = 'totais_carreira_regular'
    
    id = Column('id', Integer, primary_key=True, autoincrement=True)
    nba_player_id = Column('nba_player_id', Integer)
    gp = Column('gp', Integer)
    gs = Column('gs', Integer)
    min = Column('min', Integer)
    pts = Column('pts', Integer)
    ast = Column('ast', Integer)
    reb = Column('reb', Integer)

class StatsTotalPlayoff(Base):
    __tablename__ = 'totais_carreira_playoffs'
    
    id = Column('id', Integer, primary_key=True, autoincrement=True)
    nba_player_id = Column('nba_player_id', Integer)
    gp = Column('gp', Integer)
    gs = Column('gs', Integer)
    min = Column('min', Integer)
    pts = Column('pts', Integer)
    ast = Column('ast', Integer)
    reb = Column('reb', Integer)

class StatsRegularSeason(Base):
    __tablename__ = 'stats_temporada_regular'
    
    id = Column('id', Integer, primary_key=True, autoincrement=True)
    nba_player_id = Column('nba_player_id', Integer)
    season_id = Column('season_id', String)
    team_abbreviation = Column('team_abbreviation', String)
    player_age = Column('player_age', Integer)
    gp = Column('gp', Integer)
    gs = Column('gs', Integer)
    min = Column('min', Integer)
    pts = Column('pts', Integer)
    ast = Column('ast', Integer)
    reb = Column('reb', Integer)

class StatsSeasonPlayoff(Base):
    __tablename__ = 'stats_playoff'
    
    id = Column('id', Integer, primary_key=True, autoincrement=True)
    nba_player_id = Column('nba_player_id', Integer)
    season_id = Column('season_id', String)
    team_abbreviation = Column('team_abbreviation', String)
    player_age = Column('player_age', Integer)
    gp = Column('gp', Integer)
    gs = Column('gs', Integer)
    min = Column('min', Integer)
    pts = Column('pts', Integer)
    ast = Column('ast', Integer)
    reb = Column('reb', Integer)

class StatsGame(Base):
    __tablename__ = 'stats_playoff'
    
    id = Column('id', Integer, primary_key=True, autoincrement=True)
    game_id = Column('game_id', Integer)
    data_jogo = Column('data_jogo', String)
    nba_player_id = Column('nba_player_id', Integer)
    nome_completo = Column('nome_completo', String)
    time_jogador = Column('time_jogador', String)
    time_adversario = Column('time_adversario', Integer)
    minutos = Column('minutos', Integer)
    pts = Column('pts', Integer)
    ast = Column('ast', Integer)
    reb = Column('reb', Integer)
    oreb = Column('oreb', Integer)
    dreb = Column('dreb', Integer)
    stl = Column('stl', Integer)
    blk = Column('blk', Integer)
    tov = Column('tov', Integer)
    pf = Column('pf', Integer)
    fgm = Column('fgm', Integer)
    fga = Column('fga', Integer)
    fg_pct = Column('fg_pct', Integer)
    fg3m = Column('fg3m', Integer)
    fg3a = Column('fg3a', Integer)
    fg3_pct = Column('fg3_pct', Integer)
    ftm = Column('ftm', Integer)
    fta = Column('fta', Integer)
    ft_pct = Column('ft_pct', Integer)
    plus_minus = Column('plus_minus', Integer)
    