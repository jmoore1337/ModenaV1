# ═══════════════════════════════════════════════════════════════════════════════
# MODENA SCRAPERS - Package Init
# ═══════════════════════════════════════════════════════════════════════════════
# This makes the scrapers/ folder a Python package.
# We export the main scraper functions for easy importing.
# ═══════════════════════════════════════════════════════════════════════════════

from app.scrapers.dns import scan_dns_records
from app.scrapers.whois import scan_whois
from app.scrapers.subdomains import scan_subdomains

__all__ = ["scan_dns_records", "scan_whois", "scan_subdomains"]