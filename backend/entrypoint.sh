#!/usr/bin/env bash
set -euo pipefail

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
  echo "Starting ZAP without API key protection (local testing only)..."

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

echo "Waiting for OWASP ZAP..."

ZAP_READY=false

# ZAP can take several minutes on first startup while loading/updating addons.
# 180 attempts x 2 seconds = 360 seconds maximum wait.
for i in $(seq 1 180); do

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

  # If ZAP process has exited, fail immediately and show its log.
  if ! kill -0 "$ZAP_PID" 2>/dev/null; then
    echo "OWASP ZAP failed to start."
    echo "----- ZAP LOG -----"
    cat /tmp/zap.log || true
    echo "-------------------"
    exit 1
  fi

  sleep 2
done

if [ "$ZAP_READY" != "true" ]; then
  echo "OWASP ZAP did not become ready within 360 seconds."
  echo "----- ZAP LOG -----"
  cat /tmp/zap.log || true
  echo "-------------------"
  exit 1
fi

echo "OWASP ZAP is ready."

# Confirm the ZAP API version once more.
if [ -n "${ZAP_API_KEY:-}" ]; then
  curl -fsS \
    --get \
    --data-urlencode "apikey=${ZAP_API_KEY}" \
    "http://127.0.0.1:8080/JSON/core/view/version/"
else
  curl -fsS \
    "http://127.0.0.1:8080/JSON/core/view/version/"
fi

echo

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

echo "Applying database migrations..."
alembic upgrade head

if [ "${SEED_DEMO_ON_START:-false}" = "true" ]; then
  echo "Seeding the demonstration dataset..."
  python -m app.cli seed-demo || echo "Seeding skipped."
fi

cleanup() {
  echo "Stopping OWASP ZAP..."
  kill "$ZAP_PID" 2>/dev/null || true
}

trap cleanup EXIT INT TERM

echo "Starting FixNex API..."

exec "$@"