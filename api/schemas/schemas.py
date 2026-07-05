from pydantic import BaseModel, field_validator, EmailStr
from typing import List
from datetime import date
from enum import Enum

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

class NovoLogin(BaseModel):
    reset_token: str
    nova_senha: str
    confirmacao_nova_senha: str

class VerificarCodigoEmail(BaseModel):
    email: EmailStr
    codigo: str

class EmailTrocarSenha(BaseModel):
    email: EmailStr
    