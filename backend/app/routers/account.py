from fastapi import APIRouter, HTTPException, Request, Response
from sqlmodel import select

from app.deps import AdminDep, SessionDep, UserDep
from app.models import (ChatMessage, Conversation, Food, MealRecord, NutritionTarget,
                        Recognition, Recipe, UploadedImage, User, UserProfile)
from app.schemas import DeleteAccount
from app.security import verify_password
from app.routers.ai import image_path

router = APIRouter()


@router.get("/api/account/export", tags=["隐私与账号"], summary="导出自己的结构化数据，不包含密码和密钥")
def export_account(session: SessionDep, user: UserDep):
    result = {"user": {"id": user.id, "username": user.username, "created_at": user.created_at}}
    for label, model in [("profiles", UserProfile), ("targets", NutritionTarget),
                          ("meal_records", MealRecord), ("recognitions", Recognition),
                          ("conversations", Conversation)]:
        result[label] = [row.model_dump(mode="json") for row in session.exec(select(model).where(model.user_id == user.id)).all()]
    ids = [row["id"] for row in result["conversations"]]
    result["messages"] = [row.model_dump(mode="json") for row in session.exec(select(ChatMessage).where(ChatMessage.conversation_id.in_(ids))).all()] if ids else []
    result["images"] = [{"id": row.id, "width": row.width, "height": row.height, "created_at": row.created_at}
                        for row in session.exec(select(UploadedImage).where(UploadedImage.user_id == user.id)).all()]
    return result


@router.delete("/api/account", status_code=204, tags=["隐私与账号"], summary="验证密码后删除账号及个人数据")
def delete_account(data: DeleteAccount, request: Request, session: SessionDep, user: UserDep) -> Response:
    if not verify_password(data.password, user.password_hash):
        raise HTTPException(401, "密码错误")
    images = session.exec(select(UploadedImage).where(UploadedImage.user_id == user.id)).all()
    paths = [image_path(request.app.state.settings, image) for image in images]
    conversations = session.exec(select(Conversation).where(Conversation.user_id == user.id)).all()
    for conversation in conversations:
        for message in session.exec(select(ChatMessage).where(ChatMessage.conversation_id == conversation.id)).all():
            session.delete(message)
    session.flush()
    for model in [Conversation, Recognition, MealRecord, NutritionTarget, UploadedImage, UserProfile]:
        for row in session.exec(select(model).where(model.user_id == user.id)).all():
            session.delete(row)
        session.flush()
    session.delete(user)
    session.commit()
    for path in paths:
        path.unlink(missing_ok=True)
    return Response(status_code=204)


@router.get("/api/admin/overview", tags=["管理端"], summary="管理员查看项目数据规模")
def overview(session: SessionDep, admin: AdminDep):
    from sqlalchemy import func
    return {name: session.exec(select(func.count()).select_from(model)).one()
            for name, model in [("users", User), ("foods", Food), ("recipes", Recipe), ("meal_records", MealRecord)]}
