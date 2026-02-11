# ═══════════════════════════════════════════════════════════════════════════════
# MODENA SCRAPERS - DNS RECORD LOOKUP
# ═══════════════════════════════════════════════════════════════════════════════
#
# WHY THIS FILE?
# ──────────────
# Looks up DNS records for a domain: A, AAAA, MX, TXT, NS, CNAME, SOA
# This is the CORE functionality of a domain intelligence tool.
#
# HOW DNS WORKS (INTERVIEW KNOWLEDGE):
# ────────────────────────────────────
# When you visit google.com:
# 1. Your computer asks DNS resolver: "What's the IP for google.com?"
# 2. Resolver checks: Root servers → .com servers → google.com nameservers
# 3. Returns IP address (A record): 142.250.80.46
# 4. Your browser connects to that IP
#
# RECORD TYPES:
# ─────────────
# A      → IPv4 address (142.250.80.46)
# AAAA   → IPv6 address (2607:f8b0:4004:800::200e)
# MX     → Mail servers (mail.google.com, priority 10)
# TXT    → Text records (SPF, DKIM, domain verification)
# NS     → Name servers (ns1.google.com)
# CNAME  → Alias (www.google.com → google.com)
# SOA    → Start of Authority (primary nameserver, admin email)
#
# INTERVIEW TIP:
# ──────────────
# "DNS is the phone book of the internet. A records map names to IPs.
#  MX records tell email servers where to deliver mail.
#  TXT records are used for SPF/DKIM email authentication and domain verification."
# ═══════════════════════════════════════════════════════════════════════════════

import dns.resolver
import dns.exception
from typing import List, Dict, Any
import logging

from app.config import get_settings

settings = get_settings()
logger = logging.getLogger(__name__)

# DNS record types to query
RECORD_TYPES = ["A", "AAAA", "MX", "TXT", "NS", "CNAME", "SOA"]


def scan_dns_records(domain: str) -> List[Dict[str, Any]]:
    """
    Scan all DNS record types for a domain.
    
    Args:
        domain: The domain to scan (e.g., "google.com")
    
    Returns:
        List of DNS records found, each with:
        - record_type: A, AAAA, MX, etc.
        - record_value: The actual value
        - ttl: Time to live (seconds)
        - priority: For MX records only
    
    Example output:
        [
            {"record_type": "A", "record_value": "142.250.80.46", "ttl": 300},
            {"record_type": "MX", "record_value": "mail.google.com", "ttl": 600, "priority": 10},
        ]
    """
    results = []
    
    # Configure resolver with timeout
    resolver = dns.resolver.Resolver()
    resolver.timeout = settings.scraper_timeout
    resolver.lifetime = settings.scraper_timeout
    
    for record_type in RECORD_TYPES:
        try:
            # Query DNS for this record type
            answers = resolver.resolve(domain, record_type)
            
            for rdata in answers:
                record = {
                    "record_type": record_type,
                    "record_value": _extract_record_value(rdata, record_type),
                    "ttl": answers.ttl,
                }
                
                # MX records have priority
                if record_type == "MX":
                    record["priority"] = rdata.preference
                
                results.append(record)
                logger.debug(f"Found {record_type} record for {domain}: {record['record_value']}")
                
        except dns.resolver.NXDOMAIN:
            # Domain doesn't exist
            logger.warning(f"Domain {domain} does not exist (NXDOMAIN)")
            break  # No point checking other record types
            
        except dns.resolver.NoAnswer:
            # No records of this type (normal - not every domain has AAAA)
            logger.debug(f"No {record_type} records for {domain}")
            continue
            
        except dns.resolver.NoNameservers:
            # No nameservers could answer
            logger.warning(f"No nameservers available for {domain}")
            continue
            
        except dns.exception.Timeout:
            # Query timed out
            logger.warning(f"Timeout querying {record_type} for {domain}")
            continue
            
        except Exception as e:
            # Catch-all for unexpected errors
            logger.error(f"Error querying {record_type} for {domain}: {str(e)}")
            continue
    
    logger.info(f"DNS scan complete for {domain}: found {len(results)} records")
    return results


def _extract_record_value(rdata, record_type: str) -> str:
    """
    Extract the string value from a DNS record.
    
    Different record types have different structures:
    - A/AAAA: Just the IP address
    - MX: The mail server hostname
    - TXT: The text content (may be multiple strings)
    - NS/CNAME: The hostname
    - SOA: Primary NS + admin email
    """
    if record_type == "MX":
        return str(rdata.exchange).rstrip(".")
    
    elif record_type == "TXT":
        # TXT records can be multiple strings, join them
        return "".join([s.decode() if isinstance(s, bytes) else s for s in rdata.strings])
    
    elif record_type == "SOA":
        return f"{rdata.mname} {rdata.rname} (serial: {rdata.serial})"
    
    else:
        # A, AAAA, NS, CNAME - just convert to string
        return str(rdata).rstrip(".")