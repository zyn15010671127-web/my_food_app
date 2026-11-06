import os
import secrets
from dataclasses import dataclass, field
from pathlib import Path

from dotenv import load_dotenv

ROOT = Path(__file__).resolve().parent.parent


def flag(name: str, default: bool) -> bool:
    return os.getenv(name, str(default)).lower() in {"1", "true", "yes"}


@dataclass
class Settings:
    data_dir: Path = field(default_factory=lambda: ROOT / "data" / "runtime")
    database_url: str = ""
    jwt_secret: str = ""
    environment: str = "development"
    seed_demo: bool = True
    auto_create_tables: bool = True
    access_token_minutes: int = 30
    cors_origins: list[str] = field(default_factory=lambda: ["http://localhost:3000", "http://localhost:5173", "http://localhost:8080"])
    ai_enabled: bool = False
    ai_base_url: str = "https://api.openai.com/v1"
    ai_api_key: str = ""
    chat_model: str = ""
    vision_model: str = ""
    baidu_dish_enabled: bool = False
    baidu_api_key: str = ""
    baidu_secret_key: str = ""
    rate_limit_enabled: bool = True

    def prepare(self):
        self.data_dir = self.data_dir.resolve()
        self.data_dir.mkdir(parents=True, exist_ok=True)
        if not self.database_url:
            self.database_url = "sqlite:///" + (self.data_dir / "diet.db").as_posix()
        if not self.jwt_secret:
            if self.environment == "production":
                raise RuntimeError("生产环境必须设置 JWT_SECRET_KEY")
            key_file = self.data_dir / ".jwt_secret"
            try:
                with key_file.open("x", encoding="utf-8") as stream:
                    stream.write(secrets.token_hex(32))
            except FileExistsError:
                pass
            self.jwt_secret = key_file.read_text(encoding="utf-8").strip()
        if len(self.jwt_secret.encode()) < 32:
            raise RuntimeError("JWT_SECRET_KEY 至少需要 32 字节")
        if self.environment == "production" and (self.seed_demo or self.auto_create_tables):
            raise RuntimeError("生产环境必须关闭 SEED_DEMO_DATA 和 AUTO_CREATE_TABLES，并先运行数据库迁移")
        if self.ai_enabled and (not self.ai_base_url.startswith("https://") or not self.ai_api_key):
            raise RuntimeError("外部 AI 开启时必须配置 HTTPS 地址和 API 密钥")
        if self.baidu_dish_enabled and (not self.baidu_api_key or not self.baidu_secret_key):
            raise RuntimeError("百度菜品识别开启时必须配置 BAIDU_API_KEY 和 BAIDU_SECRET_KEY")
        return self


def load_settings() -> Settings:
    load_dotenv(ROOT / ".env")
    database_url = os.getenv("DATABASE_URL", "")
    if not database_url and os.getenv("DB_HOST"):
        from sqlalchemy import URL
        database_url = URL.create("postgresql+psycopg", username=os.getenv("DB_USER", "diet"),
            password=os.getenv("DB_PASSWORD", ""), host=os.environ["DB_HOST"],
            port=int(os.getenv("DB_PORT", "5432")), database=os.getenv("DB_NAME", "diet")).render_as_string(hide_password=False)
    return Settings(
        data_dir=Path(os.getenv("DATA_DIR", str(ROOT / "data" / "runtime"))),
        database_url=database_url,
        jwt_secret=os.getenv("JWT_SECRET_KEY", ""),
        environment=os.getenv("APP_ENV", "development"),
        seed_demo=flag("SEED_DEMO_DATA", True),
        auto_create_tables=flag("AUTO_CREATE_TABLES", True),
        access_token_minutes=int(os.getenv("ACCESS_TOKEN_MINUTES", "30")),
        cors_origins=[x.strip() for x in os.getenv("CORS_ORIGINS", "http://localhost:3000,http://localhost:5173,http://localhost:8080").split(",") if x.strip()],
        ai_enabled=flag("ENABLE_EXTERNAL_AI", False),
        ai_base_url=os.getenv("AI_BASE_URL", "https://api.openai.com/v1").rstrip("/"),
        ai_api_key=os.getenv("AI_API_KEY", ""),
        chat_model=os.getenv("AI_CHAT_MODEL", ""),
        vision_model=os.getenv("AI_VISION_MODEL", ""),
        baidu_dish_enabled=flag("ENABLE_BAIDU_DISH", False),
        baidu_api_key=os.getenv("BAIDU_API_KEY", ""),
        baidu_secret_key=os.getenv("BAIDU_SECRET_KEY", ""),
        rate_limit_enabled=flag("RATE_LIMIT_ENABLED", True),
    ).prepare()
