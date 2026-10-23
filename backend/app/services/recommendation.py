from fastapi import HTTPException
from sqlmodel import select

from app.models import Recipe, RecipeIngredient, UserProfile
from app.schemas import RecommendResult
from app.services.catalog import recipe_read
from app.services.nutrition import MEAL_SHARES, daily_progress


def recommend(session, user_id, day, meal_type, limit=3, exclude_food_ids=None):
    progress = daily_progress(session, user_id, day)
    profile = session.get(UserProfile, user_id)
    recipes = session.exec(select(Recipe).where(Recipe.is_active == True)).all()  # noqa: E712
    if exclude_food_ids:
        banned = set(session.exec(select(RecipeIngredient.recipe_id).where(
            RecipeIngredient.food_id.in_(exclude_food_ids))).all())
        recipes = [r for r in recipes if r.id not in banned]
    desired_energy = min(progress.remaining.calories_kcal,
        progress.target.calories_kcal * MEAL_SHARES[meal_type])
    desired_energy = max(desired_energy, 100)
    scored = []
    for recipe in recipes:
        energy_error = abs(recipe.calories_kcal - desired_energy) / desired_energy
        protein_target = max(progress.remaining.protein_g * MEAL_SHARES[meal_type], 1)
        protein_error = abs(recipe.protein_g - protein_target) / protein_target
        goal_bonus = 0.15 if profile.goal.value in recipe.goals else 0
        score = energy_error * 0.8 + min(protein_error, 3) * 0.2 - goal_bonus
        scored.append((score, recipe.id, recipe))
    scored.sort(key=lambda item: (item[0], item[1]))
    choices = []
    for score, _, recipe in scored[:limit]:
        choices.append({"recipe": recipe_read(session, recipe).model_dump(mode="json"),
            "match_score": round(100 / (1 + max(score, 0)), 1),
            "reason": "依据当前目标标签、剩余热量和蛋白质配额排序；食材用量为一份。"})
    message = "规则推荐仅供一般饮食参考，请自行核对过敏原和食材禁忌。"
    if progress.remaining.calories_kcal <= 0:
        message = "当天估算热量目标已达到，以下仅列备选菜谱，不表示需要继续进食。"
    if len(choices) < min(limit, 3):
        message += " 当前筛选条件下菜谱不足三套，可调整排除条件或补充菜谱库。"
    return RecommendResult(record_date=day, meal_type=meal_type, remaining=progress.remaining,
        message=message, recommendations=choices)
