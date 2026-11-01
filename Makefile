.PHONY: install lint format test run up down logs seed worker

PY ?= python

install:
	$(PY) -m pip install -e ".[dev]"

lint:
	ruff check .
	ruff format --check .

format:
	ruff check . --fix
	ruff format .

test:
	pytest -q

run:
	uvicorn app.main:create_app --factory --reload --port 8000

worker:
	$(PY) -m app.worker

up:
	docker compose up --build -d

down:
	docker compose down

logs:
	docker compose logs -f api

# Creates a demo tenant, uploads sample policies and seeds orders/catalogue (needs a running API)
seed:
	$(PY) scripts/seed_demo.py --vertical ecommerce
