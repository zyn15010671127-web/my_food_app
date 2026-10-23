from datetime import timedelta

from sqlmodel import Session, select

from app.models import ChatMessage, Conversation, MealRecord, NutritionTarget, Recognition, UploadedImage, UserProfile
from app.services.nutrition import today
from conftest import login


def test_recipe_refresh_when_food_changes(client, admin_headers):
    recipe = client.get('/api/recipes', params={'limit': 1}).json()[0]
    food_id = recipe['ingredients'][0]['food_id']
    food = client.get(f'/api/foods/{food_id}').json()
    original = recipe['calories_kcal']
    grams = recipe['ingredients'][0]['grams']
    food.pop('id'); food.pop('is_active')
    food['calories_kcal'] += 10
    assert client.put(f'/api/foods/{food_id}', headers=admin_headers, json=food).status_code == 200
    updated = client.get(f"/api/recipes/{recipe['id']}").json()
    assert abs(updated['calories_kcal'] - original - grams / 10) < 0.02


def test_password_spaces_preserved_on_account_deletion(client):
    password = '  ExamplePass123!  '
    assert client.post('/api/auth/register', json={'username': 'space_user', 'password': password}).status_code == 201
    auth = login(client, 'space_user', password)
    assert client.request('DELETE', '/api/account', headers=auth, json={'password': password}).status_code == 204


def test_csv_import_does_not_commit_before_all_rows_are_valid(client, admin_headers, food_id):
    before = client.get(f'/api/foods/{food_id}').json()['calories_kcal']
    data = 'name,calories_kcal,protein_g,carbs_g,fat_g\n测试食物,200,5,15,2\n坏记录,-5,5,15,2\n'
    result = client.post('/api/admin/foods/import', headers=admin_headers,
                         files={'file': ('foods.csv', data.encode(), 'text/csv')})
    assert result.status_code == 422
    assert client.get(f'/api/foods/{food_id}').json()['calories_kcal'] == before


def test_historical_target_stays_fixed(client, headers):
    past = str(today() - timedelta(days=1))
    first = client.get('/api/nutrition/target', params={'record_date': past}, headers=headers).json()
    profile = client.get('/api/profile/me', headers=headers).json()
    body = {k: profile[k] for k in ['sex','age','height_cm','weight_kg','goal','activity_level','body_fat_percent']}
    body['goal'] = 'gain_muscle'
    assert client.put('/api/profile/me', headers=headers, json=body).status_code == 200
    second = client.get('/api/nutrition/target', params={'record_date': past}, headers=headers).json()
    assert first == second


def test_recipe_deactivation_after_food_deactivation(client, admin_headers):
    recipe = client.get('/api/recipes', params={'limit': 1}).json()[0]
    food_id = recipe['ingredients'][0]['food_id']
    assert client.delete(f'/api/foods/{food_id}', headers=admin_headers).status_code == 204
    assert client.get(f"/api/recipes/{recipe['id']}").status_code == 404
