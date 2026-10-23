import argparse
import getpass
import os
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))

from sqlmodel import Session, select
from app.config import load_settings
from app.db import build_engine
from app.models import User
from app.security import hash_password

parser = argparse.ArgumentParser(description='Create or reset a local administrator after migrations.')
parser.add_argument('--username', required=True)
arguments = parser.parse_args()
if not re.fullmatch(r'[a-z0-9_]{3,32}', arguments.username):
    raise SystemExit('Username must contain 3-32 lowercase letters, digits or underscores.')
password = os.getenv('BOOTSTRAP_ADMIN_PASSWORD') or getpass.getpass('Administrator password: ')
if not 8 <= len(password) <= 128:
    raise SystemExit('Password must contain 8-128 characters.')
settings = load_settings()
engine = build_engine(settings.database_url)
with Session(engine) as session:
    user = session.exec(select(User).where(User.username == arguments.username)).first()
    if user is None:
        user = User(username=arguments.username, password_hash=hash_password(password), is_admin=True)
    else:
        user.password_hash = hash_password(password)
        user.is_admin = True
        user.token_version += 1
    session.add(user)
    session.commit()
engine.dispose()
print('Administrator account is ready.')
