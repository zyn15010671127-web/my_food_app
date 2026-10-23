from typing import Annotated

import jwt
from fastapi import Depends, HTTPException, Request
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from jwt.exceptions import InvalidTokenError
from sqlmodel import Session

from app.models import User
from app.security import unauthorized

bearer = HTTPBearer(auto_error=False)


def get_session(request: Request):
    with Session(request.app.state.engine) as session:
        yield session


SessionDep = Annotated[Session, Depends(get_session)]


def current_user(request: Request, session: SessionDep,
                 credentials: Annotated[HTTPAuthorizationCredentials | None, Depends(bearer)]):
    if credentials is None:
        raise unauthorized()
    try:
        payload = jwt.decode(credentials.credentials, request.app.state.settings.jwt_secret,
            algorithms=["HS256"], issuer="diet-backend", audience="diet-app",
            options={"require": ["sub", "exp", "iat", "ver"]})
        subject = payload["sub"]
        if not subject.isascii() or not subject.isdecimal() or len(subject) > 18:
            raise ValueError("invalid subject")
        user = session.get(User, int(subject))
        if user is None or user.token_version != payload["ver"]:
            raise unauthorized()
        return user
    except (InvalidTokenError, ValueError, TypeError, KeyError, AttributeError):
        raise unauthorized() from None


UserDep = Annotated[User, Depends(current_user)]


def admin_user(user: UserDep):
    if not user.is_admin:
        raise HTTPException(403, "此操作需要管理员权限")
    return user


AdminDep = Annotated[User, Depends(admin_user)]
