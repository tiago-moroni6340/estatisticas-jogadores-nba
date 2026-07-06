from datetime import datetime, timedelta, timezone
from api.config.config import bcrypt_context, ALGORITHM, ACCESS_TOKEN_EXPIRE_MINUTES, SECRET_KEY
from jose import jwt
from api.models.models import Usuario
import re

def criar_token(id_usuario, duracao_token=timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES), escopo: str = "acesso"):
    data_expiracao = datetime.now(timezone.utc) + duracao_token
    dic_info = {'sub': str(id_usuario), "exp": data_expiracao, "scope": escopo}
    jwt_codificado = jwt.encode(dic_info, SECRET_KEY, algorithm=ALGORITHM)
    return jwt_codificado

def autenticar_usuario(email, senha, session):
    usuario = session.query(Usuario).filter(Usuario.email==email).first()
    if not usuario:
        return False
    elif not bcrypt_context.verify(senha, usuario.senha):
        return False
    return usuario

def validar_senha(password):
    # No Python, usamos o módulo 're'
    padrao = r"^(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]{8,25}$"
    
    if re.match(padrao, password):
        return True
    return False