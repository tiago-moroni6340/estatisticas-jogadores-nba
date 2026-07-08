from dotenv import load_dotenv
import os
from fastapi.security import OAuth2PasswordBearer
import bcrypt

load_dotenv()

SECRET_KEY = os.getenv('SECRET_KEY')
ALGORITHM = os.getenv('ALGORITHM')
ACCESS_TOKEN_EXPIRE_MINUTES = int(os.getenv('ACCESS_TOKEN_EXPIRE_MINUTES'))
DATABASE_URL = os.getenv('DATABASE_URL')
RESEND_API_KEY = os.getenv('RESEND_API_KEY')

class BcryptContext:
    def hash(self, password: str) -> str:
        salt = bcrypt.gensalt()
        return bcrypt.hashpw(password.encode('utf-8'), salt).decode('utf-8')

    def verify(self, plain_password: str, hashed_password: str) -> bool:
        try:
            return bcrypt.checkpw(plain_password.encode('utf-8'), hashed_password.encode('utf-8'))
        except Exception:
            return False

bcrypt_context = BcryptContext()
oauth2_schema = OAuth2PasswordBearer(tokenUrl="auth/login-form")
