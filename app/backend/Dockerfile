# ═══════════════════════════════════════════════════════════════════════════════
# MODENA BACKEND - DOCKERFILE
# ═══════════════════════════════════════════════════════════════════════════════
#
# WHY MULTI-STAGE BUILD?
# ──────────────────────
# Stage 1 (builder): Install dependencies, can have extra tools
# Stage 2 (runtime): Only copy what's needed, smaller image
#
# Benefits:
# - Smaller image size (security + faster pulls)
# - Build tools not in final image (security)
# - Faster CI/CD (layer caching)
#
# INTERVIEW TIP:
# ──────────────
# "I use multi-stage builds to separate build-time dependencies from runtime.
#  The final image only contains what's needed to run the app.
#  This reduces attack surface and image size."
#
# IMAGE SIZE COMPARISON:
# ──────────────────────
# Single stage with python:3.11      → ~1.2GB
# Multi-stage with python:3.11-slim  → ~200MB
# ═══════════════════════════════════════════════════════════════════════════════

# ─────────────────────────────────────────────────────────────────────────────────
# STAGE 1: BUILDER
# ─────────────────────────────────────────────────────────────────────────────────
FROM python:3.11-slim as builder

# Set working directory
WORKDIR /app

# Install build dependencies
# gcc is needed to compile some Python packages (psycopg2)
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    libpq-dev \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements first (Docker layer caching!)
# If requirements.txt hasn't changed, this layer is cached
COPY requirements.txt .

# Install Python dependencies to a specific location
# --prefix installs to /install, which we'll copy to final image
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt


# ─────────────────────────────────────────────────────────────────────────────────
# STAGE 2: RUNTIME
# ─────────────────────────────────────────────────────────────────────────────────
FROM python:3.11-slim as runtime

# Labels for image metadata
LABEL maintainer="Lee - Modena Project"
LABEL description="Modena Domain Intelligence Backend API"
LABEL version="1.0.0"

# Set working directory
WORKDIR /app

# Install runtime dependencies only
# libpq5 is the PostgreSQL client library (needed by psycopg2)
RUN apt-get update && apt-get install -y --no-install-recommends \
    libpq5 \
    && rm -rf /var/lib/apt/lists/*

# Copy installed packages from builder stage
COPY --from=builder /install /usr/local

# Copy application code
COPY . .

# Create non-root user (security best practice!)
# WHY? If app is compromised, attacker has limited permissions
RUN useradd --create-home --shell /bin/bash appuser && \
    chown -R appuser:appuser /app

# Switch to non-root user
USER appuser

# Set environment variables
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PORT=8000

# Expose port (documentation - doesn't actually open port)
EXPOSE 8000

# Health check (Docker's built-in health check)
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD python -c "import requests; requests.get('http://localhost:8000/health')" || exit 1

# Command to run the application
# uvicorn is the ASGI server that runs FastAPI
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]