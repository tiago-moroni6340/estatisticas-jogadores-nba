from fastapi import APIRouter, Depends, HTTPException
from models.models import Usuario
from dependencies.dependencies import pegar_session, verificar_token
from config.config import bcrypt_context
from utils.autenticacao import criar_token, autenticar_usuario, validar_senha
from schemas.schemas import UsuarioSchema, LoginSchema
from sqlalchemy.orm import Session
from datetime import timedelta

auth_router = APIRouter(prefix='/auth', tags=['auth'])

logger = ...

@auth_router.post('/criar_conta')
async def criar_conta(usuario_schema: UsuarioSchema, session: Session = Depends(pegar_session)):
    usuario = session.query(Usuario).filter(Usuario.email == usuario_schema.email).first()
    if usuario:
        logger.error(
            "Tentativa de cadastro com e-mail já existente",
            extra={"extra_data": {"email_tentativa": usuario_schema.email}}
        )
        raise HTTPException(status_code=400, detail='Email de usuário já cadastrado')
    
    senha_criptografada = bcrypt_context.hash(usuario_schema.senha)
    novo_usuario = Usuario(
        nome=usuario_schema.nome, 
        email=usuario_schema.email,
        data_nascimento=usuario_schema.data_nascimento,
        cidade=usuario_schema.cidade,
        estado=usuario_schema.estado,
        pais=usuario_schema.pais,
        celular=usuario_schema.celular,
        equipe=usuario_schema.equipe,
        cargo=usuario_schema.cargo,
        senha=senha_criptografada, 
        ativo=usuario_schema.ativo, 
    )
    
    session.add(novo_usuario)
    session.commit()

    
    logger.info(
        "Novo usuário cadastrado com sucesso",
        extra={"extra_data": {"novo_usuario": usuario_schema.email}}
    )
    return {
        'Mensagem': f'Usuário cadastrado com sucesso: {usuario_schema.email}',
    }

@auth_router.post("/login")
async def login(login_schema: LoginSchema, session: Session = Depends(pegar_session)):
    usuario = autenticar_usuario(login_schema.email, login_schema.senha, session)
    if not usuario:
        logger.error(
            "Falha de autenticação: credenciais inválidas",
            extra={"extra_data": {"email_tentativa": login_schema.email}}
        )
        raise HTTPException(status_code=400, detail="Usuário não encontrado ou credenciais inválidas!")
    
    if not usuario.ativo:
        logger.warning(
            "Tentativa de login em conta desativada",
            extra={"extra_data": {"usuario_id": usuario.id, "email": usuario.email}}
        )
        raise HTTPException(status_code=403, detail="Esta conta foi desativada. Entre em contato com o administrador.")
        
    access_token = criar_token(usuario.id)
    refresh_token = criar_token(usuario.id, duracao_token=timedelta(days=7))

    logger.info(
        "Login efetuado com sucesso",
        extra={"extra_data": {"usuario_id": usuario.id, "email": usuario.email}}
    )
    return {
        'access_token': access_token,
        "refresh_token": refresh_token,
        "token_type": "Bearer"
    }

@auth_router.get("/refresh")
async def use_refresh_token(usuario: Usuario = Depends(verificar_token)):
    access_token = criar_token(usuario.id)
    logger.info(
        "Token de acesso renovado utilizando Refresh Token",
        extra={"extra_data": {"usuario_id": usuario.id, "email": usuario.email}}
    )
    return {
        'access_token': access_token,
        "token_type": "Bearer"
    }

@auth_router.delete('/deletar_conta/{nome_usuario}')
async def deletar_conta(nome_usuario: str, session: Session = Depends(pegar_session), usuario: Usuario = Depends(verificar_token)):
    conta = session.query(Usuario).filter(Usuario.nome == nome_usuario).first()
    if not conta:
        logger.error(
            "Usuario tentou excluir usuário inexistente",
            extra={"extra_data": {"nome_alvo": nome_usuario, "admin": usuario.nome}}
        )
        raise HTTPException(status_code=400, detail="Usuário não encontrado")
    
    session.delete(conta)
    session.commit()

    logger.info(
        "Conta de usuário excluída permanentemente do sistema",
        extra={"extra_data": {"usuario_deletado": nome_usuario, "excluido_por": usuario.nome}}
    )
    return {'Mensagem':'Conta deletada com sucesso!'}