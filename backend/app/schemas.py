from datetime import date, datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field, FiniteFloat, computed_field

from app.models import ActivityLevel, Goal, MealType, Sex


class Schema(BaseModel):
    model_config = ConfigDict(from_attributes=True, extra="forbid", str_strip_whitespace=True)


class Register(Schema):
    username: str = Field(min_length=3, max_length=32, pattern=r"^[a-z0-9_]+$")
    password: str = Field(min_length=8, max_length=128)
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=False)


class Login(Schema):
    username: str = Field(min_length=1, max_length=32)
    password: str = Field(min_length=1, max_length=128)
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=False)


class UserRead(Schema):
    id: int
    username: str
    is_admin: bool


class Token(Schema):
    access_token: str
    token_type: str = "bearer"
    expires_in: int


class ProfileSave(Schema):
    sex: Sex
    age: int = Field(ge=18, le=120)
    height_cm: FiniteFloat = Field(ge=50, le=260)
    weight_kg: FiniteFloat = Field(ge=10, le=500)
    goal: Goal
    activity_level: ActivityLevel
    body_fat_percent: FiniteFloat | None = Field(default=None, gt=0, lt=100)


class ProfileRead(ProfileSave):
    user_id: int
    updated_at: datetime

    @computed_field
    @property
    def bmi(self) -> float:
        return round(self.weight_kg / (self.height_cm / 100) ** 2, 2)


class FoodSave(Schema):
    name: str = Field(min_length=1, max_length=100)
    aliases: list[str] = Field(default_factory=list, max_length=20)
    calories_kcal: FiniteFloat = Field(ge=0, le=1000)
    protein_g: FiniteFloat = Field(ge=0, le=100)
    carbs_g: FiniteFloat = Field(ge=0, le=100)
    fat_g: FiniteFloat = Field(ge=0, le=100)
    gi: FiniteFloat | None = Field(default=None, ge=0, le=150)
    source: str = Field(default="用户整理，来源待核实", min_length=1, max_length=300)


class FoodRead(FoodSave):
    id: int
    is_active: bool


class IngredientSave(Schema):
    food_id: int = Field(gt=0)
    grams: FiniteFloat = Field(gt=0, le=10000)


class IngredientRead(IngredientSave):
    food_name: str


class RecipeSave(Schema):
    name: str = Field(min_length=1, max_length=100)
    cuisine: str = Field(default="家常", min_length=1, max_length=50)
    tags: list[str] = Field(default_factory=list, max_length=20)
    goals: list[Goal] = Field(default_factory=list, max_length=4)
    steps: list[str] = Field(min_length=1, max_length=30)
    ingredients: list[IngredientSave] = Field(min_length=1, max_length=40)


class NutritionTotals(Schema):
    calories_kcal: float = 0
    protein_g: float = 0
    carbs_g: float = 0
    fat_g: float = 0


class RecipeRead(NutritionTotals):
    id: int
    name: str
    cuisine: str
    tags: list[str]
    goals: list[str]
    steps: list[str]
    ingredients: list[IngredientRead]
    is_active: bool


class MealSave(Schema):
    food_id: int = Field(gt=0)
    grams: FiniteFloat = Field(gt=0, le=10000)
    meal_type: MealType
    record_date: date


class MealRead(MealSave, NutritionTotals):
    id: int
    user_id: int
    food_name: str
    source: str


class MealSummary(NutritionTotals):
    meal_type: MealType
    record_count: int = 0


class DailySummary(Schema):
    record_date: date
    record_count: int
    total: NutritionTotals
    meals: list[MealSummary]


class TargetRead(NutritionTotals):
    id: int
    record_date: date
    bmr_kcal: float
    tdee_kcal: float
    goal: Goal
    rule_version: str
    created_at: datetime
    basis: str = "profile_snapshot_at_creation"
    notice: str = "基于档案的成人一般营养估算，仅供参考，不适用于孕哺期或疾病饮食处方。"


class DailyProgress(Schema):
    record_date: date
    target: TargetRead
    consumed: NutritionTotals
    remaining: NutritionTotals
    exceeded: NutritionTotals
    completion_percent: NutritionTotals


class RecipeRecord(Schema):
    meal_type: MealType
    record_date: date
    servings: FiniteFloat = Field(default=1, gt=0, le=10)


class RecommendResult(Schema):
    record_date: date
    meal_type: MealType
    remaining: NutritionTotals
    message: str
    recommendations: list[dict]


class RecognitionRequest(Schema):
    image_id: str = Field(min_length=32, max_length=32, pattern=r"^[a-f0-9]+$")
    allow_external_processing: bool = False


class RecognitionRead(Schema):
    id: str
    image_id: str
    status: str
    mode: str
    message: str
    dishes: list[dict]
    confirmed_record_ids: list[int]


class RecognitionConfirm(Schema):
    meal_type: MealType
    record_date: date
    items: list[IngredientSave] = Field(min_length=1, max_length=30)


class ChatRequest(Schema):
    message: str = Field(min_length=1, max_length=2000)
    conversation_id: str | None = Field(default=None, min_length=32, max_length=32, pattern=r"^[a-f0-9]+$")
    allow_external_processing: bool = False


class ChatResponse(Schema):
    conversation_id: str
    reply: str
    mode: str
    sources: list[dict]


class DispatchRequest(Schema):
    message: str = Field(min_length=1, max_length=2000)
    record_date: date | None = None
    meal_type: MealType = MealType.lunch
    image_id: str | None = None
    allow_external_processing: bool = False


class DeleteAccount(Schema):
    password: str = Field(min_length=1, max_length=128)
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=False)
