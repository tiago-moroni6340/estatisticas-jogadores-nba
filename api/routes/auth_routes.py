from fastapi import APIRouter, Depends, HTTPException
from api.models.models import Usuario
from api.dependencies.dependencies import pegar_session, verificar_token
from api.config.config import bcrypt_context
from api.utils.autenticacao import criar_token, autenticar_usuario, validar_senha
from api.schemas.schemas import UsuarioSchema, LoginSchema
from sqlalchemy.orm import Session
from datetime import timedelta
from fastapi.security import OAuth2PasswordRequestForm

auth_router = APIRouter(prefix='/auth', tags=['auth'])

@auth_router.post('/criar_conta')
async def cria_conta(usuario_schema: UsuarioSchema, session: Session = Depends(pegar_session)):
    usuario = session.query(Usuario).filter(Usuario.email == usuario_schema.email).first()
    if usuario:
        raise HTTPException(status_code=400, detail='Email de usuário já cadastrado')
    
    if not valida_senha(usuario_schema.senha):
        raise HTTPException(status_code=400, detail='Senha deve conter entre 8 a 25 caracteres, pelo menos 1 letra maiúscula, 1 número e 1 caractere especial')

    if usuario_schema.senha != usuario_schema.confirmacao_senha:
        raise HTTPException(status_code=400, detail="Senhas não coincidem!")

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


    return {
        'Mensagem': f'Usuário cadastrado com sucesso: {usuario_schema.email}',
    }

@auth_router.post("/login")
async def login(login_schema: LoginSchema, session: Session = Depends(pegar_session)):
    usuario = autenticar_usuario(login_schema.email, login_schema.senha, session)
    if not usuario:
        raise HTTPException(status_code=400, detail="Usuário não encontrado ou credenciais inválidas!")
    
    if not usuario.ativo:
        raise HTTPException(status_code=403, detail="Esta conta foi desativada. Entre em contato com o administrador.")
        
    access_token = criar_token(usuario.id)
    refresh_token = criar_token(usuario.id, duracao_token=timedelta(days=7))

    return {
        'access_token': access_token,
        "refresh_token": refresh_token,
        "token_type": "Bearer"
    }

@auth_router.post("/login-form")
async def login_form(dados_formulario: OAuth2PasswordRequestForm = Depends(), session: Session = Depends(pegar_session)):
    usuario = autenticar_usuario(dados_formulario.username, dados_formulario.password, session)
    if not usuario:
        raise HTTPException(status_code=400, detail="Usuário não encontrado ou credenciais inválidas!")
    
    if not usuario.ativo:
        raise HTTPException(status_code=403, detail="Esta conta foi desativada.")
    
    access_token = criar_token(usuario.id)
    return {
        'access_token': access_token,
        "token_type": "Bearer"
    }


@auth_router.get("/refresh")
async def use_refresh_token(usuario: Usuario = Depends(verificar_token)):
    access_token = criar_token(usuario.id)
    return {
        'access_token': access_token,
        "token_type": "Bearer"
    }

@auth_router.delete('/deletar_conta/{nome_usuario}')
async def deletar_conta(nome_usuario: str, session: Session = Depends(pegar_session), usuario: Usuario = Depends(verificar_token)):
    conta = session.query(Usuario).filter(Usuario.nome == nome_usuario).first()
    if not conta:
        raise HTTPException(status_code=400, detail="Usuário não encontrado")
    
    session.delete(conta)
    session.commit()

    return {'Mensagem':'Conta deletada com sucesso!'}
