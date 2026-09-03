#!/usr/bin/env bash
set -euo pipefail

echo "========================================"
echo "Starting FixNex"
echo "========================================"

# ==================================================
# OWASP ZAP - START IN BACKGROUND
# ==================================================

ZAP_PID=""

echo "Starting OWASP ZAP in background..."

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

echo "ZAP started in background with PID ${ZAP_PID}"

# ==================================================
# ZAP READINESS CHECK - BACKGROUND
# ==================================================

check_zap() {
    echo "ZAP readiness check running in background..."

    # Give Java/ZAP a little time to initialize.
    sleep 5

    for i in $(seq 1 90); do

        # ZAP process died
        if ! kill -0 "$ZAP_PID" 2>/dev/null; then
            echo "WARNING: OWASP ZAP process exited."
            echo "ZAP-based scanning will be unavailable."
            echo "----- ZAP LOG -----"
            cat /tmp/zap.log || true
            echo "-------------------"
            return 0
        fi

        # API key enabled
        if [ -n "${ZAP_API_KEY:-}" ]; then

            if curl -fsS \
                --get \
                --data-urlencode "apikey=${ZAP_API_KEY}" \
                "http://127.0.0.1:8080/JSON/core/view/version/" \
                >/dev/null 2>&1; then

                echo "OWASP ZAP is ready."

                curl -fsS \
                    --get \
                    --data-urlencode "apikey=${ZAP_API_KEY}" \
                    "http://127.0.0.1:8080/JSON/core/view/version/" \
                    || true

                echo
                return 0
            fi

        # API key disabled
        else

            if curl -fsS \
                "http://127.0.0.1:8080/JSON/core/view/version/" \
                >/dev/null 2>&1; then

                echo "OWASP ZAP is ready."

                curl -fsS \
                    "http://127.0.0.1:8080/JSON/core/view/version/" \
                    || true

                echo
                return 0
            fi

        fi

        sleep 2
    done

    echo "WARNING: OWASP ZAP did not become ready."
    echo "ZAP-based scanning may be unavailable."
    echo "FixNex API will continue running."

    echo "----- ZAP LOG -----"
    cat /tmp/zap.log || true
    echo "-------------------"
}

# IMPORTANT:
# Do not wait for ZAP.
check_zap &

# ==================================================
# DATABASE
# ==================================================
#
# IMPORTANT:
# We intentionally DO NOT wait for PostgreSQL here.
# FastAPI starts immediately.
#
# Database connectivity is handled by the application.
# Migrations should be executed during deployment, not
# every time the Render container starts.
# ==================================================

echo "Skipping startup database wait."

echo "Skipping startup Alembic migration."

# ==================================================
# OPTIONAL DEMO SEED
# ==================================================

if [ "${SEED_DEMO_ON_START:-false}" = "true" ]; then
    echo "Demo seed requested."
    echo "Skipping demo seed during fast startup."
fi

# ==================================================
# CLEANUP
# ==================================================

cleanup() {
    echo "Stopping OWASP ZAP..."

    if [ -n "${ZAP_PID:-}" ] && kill -0 "$ZAP_PID" 2>/dev/null; then
        kill "$ZAP_PID" 2>/dev/null || true
    fi
}

trap cleanup EXIT INT TERM

# ==================================================
# START FIXNEX API IMMEDIATELY
# ==================================================

echo "========================================"
echo "Starting FixNex API immediately..."
echo "========================================"

exec "$@"