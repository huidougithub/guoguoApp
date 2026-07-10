# Guoguo Backend

FastAPI backend for cloud data and AI features.

## Local setup

```powershell
cd backend
python -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r requirements.txt
copy .env.example .env
.\.venv\Scripts\python.exe -m app.scripts.init_db
.\.venv\Scripts\python.exe -m uvicorn app.main:app --reload --host 127.0.0.1 --port 8000
```

## Server environment

Required:

```text
DATABASE_URL=postgresql://guoguo_app:***@127.0.0.1:5432/guoguo_app
DEEPSEEK_API_KEY=***
```

Optional:

```text
DEEPSEEK_BASE_URL=https://api.deepseek.com
DEEPSEEK_MODEL=deepseek-v4-pro
```

Do not commit `.env`.
