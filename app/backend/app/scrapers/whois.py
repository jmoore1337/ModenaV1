# ═══════════════════════════════════════════════════════════════════════════════
# MODENA SCRAPERS - WHOIS LOOKUP
# ═══════════════════════════════════════════════════════════════════════════════
#
# WHY THIS FILE?
# ──────────────
# WHOIS tells you WHO OWNS a domain:
# - Registrar (GoDaddy, Namecheap, etc.)
# - Creation date
# - Expiration date
# - Name servers
# - Registrant info (often hidden for privacy)
#
# HOW WHOIS WORKS:
# ────────────────
# 1. Each TLD (.com, .org, .io) has WHOIS servers
# 2. Query goes to appropriate WHOIS server
# 3. Server returns registration data
# 4. python-whois parses the messy text response
#
# USE CASES:
# ──────────
# - Check if domain is about to expire (security risk!)
# - Find out who owns a suspicious domain
# - Verify domain ownership for security audits
# - Track domain age (older = more trustworthy?)
#
# INTERVIEW TIP:
# ──────────────
# "WHOIS data helps identify domain ownership and expiration.
#  Many security tools check if corporate domains are about to expire -
#  an expired domain could be registered by attackers (domain hijacking)."
# ═══════════════════════════════════════════════════════════════════════════════

import whois
from typing import Dict, Any, Optional, List
from datetime import datetime
import logging

from app.config import get_settings

settings = get_settings()
logger = logging.getLogger(__name__)


def scan_whois(domain: str) -> Optional[Dict[str, Any]]:
    """
    Perform WHOIS lookup for a domain.
    
    Args:
        domain: The domain to lookup (e.g., "google.com")
    
    Returns:
        Dictionary with WHOIS data, or None if lookup failed.
        
        Example output:
        {
            "registrar": "MarkMonitor Inc.",
            "creation_date": datetime(1997, 9, 15),
            "expiration_date": datetime(2028, 9, 14),
            "updated_date": datetime(2019, 9, 9),
            "name_servers": ["ns1.google.com", "ns2.google.com"],
            "registrant_country": "US",
            "raw_data": "... full WHOIS response ..."
        }
    """
    try:
        logger.info(f"Starting WHOIS lookup for {domain}")
        
        # Perform WHOIS lookup
        w = whois.whois(domain)
        
        # Handle case where domain doesn't exist
        if w.domain_name is None:
            logger.warning(f"No WHOIS data found for {domain}")
            return None
        
        result = {
            "registrar": _safe_get(w.registrar),
            "creation_date": _normalize_date(w.creation_date),
            "expiration_date": _normalize_date(w.expiration_date),
            "updated_date": _normalize_date(w.updated_date),
            "name_servers": _normalize_nameservers(w.name_servers),
            "registrant_country": _safe_get(w.country),
            "raw_data": str(w.text) if hasattr(w, 'text') else None,
        }
        
        logger.info(f"WHOIS lookup complete for {domain}: registrar={result['registrar']}")
        return result
        
    except whois.parser.PywhoisError as e:
        logger.warning(f"WHOIS parse error for {domain}: {str(e)}")
        return None
        
    except Exception as e:
        logger.error(f"WHOIS lookup failed for {domain}: {str(e)}")
        return None


def _safe_get(value) -> Optional[str]:
    """
    Safely extract a string value.
    WHOIS responses are messy - sometimes lists, sometimes strings, sometimes None.
    """
    if value is None:
        return None
    if isinstance(value, list):
        return value[0] if value else None
    return str(value)


def _normalize_date(date_value) -> Optional[datetime]:
    """
    Normalize date values from WHOIS.
    Sometimes it's a datetime, sometimes a list of datetimes.
    """
    if date_value is None:
        return None
    
    if isinstance(date_value, list):
        # Take the first date if it's a list
        date_value = date_value[0] if date_value else None
    
    if isinstance(date_value, datetime):
        return date_value
    
    # Try to parse string dates
    if isinstance(date_value, str):
        try:
            return datetime.fromisoformat(date_value)
        except ValueError:
            return None
    
    return None


def _normalize_nameservers(ns_value) -> Optional[List[str]]:
    """
    Normalize name server list.
    Convert to lowercase and remove duplicates.
    """
    if ns_value is None:
        return None
    
    if isinstance(ns_value, str):
        ns_value = [ns_value]
    
    # Lowercase, strip trailing dots, remove duplicates
    nameservers = list(set([
        ns.lower().rstrip(".") 
        for ns in ns_value 
        if ns
    ]))
    
    return sorted(nameservers) if nameservers else None