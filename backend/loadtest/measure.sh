#!/bin/bash
# loadtest/measure.sh — full V.7 measurement ceremony.
#
# What it does:
#   1. Stops any backend currently running.
#   2. Boots a fresh backend with the throttler relaxed
#      (THROTTLE_LIMIT + AUTH_THROTTLE_LIMIT set very high) — load-test mode
#      ONLY, no edit to .env, no persistence.
#   3. Waits for /health to be reachable.
#   4. Runs all 5 k6 scripts via loadtest/run.sh.
#   5. On exit (success, failure, Ctrl+C) → kills the load-test backend.
#
# After this script ends, the relaxed backend is GONE. To use the app
# normally again, restart it with `node dist/main.js` or `make dev` —
# it will read .env and the throttler will be back to production limits.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKEND_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BASE_URL="${BASE_URL:-http://localhost:3000}"
BACKEND_PID=""

cleanup() {
  if [ -n "$BACKEND_PID" ] && kill -0 "$BACKEND_PID" 2>/dev/null; then
    echo
    echo "==> Stopping load-test backend (PID $BACKEND_PID)..."
    kill "$BACKEND_PID" 2>/dev/null
    wait "$BACKEND_PID" 2>/dev/null
  fi
  echo "    Throttler will be back to .env values on next backend restart."
}
trap cleanup EXIT INT TERM

echo "==> Stopping any existing backend..."
pkill -f "node.*dist/main" 2>/dev/null
sleep 1

echo "==> Starting backend with throttler RELAXED (load-test mode only)..."
cd "$BACKEND_DIR" || exit 1
THROTTLE_LIMIT=1000000 AUTH_THROTTLE_LIMIT=1000000 \
  AUTH_ALLOW_UNVERIFIED=true \
  BCRYPT_ROUNDS_OVERRIDE=4 \
  node dist/main.js > /tmp/loadtest-backend.log 2>&1 &
BACKEND_PID=$!
echo "    Backend PID = $BACKEND_PID"

echo "==> Waiting for backend health..."
ok=""
for _ in $(seq 1 30); do
  if curl -fsS "$BASE_URL/health" >/dev/null 2>&1; then
    ok=1
    break
  fi
  sleep 1
done

if [ -z "$ok" ]; then
  echo "ERROR: backend did not come up within 30s. Log tail:"
  tail -30 /tmp/loadtest-backend.log
  exit 1
fi
echo "    Backend is up"
echo

echo "==> Running load tests..."
bash "$SCRIPT_DIR/run.sh"
EXIT_CODE=$?

# trap fires here → cleanup → kill backend
exit "$EXIT_CODE"
