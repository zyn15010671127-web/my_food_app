import io
import logging
import warnings

from fastapi import APIRouter, File, HTTPException, Query, Request, Response, UploadFile
from fastapi.responses import FileResponse
from PIL import Image, ImageOps, UnidentifiedImageError
from sqlalchemy import update
from sqlmodel import select

from app.deps import SessionDep, UserDep
from app.models import ChatMessage, Conversation, Food, Recognition, UploadedImage
from app.schemas import (ChatRequest, ChatResponse, DispatchRequest, MealRead, MealSave,
                         RecognitionConfirm, RecognitionRead, RecognitionRequest)
from app.services.catalog import make_meal
from app.services.knowledge import answer
from app.services.nutrition import daily_progress, today
from app.services.provider import ProviderError, identify, identify_baidu_dish
from app.services.recommendation import recommend

router = APIRouter()
logger = logging.getLogger(__name__)
MAX_IMAGE_BYTES = 8 * 1024 * 1024


def own_image(session, user_id, image_id):
    image = session.exec(select(UploadedImage).where(
        UploadedImage.id == image_id, UploadedImage.user_id == user_id)).first()
    if image is None:
        raise HTTPException(404, "图片不存在")
    return image


def image_path(settings, image):
    root = (settings.data_dir / "uploads").resolve()
    path = (root / image.relative_path).resolve()
    if not path.is_relative_to(root):
        raise HTTPException(404, "图片不存在")
    return path


@router.post("/api/uploads/images", status_code=201, tags=["图片识别"], summary="上传并校验图片，去除 EXIF 后私有保存")
async def upload_image(request: Request, session: SessionDep, user: UserDep, file: UploadFile = File(...)):
    raw = await file.read(MAX_IMAGE_BYTES + 1)
    if len(raw) > MAX_IMAGE_BYTES:
        raise HTTPException(413, "图片不能超过 8 MB")
    try:
        with warnings.catch_warnings():
            warnings.simplefilter("error", Image.DecompressionBombWarning)
            with Image.open(io.BytesIO(raw)) as probe:
                if probe.format not in {"JPEG", "PNG", "WEBP"}:
                    raise ValueError("unsupported format")
                if probe.width * probe.height > 20_000_000:
                    raise ValueError("too many pixels")
                probe.verify()
            with Image.open(io.BytesIO(raw)) as original:
                image = ImageOps.exif_transpose(original).convert("RGB")
                image.thumbnail((2048, 2048))
                buffer = io.BytesIO()
                image.save(buffer, format="JPEG", quality=90)
                width, height = image.size
    except (UnidentifiedImageError, OSError, ValueError, Image.DecompressionBombError, Image.DecompressionBombWarning):
        raise HTTPException(422, "请上传有效的 JPEG、PNG 或 WEBP 图片，像素不能超过两千万") from None
    uploaded = UploadedImage(user_id=user.id, relative_path="", width=width, height=height)
    uploaded.relative_path = f"{user.id}/{uploaded.id}.jpg"
    path = image_path(request.app.state.settings, uploaded)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(buffer.getvalue())
    try:
        session.add(uploaded)
        session.commit()
    except Exception:
        path.unlink(missing_ok=True)
        raise
    session.refresh(uploaded)
    return {"id": uploaded.id, "width": width, "height": height,
            "url": f"/api/uploads/images/{uploaded.id}", "access": "Bearer 登录后访问"}


@router.get("/api/uploads/images/{image_id}", tags=["图片识别"], summary="读取自己的私有图片")
def get_image(image_id: str, request: Request, session: SessionDep, user: UserDep):
    image = own_image(session, user.id, image_id)
    path = image_path(request.app.state.settings, image)
    if not path.is_file():
        raise HTTPException(404, "图片文件不存在")
    return FileResponse(path, media_type="image/jpeg", headers={"Cache-Control": "private, no-store"})


def run_recognition(data, request, session, user):
    image = own_image(session, user.id, data.image_id)
    settings = request.app.state.settings
    result = Recognition(user_id=user.id, image_id=image.id,
        message="未启用外部视觉服务，请搜索食物并手动确认份量。")
    baidu_ready = bool(settings.baidu_dish_enabled and settings.baidu_api_key and settings.baidu_secret_key)
    generic_ready = bool(settings.ai_enabled and settings.vision_model and settings.ai_api_key)
    if data.allow_external_processing and (baidu_ready or generic_ready):
        try:
            path = image_path(settings, image)
            if not path.is_file():
                raise HTTPException(404, "图片文件不存在")
            if baidu_ready:
                dishes = identify_baidu_dish(settings, path.read_bytes())
                mode = "baidu_dish"
            else:
                dishes = identify(settings, path.read_bytes())
                mode = "external_vision"
            foods = session.exec(select(Food).where(Food.is_active == True)).all()  # noqa: E712
            matched = []
            for dish in dishes:
                candidates = [f for f in foods if dish["name"] == f.name or dish["name"] in f.aliases]
                matched.append({**dish, "food_id": candidates[0].id if candidates else None,
                    "requires_grams": True, "note": "名称和份量须由用户核对；没有可靠位置框时不绘制识别框。"})
            result.dishes = matched
            result.status = "recognized" if dishes else "manual_required"
            result.mode = mode
            result.message = "请核对名称、选择食物库条目并填写实际克数后确认保存。" if dishes else "未识别到食物，请手动录入。"
        except ProviderError:
            result.message = "外部识别服务不可用或返回格式无效，请手动搜索食物录入。"
    elif (settings.ai_enabled or settings.baidu_dish_enabled) and not data.allow_external_processing:
        result.message = "本次未同意将图片发送至外部服务，请手动搜索食物录入。"
    session.add(result)
    session.commit()
    session.refresh(result)
    return result


@router.post("/api/recognitions", response_model=RecognitionRead, status_code=201, tags=["图片识别"], summary="识别上传图片，失败或无密钥时明确降级")
def recognize(data: RecognitionRequest, request: Request, session: SessionDep, user: UserDep):
    return run_recognition(data, request, session, user)


@router.get("/api/recognitions/{recognition_id}", response_model=RecognitionRead, tags=["图片识别"], summary="查看自己的识别结果")
def get_recognition(recognition_id: str, session: SessionDep, user: UserDep):
    result = session.exec(select(Recognition).where(Recognition.id == recognition_id, Recognition.user_id == user.id)).first()
    if result is None:
        raise HTTPException(404, "识别任务不存在")
    return result


@router.post("/api/recognitions/{recognition_id}/confirm", response_model=list[MealRead], status_code=201,
             tags=["图片识别"], summary="用户修正食物及克数后原子保存，禁止重复确认")
def confirm_recognition(recognition_id: str, data: RecognitionConfirm, session: SessionDep, user: UserDep):
    recognition = get_recognition(recognition_id, session, user)
    claimed = session.execute(update(Recognition).where(Recognition.id == recognition_id,
        Recognition.user_id == user.id, Recognition.status != "confirmed").values(status="confirmed"))
    if claimed.rowcount != 1:
        raise HTTPException(409, "该识别任务已经确认，不能重复保存")
    records = [make_meal(session, user.id, MealSave(food_id=item.food_id, grams=item.grams,
        meal_type=data.meal_type, record_date=data.record_date), source="photo_confirmed") for item in data.items]
    session.flush()
    recognition.confirmed_record_ids = [record.id for record in records]
    recognition.status = "confirmed"
    session.add(recognition)
    session.commit()
    for record in records:
        session.refresh(record)
    return records


def own_conversation(session, user_id, conversation_id):
    conversation = session.exec(select(Conversation).where(
        Conversation.id == conversation_id, Conversation.user_id == user_id)).first()
    if conversation is None:
        raise HTTPException(404, "会话不存在")
    return conversation


@router.post("/api/chat/messages", response_model=ChatResponse, tags=["营养顾问"], summary="营养问答，支持本地知识库与可选外部模型")
def chat(data: ChatRequest, request: Request, session: SessionDep, user: UserDep):
    if data.conversation_id:
        conversation = own_conversation(session, user.id, data.conversation_id)
    else:
        conversation = Conversation(user_id=user.id, title=data.message[:30])
        session.add(conversation)
        session.flush()
    history_rows = session.exec(select(ChatMessage).where(ChatMessage.conversation_id == conversation.id)
        .order_by(ChatMessage.id.desc()).limit(6)).all()
    history = [{"role": row.role, "content": row.content} for row in reversed(history_rows)]
    reply, mode, sources = answer(request.app.state.settings, data.message, history, data.allow_external_processing)
    session.add(ChatMessage(conversation_id=conversation.id, role="user", content=data.message))
    session.add(ChatMessage(conversation_id=conversation.id, role="assistant", content=reply, mode=mode, sources=sources))
    session.commit()
    return ChatResponse(conversation_id=conversation.id, reply=reply, mode=mode, sources=sources)


@router.get("/api/chat/conversations", tags=["营养顾问"], summary="分页查看自己的咨询会话")
def conversations(session: SessionDep, user: UserDep, offset: int = Query(0, ge=0), limit: int = Query(20, ge=1, le=100)):
    return session.exec(select(Conversation).where(Conversation.user_id == user.id)
        .order_by(Conversation.created_at.desc()).offset(offset).limit(limit)).all()


@router.get("/api/chat/conversations/{conversation_id}/messages", tags=["营养顾问"], summary="分页查看自己的会话消息")
def messages(conversation_id: str, session: SessionDep, user: UserDep,
             offset: int = Query(0, ge=0), limit: int = Query(50, ge=1, le=100)):
    own_conversation(session, user.id, conversation_id)
    return session.exec(select(ChatMessage).where(ChatMessage.conversation_id == conversation_id)
        .order_by(ChatMessage.id).offset(offset).limit(limit)).all()


@router.delete("/api/chat/conversations/{conversation_id}", status_code=204, tags=["营养顾问"], summary="删除自己的咨询会话及消息")
def delete_conversation(conversation_id: str, session: SessionDep, user: UserDep) -> Response:
    conversation = own_conversation(session, user.id, conversation_id)
    for message in session.exec(select(ChatMessage).where(ChatMessage.conversation_id == conversation_id)).all():
        session.delete(message)
    session.flush()
    session.delete(conversation)
    session.commit()
    return Response(status_code=204)


@router.post("/api/agents/dispatch", tags=["Agent 编排"], summary="显式规则路由到识别、规划、顾问或营养统计模块")
def dispatch(data: DispatchRequest, request: Request, session: SessionDep, user: UserDep):
    day = data.record_date or today()
    if data.image_id:
        result = run_recognition(RecognitionRequest(image_id=data.image_id,
            allow_external_processing=data.allow_external_processing), request, session, user)
        return {"agent": "dish_recognition", "routing_mode": "rule_router", "result": RecognitionRead.model_validate(result)}
    if any(word in data.message for word in ["推荐", "吃什么", "菜谱", "搭配"]):
        return {"agent": "diet_planner", "routing_mode": "rule_router",
                "result": recommend(session, user.id, day, data.meal_type)}
    if any(word in data.message for word in ["目标", "进度", "摄入", "剩余"]):
        return {"agent": "nutrition_progress", "routing_mode": "rule_router",
                "result": daily_progress(session, user.id, day)}
    result = chat(ChatRequest(message=data.message, allow_external_processing=data.allow_external_processing), request, session, user)
    return {"agent": "nutrition_advisor", "routing_mode": "rule_router", "result": result}
