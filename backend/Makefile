.PHONY: install dev build test test-e2e test-cov \
	db-migrate db-generate db-seed \
	docker-up docker-down docker-build docker-rebuild docker-logs docker-sh up down logs \
	clean

# docker-compose.yml lives at the repo root (one level up)
COMPOSE = docker compose -f ../docker-compose.yml

# ─── Dev (host machine) ───────────────────────────────────────────────────────
install:
	npm install

dev: docker-up
	npm run start:dev

build:
	npm run build

test:
	npm run test

test-e2e:
	npm run test:e2e

test-cov:
	npm run test:cov

# ─── Prisma ───────────────────────────────────────────────────────────────────
db-migrate:
	npx prisma migrate dev

db-generate:
	npx prisma generate

db-seed:
	npx prisma db seed

# ─── Docker — infra services only (postgres + redis + mailpit) ────────────────
docker-up:
	$(COMPOSE) up -d postgres redis mailpit

docker-down:
	$(COMPOSE) down

# ─── Docker — full stack (infra + backend container) ──────────────────────────
up:
	$(COMPOSE) up -d --build

down:
	$(COMPOSE) down

docker-build:
	$(COMPOSE) build backend

docker-rebuild:
	$(COMPOSE) build --no-cache backend

logs:
	$(COMPOSE) logs -f backend

docker-logs:
	$(COMPOSE) logs -f

docker-sh:
	$(COMPOSE) exec backend sh

# ─── Cleanup ──────────────────────────────────────────────────────────────────
clean:
	rm -rf node_modules dist coverage
