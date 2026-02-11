# ═══════════════════════════════════════════════════════════════════════════════
# MODENA BACKEND - App Package Init
# ═══════════════════════════════════════════════════════════════════════════════
# This file makes the app/ folder a Python package.
# It can be empty, but we'll import commonly used items for convenience.
# 
# What it enables:
# In main.py
# from app.config import Settings          # Works!
# from app.models import Domain            # Works!
# from app.routers import domains          # Works!
# ═══════════════════════════════════════════════════════════════════════════════

from app.config import get_settings

__version__ = "1.0.0"