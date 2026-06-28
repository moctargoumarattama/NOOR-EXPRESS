import os
from pathlib import Path
import sys

from a2wsgi import ASGIMiddleware


BACKEND_DIR = Path(__file__).resolve().parent
if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))

os.environ.setdefault("FORCE_SQLITE", "1")
os.environ.setdefault("RUN_SCHEMA_BOOTSTRAP_ON_STARTUP", "0")

from app.main import app  # noqa: E402


application = ASGIMiddleware(app)
