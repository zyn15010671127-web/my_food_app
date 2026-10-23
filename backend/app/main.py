import logging
import threading
import time
from collections import defaultdict, deque
from contextlib import asynccontextmanager
from uuid import uuid4

from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from fastapi.openapi.docs import get_swagger_ui_html
from fastapi.responses import JSONResponse
from fastapi.staticfiles import StaticFiles
from sqlalchemy import text
from sqlmodel import Session
from starlette.exceptions import HTTPException as StarletteHTTPException

from app.config import Settings, load_settings
from app.db import build_engine, create_tables
from app.routers import account, ai, auth, catalog, nutrition, records

logger = logging.getLogger("diet_backend")


def create_app(settings: Settings | None = None):
    settings = (settings or load_settings()).prepare()
    engine = build_engine(settings.database_url)

    @asynccontextmanager
    async def lifespan(app):
        if settings.auto_create_tables:
            create_tables(engine)
        if settings.seed_demo:
            from app.seed import seed_demo
            with Session(engine) as session:
                seed_demo(session)
        yield
        engine.dispose()

    app = FastAPI(title="智能饮食搭配推荐系统", version="1.0.0", lifespan=lifespan,
        docs_url=None, redoc_url=None,
        description="课程提交版后端。食物营养按每100克，菜谱按每份。默认使用明确标记的演示数据；推荐和问答仅供一般营养参考。")
    app.state.settings = settings
    app.state.engine = engine
    app.add_middleware(CORSMiddleware, allow_origins=settings.cors_origins,
        allow_credentials=False, allow_methods=["GET", "POST", "PUT", "DELETE", "OPTIONS"],
        allow_headers=["Authorization", "Content-Type", "X-Request-ID"])
    requests = defaultdict(deque)
    lock = threading.Lock()

    @app.middleware("http")
    async def limits_and_headers(request: Request, call_next):
        request_id = uuid4().hex
        request.state.request_id = request_id
        length = request.headers.get("content-length", "0")
        try:
            if int(length) > 9 * 1024 * 1024:
                return JSONResponse(status_code=413, content={"detail": "请求体过大", "request_id": request_id})
        except ValueError:
            return JSONResponse(status_code=400, content={"detail": "无效的 Content-Length"})
        path = request.url.path
        if settings.rate_limit_enabled and request.method != "OPTIONS" and path.startswith("/api/"):
            auth_path = path in {"/api/auth/login", "/api/auth/register"}
            expensive = path.startswith(("/api/recognitions", "/api/chat/messages", "/api/agents/dispatch"))
            limit = 20 if auth_path else 30 if expensive else 300
            group = "auth" if auth_path else "ai" if expensive else "general"
            client = request.client.host if request.client else "unknown"
            now = time.monotonic()
            with lock:
                if len(requests) > 10000:
                    for key in list(requests):
                        if not requests[key] or requests[key][-1] < now - 60:
                            del requests[key]
                queue = requests[(client, group)]
                while queue and queue[0] < now - 60:
                    queue.popleft()
                rejected = len(queue) >= limit
                if not rejected:
                    queue.append(now)
            if rejected:
                return JSONResponse(status_code=429, content={"detail": "请求过于频繁，请稍后重试", "request_id": request_id}, headers={"Retry-After": "60"})
        response = await call_next(request)
        response.headers["X-Request-ID"] = request_id
        response.headers["X-Content-Type-Options"] = "nosniff"
        response.headers["Referrer-Policy"] = "same-origin"
        return response

    @app.exception_handler(StarletteHTTPException)
    async def http_error(request: Request, error):
        return JSONResponse(status_code=error.status_code,
            content={"detail": error.detail, "request_id": getattr(request.state, "request_id", "")}, headers=error.headers)

    @app.exception_handler(RequestValidationError)
    async def validation_error(request: Request, error):
        # 避免校验错误把密码或完整上传内容回显到客户端。
        errors = [{"loc": list(e["loc"]), "msg": e["msg"], "type": e["type"]} for e in error.errors()]
        return JSONResponse(status_code=422, content={"detail": errors, "request_id": getattr(request.state, "request_id", "")})

    @app.exception_handler(Exception)
    async def unexpected_error(request: Request, error):
        logger.exception("Unhandled request failure id=%s", getattr(request.state, "request_id", ""))
        return JSONResponse(status_code=500, content={"detail": "服务器内部错误", "request_id": getattr(request.state, "request_id", "")})

    try:
        from swagger_ui_bundle import swagger_ui_path
        app.mount("/docs-assets", StaticFiles(directory=swagger_ui_path), name="docs-assets")
        local_assets = True
    except ImportError:
        local_assets = False

    @app.get("/docs", include_in_schema=False)
    def docs():
        kwargs = {"swagger_js_url": "/docs-assets/swagger-ui-bundle.js", "swagger_css_url": "/docs-assets/swagger-ui.css"} if local_assets else {}
        return get_swagger_ui_html(openapi_url="/openapi.json", title="接口文档 · 智能饮食推荐", **kwargs,
            swagger_ui_parameters={"persistAuthorization": False, "displayRequestDuration": True})

    @app.get("/", tags=["系统"], summary="项目入口")
    def home():
        return {"message": "饮食推荐系统后端启动成功", "version": "1.0.0", "docs": "/docs", "health": "/api/health"}

    @app.get("/api/health", tags=["系统"], summary="数据库与服务健康检查")
    def health():
        try:
            with Session(engine) as session:
                session.exec(text("SELECT 1")).first()
        except Exception:
            return JSONResponse(status_code=503, content={"status": "unavailable"})
        return {"status": "ok", "version": "1.0.0", "external_ai_enabled": settings.ai_enabled}

    for router in [auth.router, catalog.router, records.router, nutrition.router, ai.router, account.router]:
        app.include_router(router)
    return app
