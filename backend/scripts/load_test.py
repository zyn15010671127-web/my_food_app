"""隔离数据库、50 个账号的真实 HTTP 并发检查，不调用外部 AI。"""
import json
import sys
import tempfile
import threading
import time
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))

import httpx
import uvicorn
from sqlmodel import Session, select

from app.config import Settings
from app.db import create_tables
from app.main import create_app
from app.models import ActivityLevel, Food, Goal, MealRecord, NutritionTarget, Sex, User, UserProfile
from app.security import create_token, hash_password
from app.seed import seed_demo
from app.services.nutrition import calculate_target, today


def main():
    import socket
    directory = ROOT / '.build-load'
    directory.mkdir(exist_ok=True)
    with tempfile.TemporaryDirectory(dir=directory) as temp:
        settings = Settings(data_dir=Path(temp), jwt_secret='load-test-secret-' * 4,
                            rate_limit_enabled=False, seed_demo=False).prepare()
        app = create_app(settings)
        create_tables(app.state.engine)
        tokens = []
        with Session(app.state.engine) as session:
            seed_demo(session)
            food = session.exec(select(Food).where(Food.name == '测试食物')).one()
            shared_hash = hash_password('LoadTest123!')
            for number in range(50):
                user = User(username=f'load_user_{number}', password_hash=shared_hash)
                session.add(user); session.flush()
                profile = UserProfile(user_id=user.id, sex=Sex.male, age=21, height_cm=175,
                    weight_kg=70, goal=Goal.maintain, activity_level=ActivityLevel.moderate)
                session.add(profile)
                session.add(NutritionTarget(user_id=user.id, record_date=today(),
                    **calculate_target(profile), profile_snapshot=profile.model_dump(mode='json')))
                for _ in range(10):
                    session.add(MealRecord(user_id=user.id, food_id=food.id, grams=100, meal_type='lunch',
                        record_date=today(), food_name=food.name, calories_kcal=100, protein_g=5, carbs_g=15, fat_g=2))
                tokens.append(create_token(user, settings))
            session.commit()
        sock = socket.socket()
        sock.bind(('127.0.0.1', 0)); sock.listen(128)
        port = sock.getsockname()[1]
        server = uvicorn.Server(uvicorn.Config(app, log_level='error', access_log=False, lifespan='on'))
        thread = threading.Thread(target=lambda: server.run(sockets=[sock]), daemon=True)
        thread.start()
        deadline = time.monotonic() + 20
        while not server.started and time.monotonic() < deadline:
            time.sleep(0.05)
        if not server.started:
            raise RuntimeError('Test server did not start')
        results = []
        try:
            with httpx.Client(base_url=f'http://127.0.0.1:{port}', timeout=30,
                              limits=httpx.Limits(max_connections=100, max_keepalive_connections=100), trust_env=False) as client:
                for endpoint in ['/api/meal-records/me', '/api/nutrition/daily', '/api/nutrition/progress', '/api/recommendations']:
                    barrier = threading.Barrier(50)
                    def invoke(token):
                        barrier.wait()
                        start = time.perf_counter()
                        response = client.get(endpoint, params={'record_date': str(today())}, headers={'Authorization':'Bearer ' + token})
                        return response.status_code, (time.perf_counter() - start) * 1000
                    with ThreadPoolExecutor(max_workers=50) as pool:
                        values = list(pool.map(invoke, tokens))
                    timings = sorted(value[1] for value in values)
                    item = {'endpoint': endpoint, 'concurrent_users': 50, 'requests': 50,
                        'successes': sum(code == 200 for code, _ in values),
                        'p50_ms': round(timings[24], 2), 'p95_ms': round(timings[47], 2), 'max_ms': round(timings[-1], 2)}
                    results.append(item)
                    print(json.dumps(item), flush=True)
        finally:
            server.should_exit = True
            thread.join(timeout=15)
            sock.close()
            app.state.engine.dispose()
        output = {'environment': 'Windows / Python ' + sys.version.split()[0],
            'method': '50 accounts, 50 simultaneous real HTTP requests per endpoint, SQLite, one process; rate limiter disabled for measurement; AI not exercised',
            'results': results}
        (ROOT / 'docs' / 'load-test-results.json').write_text(json.dumps(output, ensure_ascii=False, indent=2), encoding='utf-8')
        if any(row['successes'] != 50 for row in results):
            raise SystemExit('Load test had failed requests')


if __name__ == '__main__':
    main()
