#!/bin/bash
# Run the k6 load tests and write each rapport to loadtest/results/.
#
# Usage:
#   bash loadtest/run.sh         # run all scripts (01..05)
#   bash loadtest/run.sh 02      # run only scripts whose filename starts with "02"
#
# Env vars:
#   BASE_URL   defaults to http://localhost:3000
#
# Requires: k6 installed (brew install k6) and the backend reachable on
# BASE_URL. Each script overwrites its own results file on re-run, so the
# folder always reflects the latest baseline.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESULTS_DIR="$SCRIPT_DIR/results"
BASE_URL="${BASE_URL:-http://localhost:3000}"

if ! command -v k6 >/dev/null 2>&1; then
  echo "ERROR: k6 is not installed. Install it with: brew install k6"
  exit 1
fi

if ! curl -fsS "$BASE_URL/health" >/dev/null 2>&1; then
  echo "ERROR: backend not reachable at $BASE_URL"
  echo "       Start it first (e.g. node dist/main.js or make dev)."
  exit 1
fi

mkdir -p "$RESULTS_DIR"

PATTERN="${1:-0}"
total=0
failed=0

for script in "$SCRIPT_DIR"/${PATTERN}*.js; do
  [ -f "$script" ] || continue
  total=$((total + 1))
  name="$(basename "${script%.js}")"
  echo
  echo "==> Running $name"
  k6 run "$script" 2>&1 | tee "$RESULTS_DIR/$name.txt"
  if [ "${PIPESTATUS[0]}" -ne 0 ]; then
    echo "[FAIL] $name — thresholds breached (see $RESULTS_DIR/$name.txt)"
    failed=$((failed + 1))
  else
    echo "[PASS] $name (see $RESULTS_DIR/$name.txt)"
  fi
done

echo
if [ "$total" -eq 0 ]; then
  echo "No load-test scripts matched pattern '$PATTERN'."
  exit 1
elif [ "$failed" -eq 0 ]; then
  echo "All $total load test(s) passed."
else
  echo "$failed out of $total load test(s) breached their thresholds."
  exit 1
fi
