# ============================================================================
# FixNex Backend
#
# Production Docker image for:
#   - FastAPI
#   - Nmap
#   - Nuclei
#   - WhatWeb
#   - PostgreSQL
#   - WeasyPrint
#
# Celery is supported by the application but is NOT required when:
#
#   TASK_RUNNER=thread
#
# This allows FixNex to run on a Render Web Service without a separate
# paid Celery Background Worker.
# ============================================================================

FROM python:3.11-slim


# ----------------------------------------------------------------------------
# Python environment
# ----------------------------------------------------------------------------

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PYTHONPATH=/app


# ----------------------------------------------------------------------------
# Application directory
# ----------------------------------------------------------------------------

WORKDIR /app


# ----------------------------------------------------------------------------
# System dependencies
#
# WeasyPrint:
#   - Pango
#   - Cairo
#   - GDK Pixbuf
#   - libffi
#   - shared-mime-info
#   - fonts
#
# Security scanners:
#   - Nmap
#   - WhatWeb
#
# Other:
#   - curl
#   - ca-certificates
#   - unzip
#   - gcc
#   - PostgreSQL development libraries
# ----------------------------------------------------------------------------

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        libpango-1.0-0 \
        libpangoft2-1.0-0 \
        libcairo2 \
        libgdk-pixbuf-2.0-0 \
        libffi-dev \
        shared-mime-info \
        fonts-dejavu-core \
        nmap \
        whatweb \
        curl \
        ca-certificates \
        unzip \
        gcc \
        libpq-dev \
    && rm -rf /var/lib/apt/lists/*


# ----------------------------------------------------------------------------
# Install Nuclei
#
# ProjectDiscovery official release.
# ----------------------------------------------------------------------------

ARG NUCLEI_VERSION=3.3.7
ARG TARGETARCH=amd64

RUN set -eux; \
    curl -fsSL \
        -o /tmp/nuclei.zip \
        "https://github.com/projectdiscovery/nuclei/releases/download/v${NUCLEI_VERSION}/nuclei_${NUCLEI_VERSION}_linux_${TARGETARCH}.zip"; \
    unzip -o /tmp/nuclei.zip nuclei -d /usr/local/bin; \
    chmod +x /usr/local/bin/nuclei; \
    rm -f /tmp/nuclei.zip; \
    nuclei -version


# ----------------------------------------------------------------------------
# Verify scanner binaries
#
# If any of these fail, the Docker build stops.
# This prevents deploying a container where scanners are silently missing.
# ----------------------------------------------------------------------------

RUN nmap --version \
    && whatweb --version \
    && nuclei -version


# ----------------------------------------------------------------------------
# Python dependencies
# ----------------------------------------------------------------------------

COPY requirements.txt /app/requirements.txt

RUN python -m pip install --upgrade pip \
    && python -m pip install -r /app/requirements.txt


# ----------------------------------------------------------------------------
# Copy application
# ----------------------------------------------------------------------------

COPY . /app


# ----------------------------------------------------------------------------
# Create non-root FixNex user
# ----------------------------------------------------------------------------

RUN useradd \
        --create-home \
        --shell /bin/bash \
        --uid 10001 \
        fixnex \
    && mkdir -p /app/storage \
    && mkdir -p /home/fixnex/.config \
    && mkdir -p /home/fixnex/.cache \
    && chown -R fixnex:fixnex /app \
    && chown -R fixnex:fixnex /home/fixnex


# ----------------------------------------------------------------------------
# Runtime environment
# ----------------------------------------------------------------------------

ENV HOME=/home/fixnex \
    PATH=/usr/local/bin:/usr/bin:/bin


# ----------------------------------------------------------------------------
# Run application as non-root user
# ----------------------------------------------------------------------------

USER fixnex


# ----------------------------------------------------------------------------
# FastAPI port
# ----------------------------------------------------------------------------

EXPOSE 8000


# ----------------------------------------------------------------------------
# Default command
# ----------------------------------------------------------------------------

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]