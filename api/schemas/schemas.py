from pydantic import BaseModel, EmailStr

class UsuarioSchema(BaseModel):
    nome: str
    email: EmailStr
    data_nascimento: str
    cidade: str
    estado: str
    pais: str
    celular: str
    equipe: str
    cargo: str
    senha: str
    confirmacao_senha: str
    ativo: bool

class LoginSchema(BaseModel):
    email: EmailStr
    senha: str

    