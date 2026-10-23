FROM python:3.14-slim
WORKDIR /app
ENV PYTHONUNBUFFERED=1 PYTHONDONTWRITEBYTECODE=1
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
RUN useradd --create-home diet && mkdir -p /app/data/runtime && chown -R diet:diet /app
USER diet
EXPOSE 8000
CMD ["sh", "-c", "python scripts/init_db.py && uvicorn main:app --host 0.0.0.0 --port 8000"]
