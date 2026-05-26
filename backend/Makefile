.PHONY: install dev build test test-e2e test-cov \
	db-migrate db-generate db-seed \
	docker-up docker-down docker-build docker-rebuild docker-logs docker-sh up down logs \
	loadtest measure \
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

# ─── Load tests (V.7) ─────────────────────────────────────────────────────────
# Run all k6 scripts against a backend that's ALREADY running.
loadtest:
	bash loadtest/run.sh

# Full V.7 measurement ceremony: stops any backend, boots one with the
# throttler relaxed (load-test only — no edit to .env), runs the 5 k6
# scripts, then kills the relaxed backend (trap on exit). After this,
# restart the backend normally (`make dev` / `node dist/main.js`) and
# throttler comes back to production limits.
measure:
	bash loadtest/measure.sh

# ─── Cleanup ──────────────────────────────────────────────────────────────────
clean:
	rm -rf node_modules dist coverage
