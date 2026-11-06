from fastapi import APIRouter, HTTPException, Request, Response
from sqlalchemy.exc import IntegrityError
from sqlmodel import select

from app.deps import SessionDep, UserDep
from app.models import User, UserProfile, utcnow
from app.schemas import Login, ProfileRead, ProfileSave, Register, Token, UserRead
from app.security import create_token, dummy_hash, hash_password, verify_password
from app.services.nutrition import calculate_target, ensure_target, today

router = APIRouter()


@router.post("/api/auth/register", response_model=UserRead, status_code=201, tags=["用户认证"], summary="注册账号")
def register(data: Register, session: SessionDep):
    if session.exec(select(User).where(User.username == data.username)).first():
        raise HTTPException(409, "用户名已存在")
    user = User(username=data.username, password_hash=hash_password(data.password))
    session.add(user)
    try:
        session.commit()
    except IntegrityError:
        session.rollback()
        raise HTTPException(409, "用户名已存在") from None
    session.refresh(user)
    return user


@router.post("/api/auth/login", response_model=Token, tags=["用户认证"], summary="账号密码登录")
def login(data: Login, request: Request, session: SessionDep):
    user = session.exec(select(User).where(User.username == data.username)).first()
    valid = verify_password(data.password, user.password_hash if user else dummy_hash())
    if user is None or not valid:
        raise HTTPException(401, "用户名或密码错误", headers={"WWW-Authenticate": "Bearer"})
    settings = request.app.state.settings
    return Token(access_token=create_token(user, settings), expires_in=settings.access_token_minutes * 60)


@router.get("/api/auth/me", response_model=UserRead, tags=["用户认证"], summary="当前登录用户")
def me(user: UserDep):
    return user


@router.post("/api/auth/logout", status_code=204, tags=["用户认证"], summary="退出该账号的所有登录设备")
def logout(session: SessionDep, user: UserDep) -> Response:
    user.token_version += 1
    session.add(user)
    session.commit()
    return Response(status_code=204)


@router.put("/api/profile/me", response_model=ProfileRead, tags=["个人档案"], summary="保存个人档案并同步重算今日目标")
def save_profile(data: ProfileSave, session: SessionDep, user: UserDep):
    calculate_target(data)
    profile = session.get(UserProfile, user.id)
    if profile is None:
        profile = UserProfile(user_id=user.id, **data.model_dump())
    else:
        profile.sqlmodel_update(data.model_dump())
        profile.updated_at = utcnow()
    session.add(profile)
    try:
        session.commit()
    except IntegrityError:
        session.rollback()
        raise HTTPException(409, "档案保存冲突，请重试") from None
    session.refresh(profile)
    # 今日目标必须与本次档案保存在同一请求内更新；历史目标快照保持不变。
    ensure_target(session, user.id, today(), recalculate=True)
    return profile


@router.get("/api/profile/me", response_model=ProfileRead, tags=["个人档案"], summary="查看自己的档案")
def get_profile(session: SessionDep, user: UserDep):
    profile = session.get(UserProfile, user.id)
    if profile is None:
        raise HTTPException(404, "尚未建立个人档案")
    return profile
