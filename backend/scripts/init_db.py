import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))

from alembic import command
from alembic.config import Config
from sqlmodel import Session

from app.config import load_settings
from app.db import build_engine
from app.seed import seed_demo

settings = load_settings()
config = Config(str(ROOT / "alembic.ini"))
config.set_main_option("script_location", str(ROOT / "migrations"))
command.upgrade(config, "head")
if settings.seed_demo:
    engine = build_engine(settings.database_url)
    with Session(engine) as session:
        seed_demo(session)
    engine.dispose()
print("Database migrations completed.")
