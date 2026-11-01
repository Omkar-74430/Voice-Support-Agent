# syntax=docker/dockerfile:1.7

# ---------- build stage: resolve and install dependencies into an isolated venv ----------
FROM python:3.12-slim AS builder
ENV PIP_NO_CACHE_DIR=1 PIP_DISABLE_PIP_VERSION_CHECK=1
WORKDIR /build
COPY pyproject.toml README.md ./
COPY app ./app
RUN python -m venv /opt/venv \
 && /opt/venv/bin/pip install --upgrade pip \
 && /opt/venv/bin/pip install .

# ---------- runtime stage: small, non-root, no build tooling ----------
FROM python:3.12-slim AS runtime
ENV PATH="/opt/venv/bin:$PATH" \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONFAULTHANDLER=1
RUN groupadd --system --gid 10001 app \
 && useradd --system --uid 10001 --gid app --home-dir /app --shell /usr/sbin/nologin app
COPY --from=builder /opt/venv /opt/venv
WORKDIR /app
USER app
EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
  CMD python -c "import sys,urllib.request as u; sys.exit(0 if u.urlopen('http://127.0.0.1:8000/healthz', timeout=3).status == 200 else 1)"

# One worker per container: scale horizontally (replicas). WebSocket sessions are sticky to a container;
# Prometheus metrics stay per-process. Set FORWARDED_ALLOW_IPS to your load balancer's address range.
CMD ["uvicorn", "app.main:create_app", "--factory", \
     "--host", "0.0.0.0", "--port", "8000", \
     "--no-access-log", "--proxy-headers", \
     "--timeout-graceful-shutdown", "25", \
     "--ws-ping-interval", "20", "--ws-ping-timeout", "20", "--ws-max-size", "1048576"]
