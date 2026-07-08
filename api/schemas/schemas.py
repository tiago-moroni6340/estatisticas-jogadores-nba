from pydantic import BaseModel, EmailStr

class UsuarioSchema(BaseModel):
    nome: str
    email: EmailStr
    equipe: str
    cargo: str
    senha: str
    confirmacao_senha: str
    ativo: bool

class LoginSchema(BaseModel):
    email: EmailStr
    senha: str

    