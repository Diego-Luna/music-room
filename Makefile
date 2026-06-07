# Music Room — root orchestration.
# IV.1: a fresh clone + `make install` downloads every dependency (backend +
# mobile). Other targets delegate to backend/Makefile and the Flutter toolchain.

.PHONY: help install install-backend install-frontend \
	build build-backend build-frontend \
	test test-backend test-frontend \
	dev up down logs loadtest measure clean

BACKEND  = backend
FRONTEND = frontend/music_room_app

.DEFAULT_GOAL := help

help:
	@echo "Music Room — available targets:"
	@echo "  make install        Install backend (npm) + mobile (flutter) deps"
	@echo "  make build          Build backend + mobile"
	@echo "  make test           Run backend + mobile test suites"
	@echo "  make dev            Boot infra + backend in watch mode"
	@echo "  make up / down      Start / stop the full docker stack"
	@echo "  make loadtest       Run the k6 load tests (V.7)"
	@echo "  make clean          Remove build artifacts and dependencies"

# ─── Install (the IV.1 entry point) ───────────────────────────────────────────
install: install-backend install-frontend

install-backend:
	$(MAKE) -C $(BACKEND) install

install-frontend:
	cd $(FRONTEND) && flutter pub get

# ─── Build ────────────────────────────────────────────────────────────────────
build: build-backend build-frontend

build-backend:
	$(MAKE) -C $(BACKEND) build

build-frontend:
	cd $(FRONTEND) && flutter build apk --debug

# ─── Tests ────────────────────────────────────────────────────────────────────
test: test-backend test-frontend

test-backend:
	$(MAKE) -C $(BACKEND) test

test-frontend:
	cd $(FRONTEND) && flutter test

# ─── Run / infra (delegated to backend/Makefile + root docker-compose) ────────
dev:
	$(MAKE) -C $(BACKEND) dev

up:
	$(MAKE) -C $(BACKEND) up

down:
	$(MAKE) -C $(BACKEND) down

logs:
	$(MAKE) -C $(BACKEND) logs

# ─── Load tests (V.7) ─────────────────────────────────────────────────────────
loadtest:
	$(MAKE) -C $(BACKEND) loadtest

measure:
	$(MAKE) -C $(BACKEND) measure

# ─── Cleanup ──────────────────────────────────────────────────────────────────
clean:
	$(MAKE) -C $(BACKEND) clean
	cd $(FRONTEND) && flutter clean
