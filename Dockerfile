FROM python:3.12-slim
WORKDIR /app
RUN apt-get update && apt-get install -y curl libmagic1 libpango-1.0-0 libharfbuzz0b libpangoft2-1.0-0 && rm -rf /var/lib/apt/lists/*
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
RUN mkdir -p /app/data /app/static/uploads
ENV DATABASE_URL=sqlite+aiosqlite:////app/data/crm_yurist.db
EXPOSE 10000
CMD ["sh", "-c", "uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-10000}"]
