#!/usr/bin/env sh
set -eu
cd "$(dirname "$0")"
python3 -m venv .venv
.venv/bin/python -m pip install -r requirements-lock.txt
if [ ! -f .env ]; then cp .env.example .env; fi
.venv/bin/python scripts/init_db.py
exec .venv/bin/python -m uvicorn main:app --host 127.0.0.1 --port "${PORT:-8010}"
