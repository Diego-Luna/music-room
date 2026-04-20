.PHONY: install dev build test test-e2e test-cov db-migrate db-generate db-seed docker-up docker-down clean

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

db-migrate:
	npx prisma migrate dev

db-generate:
	npx prisma generate

db-seed:
	npx prisma db seed

docker-up:
	docker compose up -d

docker-down:
	docker compose down

clean:
	rm -rf node_modules dist coverage
