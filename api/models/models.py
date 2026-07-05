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

