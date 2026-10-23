import csv
import json

from sqlmodel import select

from app.config import ROOT
from app.models import ActivityLevel, Food, Goal, Recipe, Sex, User, UserProfile
from app.schemas import FoodSave, RecipeSave
from app.security import hash_password
from app.services.catalog import save_recipe


def seed_demo(session):
    """仅显式开启开发演示模式时使用；不覆盖用户已有数据。"""
    for username, password, admin in [("demo_user", "DemoPass123!", False), ("admin", "AdminDemo123!", True)]:
        user = session.exec(select(User).where(User.username == username)).first()
        if user is None:
            user = User(username=username, password_hash=hash_password(password), is_admin=admin)
            session.add(user)
            session.flush()
        if session.get(UserProfile, user.id) is None:
            session.add(UserProfile(user_id=user.id, sex=Sex.female, age=21, height_cm=165,
                weight_kg=55, goal=Goal.maintain, activity_level=ActivityLevel.moderate))
    foods = {}
    with (ROOT / "data" / "demo_foods.csv").open(encoding="utf-8-sig", newline="") as stream:
        for row in csv.DictReader(stream):
            row["aliases"] = [a for a in row.get("aliases", "").split("|") if a]
            if not row.get("gi"):
                row.pop("gi", None)
            data = FoodSave.model_validate(row)
            food = session.exec(select(Food).where(Food.name == data.name)).first()
            if food is None:
                food = Food(**data.model_dump())
                session.add(food)
                session.flush()
            foods[food.name] = food.id
    recipes = json.loads((ROOT / "data" / "demo_recipes.json").read_text(encoding="utf-8"))
    for row in recipes:
        if session.exec(select(Recipe).where(Recipe.name == row["name"])).first() is not None:
            continue
        data = {**row, "ingredients": [{"food_id": foods[i["food_name"]], "grams": i["grams"]} for i in row["ingredients"]]}
        save_recipe(session, RecipeSave.model_validate(data))
    session.commit()
