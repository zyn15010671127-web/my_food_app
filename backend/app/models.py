from datetime import date, datetime, timezone
from enum import Enum
from uuid import uuid4

from sqlalchemy import Column, Enum as SAEnum, JSON, UniqueConstraint
from sqlmodel import Field, SQLModel


def utcnow():
    return datetime.now(timezone.utc)


def uid():
    return uuid4().hex


class Sex(str, Enum):
    male = "male"
    female = "female"


class Goal(str, Enum):
    lose_fat = "lose_fat"
    gain_muscle = "gain_muscle"
    maintain = "maintain"
    shape = "shape"


class ActivityLevel(str, Enum):
    sedentary = "sedentary"
    light = "light"
    moderate = "moderate"
    high = "high"
    very_high = "very_high"


class MealType(str, Enum):
    breakfast = "breakfast"
    lunch = "lunch"
    dinner = "dinner"
    snack = "snack"


class User(SQLModel, table=True):
    __tablename__ = "users"
    id: int | None = Field(default=None, primary_key=True)
    username: str = Field(index=True, unique=True, max_length=32)
    password_hash: str
    is_admin: bool = False
    token_version: int = 0
    created_at: datetime = Field(default_factory=utcnow)


class UserProfile(SQLModel, table=True):
    __tablename__ = "user_profiles"
    user_id: int = Field(primary_key=True, foreign_key="users.id")
    sex: Sex = Field(sa_column=Column(SAEnum(Sex, native_enum=False), nullable=False))
    age: int
    height_cm: float
    weight_kg: float
    goal: Goal = Field(sa_column=Column(SAEnum(Goal, native_enum=False), nullable=False))
    activity_level: ActivityLevel = Field(sa_column=Column(SAEnum(ActivityLevel, native_enum=False), nullable=False))
    body_fat_percent: float | None = None
    updated_at: datetime = Field(default_factory=utcnow)


class Food(SQLModel, table=True):
    __tablename__ = "foods"
    id: int | None = Field(default=None, primary_key=True)
    name: str = Field(unique=True, index=True, max_length=100)
    aliases: list[str] = Field(default_factory=list, sa_column=Column(JSON, nullable=False))
    calories_kcal: float
    protein_g: float
    carbs_g: float
    fat_g: float
    gi: float | None = None
    source: str = "课程演示数据，非权威营养数据库"
    is_active: bool = True


class Recipe(SQLModel, table=True):
    __tablename__ = "recipes"
    id: int | None = Field(default=None, primary_key=True)
    name: str = Field(unique=True, index=True, max_length=100)
    cuisine: str = "家常"
    tags: list[str] = Field(default_factory=list, sa_column=Column(JSON, nullable=False))
    goals: list[str] = Field(default_factory=list, sa_column=Column(JSON, nullable=False))
    steps: list[str] = Field(default_factory=list, sa_column=Column(JSON, nullable=False))
    calories_kcal: float = 0
    protein_g: float = 0
    carbs_g: float = 0
    fat_g: float = 0
    is_active: bool = True


class RecipeIngredient(SQLModel, table=True):
    __tablename__ = "recipe_ingredients"
    __table_args__ = (UniqueConstraint("recipe_id", "food_id", name="uq_recipe_food"),)
    id: int | None = Field(default=None, primary_key=True)
    recipe_id: int = Field(foreign_key="recipes.id", index=True)
    food_id: int = Field(foreign_key="foods.id")
    grams: float


class NutritionTarget(SQLModel, table=True):
    __tablename__ = "nutrition_targets"
    __table_args__ = (UniqueConstraint("user_id", "record_date", name="uq_target_user_date"),)
    id: int | None = Field(default=None, primary_key=True)
    user_id: int = Field(foreign_key="users.id", index=True)
    record_date: date = Field(index=True)
    bmr_kcal: float
    tdee_kcal: float
    calories_kcal: float
    protein_g: float
    carbs_g: float
    fat_g: float
    goal: Goal = Field(sa_column=Column(SAEnum(Goal, native_enum=False), nullable=False))
    profile_snapshot: dict = Field(default_factory=dict, sa_column=Column(JSON, nullable=False))
    rule_version: str = "mvp-1.0"
    created_at: datetime = Field(default_factory=utcnow)


class UploadedImage(SQLModel, table=True):
    __tablename__ = "uploaded_images"
    id: str = Field(default_factory=uid, primary_key=True, max_length=32)
    user_id: int = Field(foreign_key="users.id", index=True)
    relative_path: str
    width: int
    height: int
    created_at: datetime = Field(default_factory=utcnow)


class Recognition(SQLModel, table=True):
    __tablename__ = "recognitions"
    id: str = Field(default_factory=uid, primary_key=True, max_length=32)
    user_id: int = Field(foreign_key="users.id", index=True)
    image_id: str = Field(foreign_key="uploaded_images.id")
    status: str = "manual_required"
    mode: str = "manual_fallback"
    message: str = ""
    dishes: list[dict] = Field(default_factory=list, sa_column=Column(JSON, nullable=False))
    confirmed_record_ids: list[int] = Field(default_factory=list, sa_column=Column(JSON, nullable=False))
    created_at: datetime = Field(default_factory=utcnow)


class MealRecord(SQLModel, table=True):
    __tablename__ = "meal_records"
    id: int | None = Field(default=None, primary_key=True)
    user_id: int = Field(foreign_key="users.id", index=True)
    food_id: int = Field(foreign_key="foods.id", index=True)
    grams: float
    meal_type: MealType = Field(sa_column=Column(SAEnum(MealType, native_enum=False), nullable=False))
    record_date: date = Field(index=True)
    food_name: str
    calories_kcal: float
    protein_g: float
    carbs_g: float
    fat_g: float
    source: str = "manual"
    created_at: datetime = Field(default_factory=utcnow)


class Conversation(SQLModel, table=True):
    __tablename__ = "ai_conversations"
    id: str = Field(default_factory=uid, primary_key=True, max_length=32)
    user_id: int = Field(foreign_key="users.id", index=True)
    title: str = "营养咨询"
    created_at: datetime = Field(default_factory=utcnow)


class ChatMessage(SQLModel, table=True):
    __tablename__ = "ai_messages"
    id: int | None = Field(default=None, primary_key=True)
    conversation_id: str = Field(foreign_key="ai_conversations.id", index=True)
    role: str
    content: str
    mode: str = "local_knowledge"
    sources: list[dict] = Field(default_factory=list, sa_column=Column(JSON, nullable=False))
    created_at: datetime = Field(default_factory=utcnow)
