from sqlalchemy.orm import sessionmaker, Session
from api.models import db

def pegar_session():
    try:
        Session = sessionmaker(bind=db)
        session = Session()
        yield session
    finally:
        session.close()