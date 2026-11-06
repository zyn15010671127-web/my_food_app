import io
from datetime import timedelta

import httpx
import jwt
import pytest
from PIL import Image
from sqlmodel import Session, select

from app.models import MealRecord, User
from app.security import create_token
from app.services import provider
from app.services.nutrition import today
from conftest import login


def meal(food_id, *, grams=150, day=None, meal_type="lunch"):
    return {"food_id": food_id, "grams": grams, "meal_type": meal_type,
            "record_date": str(day or today())}


def add_meal(client, headers, food_id, **kwargs):
    response = client.post("/api/meal-records", json=meal(food_id, **kwargs), headers=headers)
    assert response.status_code == 201, response.text
    return response.json()


def image_file():
    stream = io.BytesIO()
    Image.new("RGB", (64, 48), "orange").save(stream, "PNG")
    return stream.getvalue()


def upload(client, headers):
    response = client.post("/api/uploads/images", headers=headers,
                           files={"file": ("photo.png", image_file(), "image/png")})
    assert response.status_code == 201, response.text
    return response.json()["id"]


def test_health_and_local_docs(client):
    assert client.get("/api/health").json()["status"] == "ok"
    docs = client.get("/docs")
    assert docs.status_code == 200 and "/docs-assets/swagger-ui-bundle.js" in docs.text
    assert client.get("/docs-assets/swagger-ui-bundle.js").status_code == 200
    assert len(client.get("/openapi.json").json()["paths"]) >= 30


def test_register_hash_and_duplicate(client):
    response = client.post("/api/auth/register", json={"username": "new_user", "password": "NewPass123!"})
    assert response.status_code == 201
    assert "password" not in response.text
    with Session(client.app.state.engine) as session:
        user = session.exec(select(User).where(User.username == "new_user")).one()
        assert user.password_hash.startswith("$argon2") and not user.is_admin
    assert client.post("/api/auth/register", json={"username": "new_user", "password": "NewPass123!"}).status_code == 409


@pytest.mark.parametrize("payload", [{"username": "bad name", "password": "Password123!"},
    {"username": "valid", "password": "short"},
    {"username": "valid", "password": "Password123!", "is_admin": True}])
def test_register_validation(client, payload):
    response = client.post("/api/auth/register", json=payload)
    assert response.status_code == 422
    assert "Password123!" not in response.text


def test_wrong_password_and_unknown_user(client):
    for username in ["demo_user", "unknown_user"]:
        response = client.post("/api/auth/login", json={"username": username, "password": "WrongPassword!"})
        assert response.status_code == 401
        assert response.json()["detail"] == "用户名或密码错误"


def test_auth_and_logout_revocation(client, headers):
    assert client.get("/api/auth/me").status_code == 401
    assert client.get("/api/auth/me", headers=headers).json()["username"] == "demo_user"
    assert client.post("/api/auth/logout", headers=headers).status_code == 204
    assert client.get("/api/auth/me", headers=headers).status_code == 401
    assert client.get("/api/auth/me", headers=login(client)).status_code == 200


@pytest.mark.parametrize("kind", ["expired", "tampered", "missing_exp", "wrong_audience"])
def test_invalid_tokens(client, kind):
    settings = client.app.state.settings
    with Session(client.app.state.engine) as session:
        user = session.exec(select(User).where(User.username == "demo_user")).one()
        token = create_token(user, settings)
    claims = jwt.decode(token, settings.jwt_secret, algorithms=["HS256"], audience="diet-app", issuer="diet-backend")
    if kind == "expired":
        claims["exp"] = 1
    elif kind == "missing_exp":
        claims.pop("exp")
    elif kind == "wrong_audience":
        claims["aud"] = "another-app"
    token = jwt.encode(claims, settings.jwt_secret if kind != "tampered" else "another-secret-" * 4, algorithm="HS256")
    assert client.get("/api/auth/me", headers={"Authorization": "Bearer " + token}).status_code == 401


def test_profile_validation_and_isolation(client, headers, other_headers):
    profile = client.get("/api/profile/me", headers=headers).json()
    assert profile["bmi"] == 20.2
    assert client.get("/api/profile/me", headers=other_headers).status_code == 404
    body = {key: profile[key] for key in ["sex", "age", "height_cm", "weight_kg", "goal", "activity_level", "body_fat_percent"]}
    body["weight_kg"] = 56
    assert client.put("/api/profile/me", json=body, headers=headers).json()["bmi"] == 20.57
    body["height_cm"] = 0
    assert client.put("/api/profile/me", json=body, headers=headers).status_code == 422


def test_catalog_requires_admin(client, headers, admin_headers):
    data = {"name": "权限测试食品", "calories_kcal": 100, "protein_g": 5, "carbs_g": 15, "fat_g": 2}
    assert client.post("/api/foods", json=data).status_code == 401
    assert client.post("/api/foods", json=data, headers=headers).status_code == 403
    assert client.post("/api/foods", json=data, headers=admin_headers).status_code == 201
    assert client.post("/api/foods", json=data, headers=admin_headers).status_code == 409


def test_nonfinite_nutrition_rejected(client, admin_headers):
    data = {"name": "非有限测试", "calories_kcal": "Infinity", "protein_g": 5, "carbs_g": 15, "fat_g": 2}
    assert client.post("/api/foods", json=data, headers=admin_headers).status_code == 422


def test_meal_scale_update_delete_and_ownership(client, headers, other_headers, food_id):
    record = add_meal(client, headers, food_id)
    assert [record[key] for key in ["calories_kcal", "protein_g", "carbs_g", "fat_g"]] == [150, 7.5, 22.5, 3]
    path = f"/api/meal-records/{record['id']}"
    assert client.put(path, json=meal(food_id, grams=200), headers=other_headers).status_code == 404
    assert client.delete(path, headers=other_headers).status_code == 404
    updated = client.put(path, json=meal(food_id, grams=200), headers=headers)
    assert updated.status_code == 200 and updated.json()["calories_kcal"] == 200
    assert client.delete(path, headers=headers).status_code == 204
    assert client.delete(path, headers=headers).status_code == 404


def test_missing_food_and_invalid_grams(client, headers, food_id):
    assert client.post("/api/meal-records", json=meal(999999), headers=headers).status_code == 404
    assert client.post("/api/meal-records", json=meal(food_id, grams=0), headers=headers).status_code == 422


def test_history_snapshot_stable(client, headers, admin_headers, food_id):
    record = add_meal(client, headers, food_id)
    food = client.get(f"/api/foods/{food_id}").json()
    food.pop("id"); food.pop("is_active")
    food["calories_kcal"] = 200
    assert client.put(f"/api/foods/{food_id}", json=food, headers=admin_headers).status_code == 200
    rows = client.get("/api/meal-records/me", params={"record_date": str(today())}, headers=headers).json()
    assert rows[0]["calories_kcal"] == 150
    assert client.put(f"/api/meal-records/{record['id']}", json=meal(food_id, grams=100), headers=headers).json()["calories_kcal"] == 200


def test_daily_aggregation_no_pagination(client, headers, other_headers, food_id):
    user_id = client.get("/api/auth/me", headers=headers).json()["id"]
    with Session(client.app.state.engine) as session:
        for _ in range(26):
            session.add(MealRecord(user_id=user_id, food_id=food_id, grams=100, meal_type="lunch", record_date=today(), food_name="测试食物", calories_kcal=100, protein_g=5, carbs_g=15, fat_g=2))
        session.commit()
    listing = client.get("/api/meal-records/me", params={"record_date": str(today())}, headers=headers).json()
    assert len(listing) == 20
    summary = client.get("/api/nutrition/daily", params={"record_date": str(today())}, headers=headers).json()
    assert summary["record_count"] == 26 and summary["total"]["calories_kcal"] == 2600
    assert len(summary["meals"]) == 4
    assert client.get("/api/nutrition/daily", params={"record_date": str(today())}, headers=other_headers).json()["record_count"] == 0


def test_empty_day_and_trend_bounds(client, headers):
    day = str(today() - timedelta(days=30))
    result = client.get("/api/nutrition/daily", params={"record_date": day}, headers=headers).json()
    assert result["record_count"] == 0 and result["total"]["calories_kcal"] == 0
    result = client.get("/api/nutrition/weekly", headers=headers).json()
    assert len(result["days"]) == 7
    assert client.get("/api/nutrition/trends", params={"start_date": str(today()), "end_date": day}, headers=headers).status_code == 422


def test_target_math_and_saved_snapshot(client, headers):
    target = client.get("/api/nutrition/target", headers=headers).json()
    assert target["bmr_kcal"] == 1315.25 and target["tdee_kcal"] == 2038.64
    assert target["protein_g"] == 66
    profile = client.get("/api/profile/me", headers=headers).json()
    body = {key: profile[key] for key in ["sex", "age", "height_cm", "weight_kg", "goal", "activity_level", "body_fat_percent"]}
    body["weight_kg"] = 60
    client.put("/api/profile/me", json=body, headers=headers)
    assert client.get("/api/nutrition/target", headers=headers).json()["calories_kcal"] == target["calories_kcal"]
    recalculated = client.post("/api/nutrition/target/recalculate", headers=headers)
    assert recalculated.status_code == 200 and recalculated.json()["calories_kcal"] > target["calories_kcal"]


def test_target_missing_profile_and_past_recalculate(client, headers, other_headers):
    assert client.get("/api/nutrition/target", headers=other_headers).status_code == 404
    past = str(today() - timedelta(days=1))
    assert client.post("/api/nutrition/target/recalculate", params={"record_date": past}, headers=headers).status_code == 409


def test_progress_excess_not_negative(client, headers, food_id):
    add_meal(client, headers, food_id, grams=10000)
    result = client.get("/api/nutrition/progress", headers=headers).json()
    assert result["remaining"]["calories_kcal"] == 0
    assert result["exceeded"]["calories_kcal"] > 0
    assert result["completion_percent"]["calories_kcal"] > 100


def test_recommendations_and_record_recipe(client, headers):
    result = client.get("/api/recommendations", headers=headers)
    assert result.status_code == 200 and len(result.json()["recommendations"]) == 3
    recipe = result.json()["recommendations"][0]["recipe"]
    assert recipe["ingredients"] and recipe["steps"]
    records = client.post(f"/api/recipes/{recipe['id']}/record", headers=headers,
        json={"meal_type": "lunch", "record_date": str(today()), "servings": 1})
    assert records.status_code == 201
    assert len(records.json()) == len(recipe["ingredients"])
    assert sum(row["calories_kcal"] for row in records.json()) == pytest.approx(recipe["calories_kcal"], abs=0.1)


def test_recommendation_exclusions(client, headers):
    ids = [food["id"] for food in client.get("/api/foods", params={"limit": 100}).json()]
    result = client.get("/api/recommendations", params=[("exclude_food_ids", str(i)) for i in ids], headers=headers)
    assert result.status_code == 200 and result.json()["recommendations"] == []


def test_csv_import_atomicity(client, admin_headers):
    data = "name,calories_kcal,protein_g,carbs_g,fat_g\n导入正确,100,5,15,2\n导入错误,-1,5,15,2\n"
    response = client.post("/api/admin/foods/import", headers=admin_headers, files={"file": ("foods.csv", data.encode(), "text/csv")})
    assert response.status_code == 422
    assert client.get("/api/foods", params={"q": "导入正确"}).json() == []
    data = data.replace("-1", "100")
    response = client.post("/api/admin/foods/import", headers=admin_headers, files={"file": ("foods.csv", data.encode(), "text/csv")})
    assert response.status_code == 200 and response.json()["created"] == 2


def test_recipe_duplicate_and_bad_reference(client, admin_headers, food_id):
    data = {"name": "新增菜谱", "steps": ["演示步骤"], "ingredients": [{"food_id": food_id, "grams": 100}]}
    assert client.post("/api/recipes", json=data, headers=admin_headers).status_code == 201
    assert client.post("/api/recipes", json=data, headers=admin_headers).status_code == 409
    data["name"] = "关联错误"
    data["ingredients"][0]["food_id"] = 999999
    assert client.post("/api/recipes", json=data, headers=admin_headers).status_code == 404


def test_image_validation_and_privacy(client, headers, other_headers):
    assert client.post("/api/uploads/images", headers=headers, files={"file": ("bad.png", b'not an image', "image/png")}).status_code == 422
    image_id = upload(client, headers)
    response = client.get(f"/api/uploads/images/{image_id}", headers=headers)
    assert response.status_code == 200 and response.headers["content-type"] == "image/jpeg"
    assert client.get(f"/api/uploads/images/{image_id}", headers=other_headers).status_code == 404


def test_recognition_fallback_confirm_once(client, headers, other_headers, food_id):
    image_id = upload(client, headers)
    response = client.post("/api/recognitions", json={"image_id": image_id}, headers=headers)
    assert response.status_code == 201 and response.json()["status"] == "manual_required"
    recognition_id = response.json()["id"]
    data = {"meal_type": "lunch", "record_date": str(today()), "items": [{"food_id": food_id, "grams": 150}]}
    assert client.post(f"/api/recognitions/{recognition_id}/confirm", json=data, headers=other_headers).status_code == 404
    result = client.post(f"/api/recognitions/{recognition_id}/confirm", json=data, headers=headers)
    assert result.status_code == 201 and result.json()[0]["calories_kcal"] == 150
    assert client.post(f"/api/recognitions/{recognition_id}/confirm", json=data, headers=headers).status_code == 409


def test_failed_confirmation_rolls_back(client, headers, food_id):
    image_id = upload(client, headers)
    recognition_id = client.post("/api/recognitions", json={"image_id": image_id}, headers=headers).json()["id"]
    data = {"meal_type": "lunch", "record_date": str(today()), "items": [{"food_id": food_id, "grams": 100}, {"food_id": 999999, "grams": 100}]}
    assert client.post(f"/api/recognitions/{recognition_id}/confirm", json=data, headers=headers).status_code == 404
    assert client.get("/api/nutrition/daily", params={"record_date": str(today())}, headers=headers).json()["record_count"] == 0
    data["items"].pop()
    assert client.post(f"/api/recognitions/{recognition_id}/confirm", json=data, headers=headers).status_code == 201


def test_external_vision_mock(client, headers, monkeypatch):
    settings = client.app.state.settings
    settings.ai_enabled, settings.vision_model, settings.ai_api_key = True, "mock-vision", "test-key"
    def fake_post(url, **kwargs):
        assert kwargs["json"]["model"] == "mock-vision"
        return httpx.Response(200, request=httpx.Request("POST", url), json={"choices": [{"message": {"content": '{"dishes":[{"name":"米饭","confidence":0.9}]}'}}]})
    monkeypatch.setattr("app.services.provider.httpx.post", fake_post)
    image_id = upload(client, headers)
    result = client.post("/api/recognitions", headers=headers, json={"image_id": image_id, "allow_external_processing": True})
    assert result.json()["mode"] == "external_vision" and result.json()["dishes"][0]["food_id"] is not None


def test_external_vision_invalid_response_fallback(client, headers, monkeypatch):
    settings = client.app.state.settings
    settings.ai_enabled, settings.vision_model, settings.ai_api_key = True, "mock-vision", "test-key"
    monkeypatch.setattr("app.services.provider.httpx.post", lambda url, **kwargs: httpx.Response(200,
        request=httpx.Request("POST", url), json={"choices": [{"message": {"content": "not json"}}]}))
    image_id = upload(client, headers)
    result = client.post("/api/recognitions", headers=headers, json={"image_id": image_id, "allow_external_processing": True})
    assert result.json()["status"] == "manual_required"


def test_external_processing_requires_consent(client, headers, monkeypatch):
    settings = client.app.state.settings
    settings.ai_enabled, settings.vision_model, settings.ai_api_key = True, "mock-vision", "test-key"
    def forbidden(*args, **kwargs):
        raise AssertionError("External provider called without consent")
    monkeypatch.setattr("app.services.provider.httpx.post", forbidden)
    image_id = upload(client, headers)
    result = client.post("/api/recognitions", headers=headers, json={"image_id": image_id})
    assert result.json()["status"] == "manual_required"


def test_baidu_dish_auth_and_top1(client, headers, monkeypatch):
    settings = client.app.state.settings
    settings.baidu_dish_enabled = True
    settings.baidu_api_key = "test-baidu-key"
    settings.baidu_secret_key = "test-baidu-secret"
    monkeypatch.setattr(provider, "_baidu_token_cache", {})
    calls = []

    def fake_post(url, **kwargs):
        calls.append(url)
        request = httpx.Request("POST", url)
        if url == provider._BAIDU_TOKEN_URL:
            assert kwargs["params"]["grant_type"] == "client_credentials"
            assert kwargs["params"]["client_id"] == "test-baidu-key"
            assert kwargs["params"]["client_secret"] == "test-baidu-secret"
            return httpx.Response(200, request=request,
                json={"access_token": "test-baidu-token", "expires_in": 2592000})
        assert url == provider._BAIDU_DISH_URL
        assert kwargs["params"] == {"access_token": "test-baidu-token"}
        assert kwargs["data"]["top_num"] == 5
        assert kwargs["data"]["image"]
        return httpx.Response(200, request=request, json={"result": [
            {"name": "鱼香肉丝", "probability": "0.96"},
            {"name": "宫保鸡丁", "probability": "0.02"},
        ]})

    monkeypatch.setattr(provider.httpx, "post", fake_post)
    image_id = upload(client, headers)
    response = client.post("/api/recognitions", headers=headers,
        json={"image_id": image_id, "allow_external_processing": True})
    assert response.status_code == 201, response.text
    result = response.json()
    assert result["mode"] == "baidu_dish" and result["status"] == "recognized"
    assert len(result["dishes"]) == 1
    assert result["dishes"][0]["name"] == "鱼香肉丝"
    assert result["dishes"][0]["confidence"] == 0.96
    assert result["dishes"][0]["food_id"] is not None
    assert calls == [provider._BAIDU_TOKEN_URL, provider._BAIDU_DISH_URL]


def test_baidu_dish_failure_falls_back(client, headers, monkeypatch):
    settings = client.app.state.settings
    settings.baidu_dish_enabled = True
    settings.baidu_api_key = "test-baidu-key"
    settings.baidu_secret_key = "test-baidu-secret"
    monkeypatch.setattr(provider, "_baidu_access_token", lambda settings: "test-token")

    def fake_post(url, **kwargs):
        return httpx.Response(200, request=httpx.Request("POST", url),
            json={"error_code": 216201, "error_msg": "invalid image"})

    monkeypatch.setattr(provider.httpx, "post", fake_post)
    image_id = upload(client, headers)
    response = client.post("/api/recognitions", headers=headers,
        json={"image_id": image_id, "allow_external_processing": True})
    assert response.status_code == 201
    assert response.json()["status"] == "manual_required"
    assert "手动" in response.json()["message"]


def test_baidu_dish_requires_consent(client, headers, monkeypatch):
    settings = client.app.state.settings
    settings.baidu_dish_enabled = True
    settings.baidu_api_key = "test-baidu-key"
    settings.baidu_secret_key = "test-baidu-secret"

    def forbidden(*args, **kwargs):
        raise AssertionError("Baidu called without consent")

    monkeypatch.setattr(provider.httpx, "post", forbidden)
    image_id = upload(client, headers)
    response = client.post("/api/recognitions", headers=headers, json={"image_id": image_id})
    assert response.status_code == 201
    assert response.json()["status"] == "manual_required"
    assert "未同意" in response.json()["message"]


def test_chat_history_and_owner(client, headers, other_headers):
    result = client.post("/api/chat/messages", headers=headers, json={"message": "蛋白质是什么"})
    assert result.status_code == 200 and result.json()["mode"] == "local_knowledge"
    conversation_id = result.json()["conversation_id"]
    assert result.json()["sources"]
    path = f"/api/chat/conversations/{conversation_id}/messages"
    assert len(client.get(path, headers=headers).json()) == 2
    assert client.get(path, headers=other_headers).status_code == 404
    assert client.post("/api/chat/messages", headers=other_headers, json={"message": "你好", "conversation_id": conversation_id}).status_code == 404
    assert client.delete(f"/api/chat/conversations/{conversation_id}", headers=headers).status_code == 204


def test_chat_external_failure_fallback(client, headers, monkeypatch):
    settings = client.app.state.settings
    settings.ai_enabled, settings.chat_model, settings.ai_api_key = True, "mock-chat", "test-key"
    monkeypatch.setattr("app.services.provider.httpx.post", lambda url, **kwargs: httpx.Response(503, request=httpx.Request("POST", url)))
    result = client.post("/api/chat/messages", headers=headers, json={"message": "蛋白质", "allow_external_processing": True})
    assert result.status_code == 200 and result.json()["mode"] == "local_knowledge"


def test_chat_medical_scope(client, headers):
    result = client.post("/api/chat/messages", headers=headers, json={"message": "糖尿病怎么吃药"})
    assert result.status_code == 200 and "不能" in result.json()["reply"]


@pytest.mark.parametrize("message,agent", [("推荐午餐", "diet_planner"), ("查看目标", "nutrition_progress"), ("蛋白质是什么", "nutrition_advisor")])
def test_agent_routing(client, headers, message, agent):
    response = client.post("/api/agents/dispatch", json={"message": message}, headers=headers)
    assert response.status_code == 200 and response.json()["agent"] == agent


def test_account_export_and_delete(client, headers, food_id):
    add_meal(client, headers, food_id)
    upload(client, headers)
    client.post("/api/chat/messages", headers=headers, json={"message": "蛋白质"})
    export = client.get("/api/account/export", headers=headers)
    assert export.status_code == 200 and "password_hash" not in export.text and "JWT" not in export.text
    assert export.json()["meal_records"]
    assert client.request("DELETE", "/api/account", headers=headers, json={"password": "wrong"}).status_code == 401
    assert client.request("DELETE", "/api/account", headers=headers, json={"password": "DemoPass123!"}).status_code == 204
    assert client.get("/api/auth/me", headers=headers).status_code == 401
    assert not list((client.app.state.settings.data_dir / "uploads").rglob("*.jpg"))


def test_rate_limit(client):
    client.app.state.settings.rate_limit_enabled = True
    for _ in range(20):
        response = client.post("/api/auth/login", json={"username": "x", "password": "x"})
        assert response.status_code == 401
    assert client.post("/api/auth/login", json={"username": "x", "password": "x"}).status_code == 429


def test_cors_allowlist(client):
    headers = {"Origin": "http://localhost:5173", "Access-Control-Request-Method": "GET"}
    assert client.options("/api/auth/me", headers=headers).headers["access-control-allow-origin"] == "http://localhost:5173"
    headers["Origin"] = "https://untrusted.example"
    assert "access-control-allow-origin" not in client.options("/api/auth/me", headers=headers).headers
