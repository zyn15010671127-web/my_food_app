from pathlib import Path

import pytest
from fastapi.testclient import TestClient

from app.config import Settings
from app.main import create_app


@pytest.fixture
def client(tmp_path):
    settings = Settings(data_dir=tmp_path / "runtime", jwt_secret="test-only-secret-" * 4,
                        rate_limit_enabled=False)
    with TestClient(create_app(settings)) as instance:
        yield instance


def login(client, username="demo_user", password="DemoPass123!"):
    response = client.post("/api/auth/login", json={"username": username, "password": password})
    assert response.status_code == 200, response.text
    return {"Authorization": "Bearer " + response.json()["access_token"]}


@pytest.fixture
def headers(client):
    return login(client)


@pytest.fixture
def admin_headers(client):
    return login(client, "admin", "AdminDemo123!")


@pytest.fixture
def other_headers(client):
    result = client.post("/api/auth/register", json={"username": "other_user", "password": "OtherPass123!"})
    assert result.status_code == 201
    return login(client, "other_user", "OtherPass123!")


@pytest.fixture
def food_id(client):
    return client.get("/api/foods", params={"q": "测试食物"}).json()[0]["id"]
