#!/usr/bin/env bash
set -euo pipefail

echo "========================================"
echo "Starting FixNex"
echo "========================================"

# ==================================================
# OWASP ZAP - OPTIONAL
# ==================================================

echo "Starting OWASP ZAP..."

mkdir -p /home/fixnex/.ZAP

if [ -n "${ZAP_API_KEY:-}" ]; then
  echo "Starting ZAP with API key protection..."

  /opt/zap/zap.sh \
    -daemon \
    -host 127.0.0.1 \
    -port 8080 \
    -config "api.key=${ZAP_API_KEY}" \
    -config "api.addrs.addr.name=127.0.0.1" \
    -config "api.addrs.addr.regex=true" \
    > /tmp/zap.log 2>&1 &
else
  echo "Starting ZAP without API key protection..."

  /opt/zap/zap.sh \
    -daemon \
    -host 127.0.0.1 \
    -port 8080 \
    -config "api.disablekey=true" \
    -config "api.addrs.addr.name=127.0.0.1" \
    -config "api.addrs.addr.regex=true" \
    > /tmp/zap.log 2>&1 &
fi

ZAP_PID=$!

echo "ZAP process started with PID ${ZAP_PID}"

# ==================================================
# Wait for ZAP - NON-FATAL
# ==================================================

echo "Waiting for OWASP ZAP..."

ZAP_READY=false

for i in $(seq 1 90); do

  if [ -n "${ZAP_API_KEY:-}" ]; then
    if curl -fsS \
      --get \
      --data-urlencode "apikey=${ZAP_API_KEY}" \
      "http://127.0.0.1:8080/JSON/core/view/version/" \
      >/dev/null 2>&1; then

      ZAP_READY=true
      break
    fi
  else
    if curl -fsS \
      "http://127.0.0.1:8080/JSON/core/view/version/" \
      >/dev/null 2>&1; then

      ZAP_READY=true
      break
    fi
  fi

  # ZAP died -> don't kill FixNex
  if ! kill -0 "$ZAP_PID" 2>/dev/null; then
    echo "WARNING: OWASP ZAP process exited."
    break
  fi

  sleep 2
done

if [ "$ZAP_READY" = "true" ]; then
  echo "OWASP ZAP is ready."

  if [ -n "${ZAP_API_KEY:-}" ]; then
    curl -fsS \
      --get \
      --data-urlencode "apikey=${ZAP_API_KEY}" \
      "http://127.0.0.1:8080/JSON/core/view/version/" \
      || echo "WARNING: Could not verify ZAP API."
  else
    curl -fsS \
      "http://127.0.0.1:8080/JSON/core/view/version/" \
      || echo "WARNING: Could not verify ZAP API."
  fi

  echo
else
  echo "WARNING: OWASP ZAP is unavailable."
  echo "ZAP-based scanning will be unavailable."
  echo "The remaining FixNex services will continue."
  echo "----- ZAP LOG -----"
  cat /tmp/zap.log || true
  echo "-------------------"
fi

# ==================================================
# PostgreSQL
# ==================================================

echo "Waiting for PostgreSQL..."

until python -c "
import sys
import psycopg2
from app.core.config import settings

url = settings.DATABASE_URL.replace(
    'postgresql+psycopg2',
    'postgresql'
)

try:
    psycopg2.connect(url).close()
except Exception as exc:
    print(exc)
    sys.exit(1)
" 2>/dev/null; do
  sleep 2
done

echo "PostgreSQL is ready."

# ==================================================
# Database migrations
# ==================================================

echo "Applying database migrations..."

alembic upgrade head

echo "Database migrations completed."

# ==================================================
# Optional demo seed
# ==================================================

if [ "${SEED_DEMO_ON_START:-false}" = "true" ]; then
  echo "Seeding the demonstration dataset..."
  python -m app.cli seed-demo || echo "Seeding skipped."
fi

# ==================================================
# Cleanup
# ==================================================

cleanup() {
  echo "Stopping OWASP ZAP..."

  if [ -n "${ZAP_PID:-}" ] && kill -0 "$ZAP_PID" 2>/dev/null; then
    kill "$ZAP_PID" 2>/dev/null || true
  fi
}

trap cleanup EXIT INT TERM

# ==================================================
# Start FixNex API
# ==================================================

echo "Starting FixNex API..."

exec "$@"