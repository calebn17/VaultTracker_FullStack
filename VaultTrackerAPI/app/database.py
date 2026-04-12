from sqlalchemy import create_engine
from sqlalchemy.orm import declarative_base, sessionmaker

from app.config import settings


def _engine_kwargs(url: str) -> dict:
    """
    SQLite needs check_same_thread=False (FastAPI may use different threads per
    request). PostgreSQL benefits from pool_pre_ping so dropped connections
    (e.g. Neon idle) are detected.
    """
    if url.startswith("sqlite"):
        return {"connect_args": {"check_same_thread": False}}
    return {"pool_pre_ping": True}


engine = create_engine(settings.database_url, **_engine_kwargs(settings.database_url))

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

Base = declarative_base()

# Register all models on Base.metadata before create_all() (see app.main lifespan).
import app.models  # noqa: E402, F401


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
