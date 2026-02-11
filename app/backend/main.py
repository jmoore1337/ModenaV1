# ═══════════════════════════════════════════════════════════════════════════════
# MODENA BACKEND - MAIN ENTRY POINT
# ═══════════════════════════════════════════════════════════════════════════════
#
# WHY THIS FILE?
# ──────────────
# This is where FastAPI starts. It:
# 1. Creates the FastAPI application
# 2. Registers all routers (domains, scans)
# 3. Sets up database tables
# 4. Defines health check endpoint
#
# HOW TO RUN:
# ───────────
# Local:   uvicorn main:app --reload --host 0.0.0.0 --port 8000
# Docker:  docker run -p 8000:8000 modena-backend
# K8s:     Deployed via kubectl apply -k k8s/overlays/dev/
#
# ENDPOINTS:
# ──────────
# GET  /              → Welcome message
# GET  /health        → Health check (K8s uses this!)
# GET  /docs          → Swagger UI (auto-generated)
# GET  /api/domains   → List domains
# POST /api/domains   → Add domain
# POST /api/scans     → Run a scan
# GET  /api/scans/{id}→ Get scan results
# ═══════════════════════════════════════════════════════════════════════════════

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
import logging

from app.config import get_settings
from app.database import engine, Base
from app.routers import domains_router, scans_router
from app.schemas import HealthResponse

# ─────────────────────────────────────────────────────────────────────────────────
# LOGGING SETUP
# ─────────────────────────────────────────────────────────────────────────────────
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s"
)
logger = logging.getLogger(__name__)

# ─────────────────────────────────────────────────────────────────────────────────
# LOAD SETTINGS
# ─────────────────────────────────────────────────────────────────────────────────
settings = get_settings()

# ─────────────────────────────────────────────────────────────────────────────────
# CREATE FASTAPI APP
# ─────────────────────────────────────────────────────────────────────────────────
app = FastAPI(
    title=settings.app_name,
    version=settings.app_version,
    description="""
    🔍 **Modena Domain Intelligence API**
    
    Scan domains for:
    - DNS records (A, MX, TXT, NS, CNAME)
    - WHOIS data (registrar, dates, nameservers)
    - Subdomain enumeration
    
    Built as a DevOps learning project demonstrating:
    - FastAPI + PostgreSQL
    - Docker + Kubernetes (EKS)
    - Terraform infrastructure
    - Jenkins CI/CD
    """,
    docs_url="/docs",      # Swagger UI
    redoc_url="/redoc",    # ReDoc UI
)

# ─────────────────────────────────────────────────────────────────────────────────
# CORS MIDDLEWARE
# ─────────────────────────────────────────────────────────────────────────────────
# Allows frontend (React) to call this API from different origin
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # In production, specify exact origins
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ─────────────────────────────────────────────────────────────────────────────────
# CREATE DATABASE TABLES
# ─────────────────────────────────────────────────────────────────────────────────
# This creates tables if they don't exist
# In production, you'd use Alembic migrations instead
@app.on_event("startup")
async def startup_event():
    """
    Run on application startup.
    Creates database tables if they don't exist.
    """
    logger.info(f"Starting {settings.app_name} v{settings.app_version}")
    logger.info(f"Environment: {settings.environment}")
    logger.info(f"Database: {settings.database_host}:{settings.database_port}/{settings.database_name}")
    
    # Create all tables
    Base.metadata.create_all(bind=engine)
    logger.info("Database tables created/verified")


# ─────────────────────────────────────────────────────────────────────────────────
# REGISTER ROUTERS
# ─────────────────────────────────────────────────────────────────────────────────
app.include_router(domains_router)
app.include_router(scans_router)


# ─────────────────────────────────────────────────────────────────────────────────
# ROOT ENDPOINT
# ─────────────────────────────────────────────────────────────────────────────────
@app.get("/")
def root():
    """
    Welcome message.
    """
    return {
        "message": f"Welcome to {settings.app_name}",
        "version": settings.app_version,
        "docs": "/docs",
        "health": "/health",
    }


# ─────────────────────────────────────────────────────────────────────────────────
# HEALTH CHECK ENDPOINT
# ─────────────────────────────────────────────────────────────────────────────────
# CRITICAL FOR KUBERNETES!
# K8s uses this to know if pod is healthy.
# If this returns error, K8s restarts the pod.

@app.get("/health", response_model=HealthResponse)
def health_check():
    """
    Health check endpoint for Kubernetes.
    
    K8s livenessProbe and readinessProbe hit this endpoint.
    If database is unreachable, return unhealthy status.
    
    From your Dsny experience (Datadog monitors):
    This is like the monitors you set up - "Is the service healthy?"
    """
    # Try to connect to database
    db_connected = False
    try:
        from app.database import SessionLocal
        db = SessionLocal()
        db.execute("SELECT 1")
        db.close()
        db_connected = True
    except Exception as e:
        logger.error(f"Database health check failed: {str(e)}")
    
    return HealthResponse(
        status="healthy" if db_connected else "unhealthy",
        version=settings.app_version,
        environment=settings.environment,
        database_connected=db_connected,
    )