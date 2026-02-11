# ═══════════════════════════════════════════════════════════════════════════════
# MODENA BACKEND - CONFIGURATION
# ═══════════════════════════════════════════════════════════════════════════════
# 
# WHY THIS FILE?
# ──────────────
# Centralizes ALL configuration in one place.
# Values come from ENVIRONMENT VARIABLES, not hardcoded.
#
# HOW IT CONNECTS TO YOUR INFRASTRUCTURE:
# ───────────────────────────────────────
# Your RDS endpoint: modena-dev-db.cetosysiae5v.us-east-1.rds.amazonaws.com
# Your RDS port: 5432
# Your RDS database: modena
# Your RDS username: modena_admin
# Your RDS password: (from Secrets Manager or env var)
#
# In Kubernetes, these come from:
#   - ConfigMap (non-sensitive: host, port, db name)
#   - Secret (sensitive: password)
#
# INTERVIEW TIP:
# ──────────────
# "I never hardcode database credentials. They come from environment variables,
#  which in Kubernetes are injected from ConfigMaps and Secrets. The app doesn't
#  know or care where the values come from - it just reads environment variables."
#
# This matches your Cisco experience (IMG_3154):
# "everything that is called a secret should go through a certain process"
# ═══════════════════════════════════════════════════════════════════════════════

from pydantic_settings import BaseSettings
from functools import lru_cache


class Settings(BaseSettings):
    """
    Application settings loaded from environment variables.
    
    Pydantic automatically reads these from environment:
      DATABASE_HOST=xxx  →  settings.database_host
      DATABASE_PORT=5432 →  settings.database_port
    """
    
    # ─────────────────────────────────────────────────────────────────────────
    # APPLICATION
    # ─────────────────────────────────────────────────────────────────────────
    app_name: str = "Modena Domain Intelligence"
    app_version: str = "1.0.0"
    environment: str = "dev"  # dev, stage, prod
    debug: bool = True
    
    # ─────────────────────────────────────────────────────────────────────────
    # DATABASE (Your RDS!)
    # ─────────────────────────────────────────────────────────────────────────
    # These map to YOUR deployed infrastructure:
    database_host: str = "localhost"  # Override with RDS endpoint
    database_port: int = 5432
    database_name: str = "modena"
    database_user: str = "modena_admin"
    database_password: str = "changeme"  # NEVER commit real password!
    
    @property
    def database_url(self) -> str:
        """
        Constructs the SQLAlchemy connection string.
        
        Format: postgresql://user:password@host:port/database
        
        YOUR RDS would be:
        postgresql://modena_admin:xxx@modena-dev-db.cetosysiae5v.us-east-1.rds.amazonaws.com:5432/modena
        """
        return (
            f"postgresql://{self.database_user}:{self.database_password}"
            f"@{self.database_host}:{self.database_port}/{self.database_name}"
        )
    
    # ─────────────────────────────────────────────────────────────────────────
    # SCRAPER SETTINGS
    # ─────────────────────────────────────────────────────────────────────────
    scraper_timeout: int = 10  # Seconds to wait for DNS/WHOIS responses
    scraper_max_retries: int = 3
    
    # Common subdomains to check (can be extended)
    common_subdomains: list = [
        "www", "mail", "ftp", "admin", "api", "dev", "staging", "test",
        "blog", "shop", "store", "app", "portal", "secure", "vpn",
        "remote", "webmail", "mx", "ns1", "ns2", "cdn", "static"
    ]
    
    class Config:
        # Load from .env file if it exists (for local development)
        env_file = ".env"
        env_file_encoding = "utf-8"


@lru_cache()
def get_settings() -> Settings:
    """
    Returns cached settings instance.
    
    WHY @lru_cache?
    ───────────────
    Settings are read ONCE and cached.
    Every call to get_settings() returns the same instance.
    Faster than re-reading environment variables every time.
    """
    return Settings()