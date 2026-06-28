from collections.abc import AsyncGenerator
from pathlib import Path

from sqlalchemy.engine import make_url
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine
from sqlalchemy.orm import DeclarativeBase

from app.core.config import settings


class Base(DeclarativeBase):
    pass


_backend_dir = Path(__file__).resolve().parents[2]
_database_url = make_url(settings.DATABASE_URL)
if settings.FORCE_SQLITE:
    _database_url = make_url("sqlite+aiosqlite:///NOOREXPRESS.BD")
if _database_url.get_backend_name() == "sqlite" and _database_url.database:
    database_path = Path(_database_url.database)
    if not database_path.is_absolute() and _database_url.database != ":memory:":
        database_path = (_backend_dir / database_path).resolve()
    _database_url = _database_url.set(database=str(database_path.as_posix()))

_engine_kwargs = {"echo": False}
if _database_url.get_backend_name() == "sqlite":
    _engine_kwargs["connect_args"] = {"check_same_thread": False}
else:
    _engine_kwargs.update(
        pool_size=10,
        max_overflow=20,
        pool_pre_ping=True,
        pool_recycle=3600,
    )

engine = create_async_engine(str(_database_url), **_engine_kwargs)

AsyncSessionLocal = async_sessionmaker(
    bind=engine,
    class_=AsyncSession,
    expire_on_commit=False,
)


async def get_db_session() -> AsyncGenerator[AsyncSession, None]:
    async with AsyncSessionLocal() as session:
        yield session
