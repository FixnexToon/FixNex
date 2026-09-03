#!/usr/bin/env bash
set -euo pipefail

echo "========================================"
echo "Starting FixNex"
echo "========================================"

# ==================================================
# FAST STARTUP
# ==================================================
#
# IMPORTANT:
# OWASP ZAP is NOT started here.
#
# ZAP is started lazily by the ZAP scanner only when
# a ZAP scan is actually requested.
#
# This prevents Java/ZAP startup from consuming CPU/RAM
# during normal API startup.
# ==================================================

echo "ZAP lazy-start enabled."
echo "ZAP will start only when a ZAP scan is requested."

# ==================================================
# DATABASE
# ==================================================
#
# Do not wait for PostgreSQL here.
# FastAPI handles database connectivity.
#
# Run Alembic migrations separately during deployment.
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
# START FIXNEX API IMMEDIATELY
# ==================================================

echo "========================================"
echo "Starting FixNex API immediately..."
echo "========================================"

exec "$@"