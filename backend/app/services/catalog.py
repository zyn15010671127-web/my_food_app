from fastapi import HTTPException
from sqlalchemy.exc import IntegrityError
from sqlmodel import select

from app.models import Food, MealRecord, Recipe, RecipeIngredient
from app.schemas import IngredientRead, MealSave, RecipeRead
from app.services.nutrition import NUTRIENTS


def active_food(session, food_id):
    food = session.get(Food, food_id)
    if food is None or not food.is_active:
        raise HTTPException(404, "食物不存在或已停用")
    return food


def meal_values(food, grams):
    return {"food_name": food.name, **{key: round(getattr(food, key) * grams / 100, 2) for key in NUTRIENTS}}


def make_meal(session, user_id, data: MealSave, source="manual"):
    food = active_food(session, data.food_id)
    record = MealRecord(user_id=user_id, **data.model_dump(), **meal_values(food, data.grams), source=source)
    session.add(record)
    return record


def owned_record(session, user_id, record_id):
    record = session.exec(select(MealRecord).where(
        MealRecord.id == record_id, MealRecord.user_id == user_id)).first()
    if record is None:
        raise HTTPException(404, "饮食记录不存在")
    return record


def active_recipe(session, recipe_id):
    recipe = session.get(Recipe, recipe_id)
    if recipe is None or not recipe.is_active:
        raise HTTPException(404, "菜谱不存在或已停用")
    return recipe


def recipe_read(session, recipe):
    rows = session.exec(select(RecipeIngredient, Food.name).join(Food, RecipeIngredient.food_id == Food.id)
        .where(RecipeIngredient.recipe_id == recipe.id)).all()
    return RecipeRead(**recipe.model_dump(), ingredients=[IngredientRead(food_id=i.food_id, grams=i.grams, food_name=name) for i, name in rows])


def refresh_related_recipes(session, food_id):
    """菜谱反映当前食物库；已保存的饮食记录仍使用历史快照。"""
    recipe_ids = session.exec(select(RecipeIngredient.recipe_id).where(RecipeIngredient.food_id == food_id)).all()
    for recipe_id in recipe_ids:
        recipe = session.get(Recipe, recipe_id)
        rows = session.exec(select(RecipeIngredient, Food).join(Food, RecipeIngredient.food_id == Food.id)
            .where(RecipeIngredient.recipe_id == recipe_id)).all()
        recipe.sqlmodel_update({key: round(sum(getattr(food, key) * item.grams / 100 for item, food in rows), 2)
                                 for key in NUTRIENTS})
        session.add(recipe)


def save_recipe(session, data, recipe=None):
    ids = [item.food_id for item in data.ingredients]
    if len(ids) != len(set(ids)):
        raise HTTPException(422, "同一菜谱中食材不能重复，请合并用量")
    foods = {item.food_id: active_food(session, item.food_id) for item in data.ingredients}
    values = data.model_dump(exclude={"ingredients", "goals"})
    values["goals"] = [goal.value for goal in data.goals]
    values.update({key: round(sum(getattr(foods[item.food_id], key) * item.grams / 100 for item in data.ingredients), 2) for key in NUTRIENTS})
    if recipe is None:
        recipe = Recipe(**values)
    else:
        recipe.sqlmodel_update(values)
        for ingredient in session.exec(select(RecipeIngredient).where(RecipeIngredient.recipe_id == recipe.id)).all():
            session.delete(ingredient)
        session.flush()
    session.add(recipe)
    try:
        session.flush()
    except IntegrityError:
        session.rollback()
        raise HTTPException(409, "菜谱名称重复或食材关联冲突") from None
    for item in data.ingredients:
        session.add(RecipeIngredient(recipe_id=recipe.id, **item.model_dump()))
    return recipe
