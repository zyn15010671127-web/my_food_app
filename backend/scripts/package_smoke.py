"""解压到隔离目录，使用离线依赖环境检查初始化、实际HTTP启动与数据持久化。"""
import hashlib
import json
import os
import shutil
import subprocess
import sys
import time
from pathlib import Path
from zipfile import ZipFile

import httpx

ROOT = Path(__file__).resolve().parent.parent
ARCHIVE = ROOT.parent / '智能饮食搭配推荐系统_后端提交包.zip'
CHECK = ROOT.parent / '.build-package-check'
CHECK.mkdir(exist_ok=True)
with ZipFile(ARCHIVE) as archive:
    for name in archive.namelist():
        target = (CHECK / name).resolve()
        if not target.is_relative_to(CHECK.resolve()):
            raise RuntimeError('Unsafe archive member')
    archive.extractall(CHECK)
PROJECT = CHECK / 'diet-backend'
PYTHON = ROOT.parent / '.build-offline-check' / '.venv' / 'Scripts' / 'python.exe'
if not PYTHON.is_file():
    raise SystemExit('Prepare the clean offline-check environment before running this builder check.')
env = dict(os.environ)
for key in ['DATABASE_URL','JWT_SECRET_KEY','APP_ENV','SEED_DEMO_DATA','AUTO_CREATE_TABLES','DB_HOST']:
    env.pop(key, None)
env['PYTHONUTF8'] = '1'
env['PYTHONIOENCODING'] = 'utf-8'
env['RATE_LIMIT_ENABLED'] = 'false'
env['DATA_DIR'] = str(PROJECT / 'data' / 'runtime')
subprocess.run([str(PYTHON),'scripts/init_db.py'],cwd=PROJECT,env=env,check=True)
manifest = (PROJECT / 'MANIFEST.sha256').read_text(encoding='utf-8').splitlines()
for line in manifest:
    digest, filename = line.split('  ',1)
    assert hashlib.sha256((PROJECT / filename).read_bytes()).hexdigest() == digest, filename


def start(port):
    log = (CHECK / f'server-{port}.log').open('w',encoding='utf-8')
    process = subprocess.Popen([str(PYTHON),'-m','uvicorn','main:app','--host','127.0.0.1','--port',str(port)],
        cwd=PROJECT,env=env,stdout=log,stderr=subprocess.STDOUT,
        creationflags=subprocess.CREATE_NO_WINDOW if os.name=='nt' else 0)
    for _ in range(100):
        if process.poll() is not None:
            log.close()
            raise RuntimeError((CHECK / f'server-{port}.log').read_text(encoding='utf-8'))
        try:
            if httpx.get(f'http://127.0.0.1:{port}/api/health',timeout=0.5,trust_env=False).status_code==200:
                return process,log
        except httpx.HTTPError:
            pass
        time.sleep(0.1)
    process.terminate(); process.wait(timeout=10); log.close()
    raise RuntimeError('Packaged application did not start')


port=18071
process,log=start(port)
try:
    with httpx.Client(base_url=f'http://127.0.0.1:{port}',timeout=10,trust_env=False) as client:
        response=client.post('/api/auth/login',json={'username':'demo_user','password':'DemoPass123!'})
        assert response.status_code==200
        token=response.json()['access_token']
        headers={'Authorization':'Bearer '+token}
        food=client.get('/api/foods',params={'q':'测试食物'}).json()[0]
        created=client.post('/api/meal-records',headers=headers,json={'food_id':food['id'],'grams':150,'meal_type':'lunch','record_date':'2026-10-23'})
        assert created.status_code==201 and created.json()['calories_kcal']==150
        record_id=created.json()['id']
        assert client.get('/docs').status_code==200
        assert client.get('/docs-assets/swagger-ui-bundle.js').status_code==200
        assert len(client.get('/api/recommendations',headers=headers).json()['recommendations'])==3
        assert client.post('/api/chat/messages',headers=headers,json={'message':'蛋白质'}).json()['mode']=='local_knowledge'
finally:
    process.terminate(); process.wait(timeout=15); log.close()
process,log=start(port)
try:
    response=httpx.get(f'http://127.0.0.1:{port}/api/meal-records/me',headers=headers,params={'record_date':'2026-10-23'},trust_env=False)
    assert response.status_code==200 and any(row['id']==record_id for row in response.json())
finally:
    process.terminate(); process.wait(timeout=15); log.close()
result={'archive_crc':'passed','manifest_sha256':'passed','clean_offline_environment':'passed',
    'alembic_initialization':'passed','real_http_startup':'passed','demo_login':'passed',
    'local_swagger_assets':'passed','meal_record':'passed','three_recommendations':'passed',
    'local_chat':'passed','restart_preserves_data_and_jwt':'passed'}
(ROOT / 'docs' / 'package-smoke-results.json').write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps(result),flush=True)
