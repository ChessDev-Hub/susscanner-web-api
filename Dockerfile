# Dockerfile
FROM python:3.11-slim

# Good runtime defaults
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONPATH=/app

WORKDIR /app

# Improve build caching: install deps before copying the whole repo
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Now copy the application code
COPY . .

# Improve build caching: install deps before copying the whole repo
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Now copy the application code
COPY . .

# IMPORTANT: use $PORT provided by Render (no hard-coded 8080)
CMD ["sh","-c","uvicorn api.main:app --host 0.0.0.0 --port ${PORT:-8000}"]
