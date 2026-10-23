"""只打包可提交文件，不带真实密钥、运行数据、虚拟环境或测试临时目录。"""
import hashlib
import json
from pathlib import Path
from zipfile import ZIP_DEFLATED, ZipFile

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT.parent / '智能饮食搭配推荐系统_后端提交包.zip'
DENY = {'.venv', '.env', '__pycache__', '.pytest_cache', '.git', '.setup-tmp'}


def included(path):
    relative = path.relative_to(ROOT)
    if any(part in DENY or part.startswith('.build') for part in relative.parts):
        return False
    if relative.parts[:2] == ('data', 'runtime'):
        return False
    if path.suffix in {'.pyc', '.db', '.sqlite', '.sqlite3'} or '.db-' in path.name:
        return False
    return path.is_file()


def package():
    files = sorted(path for path in ROOT.rglob('*') if included(path) and path.name != 'MANIFEST.sha256')
    manifest = '\n'.join(hashlib.sha256(path.read_bytes()).hexdigest() + '  ' + path.relative_to(ROOT).as_posix() for path in files) + '\n'
    (ROOT / 'MANIFEST.sha256').write_text(manifest, encoding='utf-8')
    files.append(ROOT / 'MANIFEST.sha256')
    with ZipFile(OUT, 'w', ZIP_DEFLATED, compresslevel=6) as archive:
        for path in files:
            archive.write(path, 'diet-backend/' + path.relative_to(ROOT).as_posix())
    with ZipFile(OUT) as archive:
        assert archive.testzip() is None
        assert all('/.env' not in name or name.endswith('/.env.example') for name in archive.namelist())
    digest = hashlib.sha256(OUT.read_bytes()).hexdigest()
    OUT.with_suffix('.zip.sha256').write_text(digest + '  ' + OUT.name + '\n', encoding='utf-8')
    print(json.dumps({'archive':str(OUT),'files':len(files),'size_mb':round(OUT.stat().st_size / 1024**2,2),'sha256':digest}, ensure_ascii=False))


if __name__ == '__main__':
    package()
