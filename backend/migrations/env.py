from alembic import context
from sqlmodel import SQLModel

from app import models
from app.config import load_settings
from app.db import build_engine

settings = load_settings()
target_metadata = SQLModel.metadata

if context.is_offline_mode():
    context.configure(url=settings.database_url, target_metadata=target_metadata, literal_binds=True,
        dialect_opts={"paramstyle": "named"})
    with context.begin_transaction():
        context.run_migrations()
else:
    engine = build_engine(settings.database_url)
    with engine.connect() as connection:
        context.configure(connection=connection, target_metadata=target_metadata,
            render_as_batch=settings.database_url.startswith("sqlite"))
        with context.begin_transaction():
            context.run_migrations()
    engine.dispose()
