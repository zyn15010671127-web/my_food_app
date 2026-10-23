import csv
import io

from fastapi import APIRouter, File, HTTPException, Query, Response, UploadFile
from pydantic import ValidationError
from sqlalchemy import or_
from sqlalchemy.exc import IntegrityError
from sqlmodel import select

from app.deps import AdminDep, SessionDep, UserDep
from app.models import Food, Recipe, RecipeIngredient
from app.schemas import FoodRead, FoodSave, MealRead, MealSave, RecipeRead, RecipeRecord, RecipeSave
from app.services.catalog import active_food, active_recipe, make_meal, recipe_read, refresh_related_recipes, save_recipe

router = APIRouter(tags=["食物与菜谱"])


def commit(session):
    try:
        session.commit()
    except IntegrityError:
        session.rollback()
        raise HTTPException(409, "名称重复或数据关联冲突") from None


@router.get("/api/foods", response_model=list[FoodRead], summary="搜索食物库，每一百克营养值")
def list_foods(session: SessionDep, q: str = Query("", max_length=100),
               offset: int = Query(0, ge=0), limit: int = Query(20, ge=1, le=100)):
    statement = select(Food).where(Food.is_active == True)  # noqa: E712
    if q.strip():
        statement = statement.where(Food.name.contains(q.strip(), autoescape=True))
    return session.exec(statement.order_by(Food.id).offset(offset).limit(limit)).all()


@router.get("/api/foods/{food_id}", response_model=FoodRead, summary="查看一种食物")
def get_food(food_id: int, session: SessionDep):
    return active_food(session, food_id)


@router.post("/api/foods", response_model=FoodRead, status_code=201, summary="管理员添加食物")
def add_food(data: FoodSave, session: SessionDep, admin: AdminDep):
    food = Food(**data.model_dump())
    session.add(food)
    commit(session)
    session.refresh(food)
    return food


@router.put("/api/foods/{food_id}", response_model=FoodRead, summary="管理员修改食物，历史饮食快照不变")
def update_food(food_id: int, data: FoodSave, session: SessionDep, admin: AdminDep):
    food = active_food(session, food_id)
    food.sqlmodel_update(data.model_dump())
    session.add(food)
    refresh_related_recipes(session, food.id)
    commit(session)
    session.refresh(food)
    return food


@router.delete("/api/foods/{food_id}", status_code=204, summary="管理员停用食物，保留历史关联")
def disable_food(food_id: int, session: SessionDep, admin: AdminDep) -> Response:
    food = active_food(session, food_id)
    food.is_active = False
    session.add(food)
    # 包含该食物的菜谱同步停用，避免推荐不可用食材。
    ids = session.exec(select(RecipeIngredient.recipe_id).where(RecipeIngredient.food_id == food_id)).all()
    for recipe in session.exec(select(Recipe).where(Recipe.id.in_(ids))).all() if ids else []:
        recipe.is_active = False
        session.add(recipe)
    commit(session)
    return Response(status_code=204)


@router.get("/api/recipes", response_model=list[RecipeRead], summary="查询菜谱和食材做法")
def list_recipes(session: SessionDep, q: str = Query("", max_length=100),
                 offset: int = Query(0, ge=0), limit: int = Query(20, ge=1, le=100)):
    statement = select(Recipe).where(Recipe.is_active == True)  # noqa: E712
    if q.strip():
        statement = statement.where(Recipe.name.contains(q.strip(), autoescape=True))
    recipes = session.exec(statement.order_by(Recipe.id).offset(offset).limit(limit)).all()
    return [recipe_read(session, recipe) for recipe in recipes]


@router.get("/api/recipes/{recipe_id}", response_model=RecipeRead, summary="查看菜谱详情，每份营养及食材克数")
def get_recipe(recipe_id: int, session: SessionDep):
    return recipe_read(session, active_recipe(session, recipe_id))


@router.post("/api/recipes", response_model=RecipeRead, status_code=201, summary="管理员添加菜谱并计算每份营养")
def add_recipe(data: RecipeSave, session: SessionDep, admin: AdminDep):
    recipe = save_recipe(session, data)
    commit(session)
    session.refresh(recipe)
    return recipe_read(session, recipe)


@router.put("/api/recipes/{recipe_id}", response_model=RecipeRead, summary="管理员完整更新菜谱")
def update_recipe(recipe_id: int, data: RecipeSave, session: SessionDep, admin: AdminDep):
    recipe = save_recipe(session, data, active_recipe(session, recipe_id))
    commit(session)
    session.refresh(recipe)
    return recipe_read(session, recipe)


@router.delete("/api/recipes/{recipe_id}", status_code=204, summary="管理员停用菜谱")
def disable_recipe(recipe_id: int, session: SessionDep, admin: AdminDep) -> Response:
    recipe = active_recipe(session, recipe_id)
    recipe.is_active = False
    session.add(recipe)
    commit(session)
    return Response(status_code=204)


@router.post("/api/recipes/{recipe_id}/record", response_model=list[MealRead], status_code=201,
             summary="按份数将整份菜谱食材记录到当前账号")
def record_recipe(recipe_id: int, data: RecipeRecord, session: SessionDep, user: UserDep):
    recipe = active_recipe(session, recipe_id)
    ingredients = session.exec(select(RecipeIngredient).where(RecipeIngredient.recipe_id == recipe.id)).all()
    records = []
    for item in ingredients:
        if item.grams * data.servings > 10000:
            raise HTTPException(422, "单种食材记录不能超过 10000 克，请减少份数")
        records.append(make_meal(session, user.id, MealSave(food_id=item.food_id,
            grams=item.grams * data.servings, meal_type=data.meal_type, record_date=data.record_date), source="recipe"))
    session.commit()
    for record in records:
        session.refresh(record)
    return records


@router.post("/api/admin/foods/import", summary="管理员从 CSV 原子导入食物，按名称新增或更新")
async def import_foods(session: SessionDep, admin: AdminDep, file: UploadFile = File(...)):
    raw = await file.read(1024 * 1024 + 1)
    if len(raw) > 1024 * 1024:
        raise HTTPException(413, "CSV 文件不能超过 1 MB")
    try:
        reader = csv.DictReader(io.StringIO(raw.decode("utf-8-sig")))
        rows = list(reader)
        if not 1 <= len(rows) <= 5000:
            raise ValueError("需要 1 至 5000 行数据")
        required = {"name", "calories_kcal", "protein_g", "carbs_g", "fat_g"}
        if not required.issubset(reader.fieldnames or []):
            raise ValueError("缺少必要列：" + ",".join(sorted(required)))
        values = []
        for number, row in enumerate(rows, 2):
            clean = {key: value for key, value in row.items() if key is not None and value not in ("", None)}
            if "aliases" in clean:
                clean["aliases"] = [v.strip() for v in clean["aliases"].split("|") if v.strip()]
            try:
                values.append(FoodSave.model_validate(clean))
            except ValidationError as error:
                raise ValueError(f"第 {number} 行校验失败：{error.errors(include_input=False, include_url=False)}") from None
        names = [item.name for item in values]
        if len(names) != len(set(names)):
            raise ValueError("同一文件内名称不能重复")
    except (UnicodeDecodeError, csv.Error, ValueError) as error:
        raise HTTPException(422, str(error)) from None
    created, updated = 0, 0
    for item in values:
        food = session.exec(select(Food).where(Food.name == item.name)).first()
        if food is None:
            food = Food(**item.model_dump())
            created += 1
        else:
            food.sqlmodel_update(item.model_dump())
            updated += 1
        session.add(food)
        if food.id is not None:
            refresh_related_recipes(session, food.id)
    commit(session)
    return {"created": created, "updated": updated, "total": len(values)}


@router.post("/api/admin/recipes/import", summary="管理员批量导入菜谱 JSON 数组，按名称更新")
def import_recipes(data: list[RecipeSave], session: SessionDep, admin: AdminDep):
    if not 1 <= len(data) <= 500:
        raise HTTPException(422, "每次导入 1 至 500 道菜谱")
    if len({item.name for item in data}) != len(data):
        raise HTTPException(422, "同批次菜谱名称不能重复")
    for item in data:
        existing = session.exec(select(Recipe).where(Recipe.name == item.name)).first()
        save_recipe(session, item, existing)
    commit(session)
    return {"imported": len(data)}
