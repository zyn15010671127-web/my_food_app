from sqlalchemy import event
from sqlmodel import Session, SQLModel, create_engine


def build_engine(url: str):
    kwargs = {"pool_pre_ping": True}
    if url.startswith("sqlite"):
        kwargs["connect_args"] = {"check_same_thread": False, "timeout": 15}
    engine = create_engine(url, **kwargs)
    if url.startswith("sqlite"):
        @event.listens_for(engine, "connect")
        def configure_sqlite(connection, _):
            cursor = connection.cursor()
            cursor.execute("PRAGMA foreign_keys=ON")
            cursor.execute("PRAGMA busy_timeout=15000")
            cursor.close()
    return engine


def get_session(request):
    with Session(request.app.state.engine) as session:
        yield session


def create_tables(engine):
    from app import models  # noqa: F401
    SQLModel.metadata.create_all(engine)
