from sqlalchemy.orm import sessionmaker, Session
from api.models.models import db, Usuario
from fastapi import Depends, HTTPException
from jose import jwt, JWTError
from api.config.config import SECRET_KEY, ALGORITHM, oauth2_schema

def pega_session():
    try:
        Session = sessionmaker(bind=db)
        session = Session()
        yield session
    finally:
        session.close()

def verifica_token(token: str = Depends(oauth2_schema), session: Session = Depends(pega_session)):
    try:
        dic_info = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        id_usuario = dic_info.get('sub')
    except JWTError:
        raise HTTPException(status_code=401, detail="Acesso negado, verifique a validade do token")
    usuario = session.query(Usuario).filter(Usuario.id == id_usuario).first()
    if not usuario:
        raise HTTPException(status_code=401, detail='Acesso inválido!')
    if not usuario.ativo:
        raise HTTPException(status_code=401, detail='Usuário inativo!')

    return usuario
