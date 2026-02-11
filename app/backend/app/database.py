# ═══════════════════════════════════════════════════════════════════════════════
# MODENA BACKEND - DATABASE CONNECTION
# ═══════════════════════════════════════════════════════════════════════════════
#
# WHY THIS FILE?
# ──────────────
# Creates the connection to YOUR RDS PostgreSQL database.
# SQLAlchemy handles connection pooling, retries, etc.
#
# HOW IT WORKS:
# ─────────────
# 1. Reads DATABASE_URL from config.py (which reads environment variables)
# 2. Creates a SQLAlchemy "engine" (the connection pool)
# 3. Creates a "SessionLocal" factory (makes database sessions)
# 4. FastAPI endpoints use sessions to query/insert data
#
# CONNECTION FLOW:
# ────────────────
# FastAPI Request → get_db() → SessionLocal() → Engine → RDS PostgreSQL
#                                                         ↓
#                                         modena-dev-db.xxx.rds.amazonaws.com
# ═══════════════════════════════════════════════════════════════════════════════

from sqlalchemy import create_engine
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker

from app.config import get_settings

settings = get_settings()

# ─────────────────────────────────────────────────────────────────────────────────
# DATABASE ENGINE
# ─────────────────────────────────────────────────────────────────────────────────
# The "engine" is SQLAlchemy's connection to the database.
# It manages a POOL of connections (doesn't open new connection for every query).

engine = create_engine(
    settings.database_url,
    
    # Connection pool settings
    pool_size=5,           # Keep 5 connections open
    max_overflow=10,       # Allow 10 more during high load
    pool_timeout=30,       # Wait 30s for available connection
    pool_recycle=1800,     # Recycle connections after 30 minutes
    
    # Useful for debugging - logs all SQL queries
    echo=settings.debug,
)

# ─────────────────────────────────────────────────────────────────────────────────
# SESSION FACTORY
# ─────────────────────────────────────────────────────────────────────────────────
# SessionLocal is a FACTORY - call it to create new database sessions.
# Each API request gets its own session (isolated transactions).

SessionLocal = sessionmaker(
    autocommit=False,  # We control when to commit
    autoflush=False,   # We control when to flush
    bind=engine,       # Use our engine
)

# ─────────────────────────────────────────────────────────────────────────────────
# BASE CLASS FOR MODELS
# ─────────────────────────────────────────────────────────────────────────────────
# All our database models inherit from this.
# It provides the mapping between Python classes and database tables.

Base = declarative_base()


# ─────────────────────────────────────────────────────────────────────────────────
# DEPENDENCY FOR FASTAPI
# ─────────────────────────────────────────────────────────────────────────────────
# This is a "dependency" that FastAPI injects into route functions.
# It ensures every request gets a session, and it's closed when done.

def get_db():
    """
    Dependency that provides a database session to FastAPI routes.
    
    Usage in a route:
        @app.get("/domains")
        def get_domains(db: Session = Depends(get_db)):
            return db.query(Domain).all()
    
    The 'yield' makes this a generator:
    1. Before yield: create session
    2. yield: route function runs with the session
    3. After yield (finally): close session
    """
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()