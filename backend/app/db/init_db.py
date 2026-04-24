import asyncio

import app.models  # noqa: F401
from app.db.database import Base, engine
from app.db.schema_bootstrap import ensure_database_schema_sync


async def init_db() -> None:
    async with engine.begin() as connection:
        await connection.run_sync(Base.metadata.create_all)
        await connection.run_sync(ensure_database_schema_sync)


if __name__ == "__main__":
    asyncio.run(init_db())
