import os
import asyncio
from pathlib import Path
import sys
from typing import Any


BACKEND_DIR = Path(__file__).resolve().parent
if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))

os.environ.setdefault("FORCE_SQLITE", "1")
os.environ.setdefault("RUN_SCHEMA_BOOTSTRAP_ON_STARTUP", "0")
os.environ.setdefault("RUN_SCHEMA_CREATE_ALL_ON_STARTUP", "1")
os.environ.setdefault("SKIP_FIREBASE_STARTUP_CHECK", "1")


class LazyFastAPIWSGI:
    def __init__(self) -> None:
        self._application: Any | None = None

    def _load_application(self) -> Any:
        if self._application is None:
            from a2wsgi import ASGIMiddleware
            from app.core.config import settings
            from app.db.database import Base, engine
            from app.db.schema_bootstrap import ensure_database_schema
            from app.main import app

            async def _bootstrap_schema() -> None:
                # PythonAnywhere WSGI ne lance pas toujours le lifespan ASGI,
                # donc on prépare la base avant le premier appel.
                if settings.RUN_SCHEMA_BOOTSTRAP_ON_STARTUP:
                    await ensure_database_schema()
                elif settings.RUN_SCHEMA_CREATE_ALL_ON_STARTUP:
                    async with engine.begin() as connection:
                        await connection.run_sync(Base.metadata.create_all)

            if settings.RUN_SCHEMA_BOOTSTRAP_ON_STARTUP or settings.RUN_SCHEMA_CREATE_ALL_ON_STARTUP:
                asyncio.run(_bootstrap_schema())

            self._application = ASGIMiddleware(app)
        return self._application

    def __call__(self, environ: dict[str, Any], start_response: Any) -> Any:
        return self._load_application()(environ, start_response)


application = LazyFastAPIWSGI()
