#!/bin/sh
set -e

echo "[entrypoint] Applying Prisma migrations..."
npx --yes prisma migrate deploy

echo "[entrypoint] Starting Nest server..."
exec node dist/main.js
