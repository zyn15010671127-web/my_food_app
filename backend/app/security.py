from datetime import datetime, timedelta, timezone
from functools import lru_cache

import jwt
from fastapi import HTTPException
from pwdlib import PasswordHash

password_hasher = PasswordHash.recommended()


def hash_password(password):
    return password_hasher.hash(password)


def verify_password(password, hashed):
    try:
        return password_hasher.verify(password, hashed)
    except (ValueError, TypeError):
        return False


@lru_cache(maxsize=1)
def dummy_hash():
    return hash_password("timing-protection-placeholder-password")


def create_token(user, settings):
    now = datetime.now(timezone.utc)
    return jwt.encode({"sub": str(user.id), "ver": user.token_version,
        "iat": now, "exp": now + timedelta(minutes=settings.access_token_minutes),
        "iss": "diet-backend", "aud": "diet-app"}, settings.jwt_secret, algorithm="HS256")


def unauthorized():
    return HTTPException(401, "登录凭证无效或已过期，请重新登录", headers={"WWW-Authenticate": "Bearer"})
