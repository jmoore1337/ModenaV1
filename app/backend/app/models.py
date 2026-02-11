# ═══════════════════════════════════════════════════════════════════════════════
# MODENA BACKEND - DATABASE MODELS
# ═══════════════════════════════════════════════════════════════════════════════
#
# WHY THIS FILE?
# ──────────────
# Defines the DATABASE TABLES as Python classes.
# SQLAlchemy converts these to CREATE TABLE statements.
#
# TABLES WE'RE CREATING:
# ──────────────────────
# 1. domains      - Domains to scan (google.com, github.com)
# 2. scans        - Each scan attempt (domain + timestamp)
# 3. dns_records  - DNS results (A, MX, TXT, etc.)
# 4. whois_data   - WHOIS results (registrar, dates)
# 5. subdomains   - Found subdomains (www, api, mail)
#
# RELATIONSHIPS:
# ──────────────
# domains ──┬── scans ──┬── dns_records
#           │           ├── whois_data
#           │           └── subdomains
#           │
#           └── (one domain has many scans)
#
# INTERVIEW TIP:
# ──────────────
# "I chose PostgreSQL over DynamoDB for this because the data is relational -
#  domains have scans, scans have results. JOINs make querying easy.
#  DynamoDB is better for simple key-value lookups like Terraform state locking."
# ═══════════════════════════════════════════════════════════════════════════════

from datetime import datetime
from sqlalchemy import Column, Integer, String, DateTime, ForeignKey, Text, Boolean, JSON
from sqlalchemy.orm import relationship

from app.database import Base


class Domain(Base):
    """
    A domain to be scanned.
    
    Example: google.com, github.com, your-company.com
    """
    __tablename__ = "domains"
    
    id = Column(Integer, primary_key=True, index=True)
    domain_name = Column(String(255), unique=True, index=True, nullable=False)
    # WHY index=True? Fast lookups when searching by domain name
    
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    is_active = Column(Boolean, default=True)
    
    # Relationship: One domain has many scans
    scans = relationship("Scan", back_populates="domain", cascade="all, delete-orphan")


class Scan(Base):
    """
    A single scan of a domain.
    
    Each time you scan google.com, a new Scan record is created.
    This lets you track changes over time.
    """
    __tablename__ = "scans"
    
    id = Column(Integer, primary_key=True, index=True)
    domain_id = Column(Integer, ForeignKey("domains.id"), nullable=False)
    
    started_at = Column(DateTime, default=datetime.utcnow)
    completed_at = Column(DateTime, nullable=True)
    status = Column(String(50), default="pending")  # pending, running, completed, failed
    error_message = Column(Text, nullable=True)
    
    # Relationships
    domain = relationship("Domain", back_populates="scans")
    dns_records = relationship("DNSRecord", back_populates="scan", cascade="all, delete-orphan")
    whois_data = relationship("WhoisData", back_populates="scan", uselist=False, cascade="all, delete-orphan")
    subdomains = relationship("Subdomain", back_populates="scan", cascade="all, delete-orphan")


class DNSRecord(Base):
    """
    DNS records found during a scan.
    
    Types: A, AAAA, MX, TXT, NS, CNAME, SOA
    """
    __tablename__ = "dns_records"
    
    id = Column(Integer, primary_key=True, index=True)
    scan_id = Column(Integer, ForeignKey("scans.id"), nullable=False)
    
    record_type = Column(String(10), nullable=False)  # A, AAAA, MX, TXT, NS, CNAME
    record_value = Column(Text, nullable=False)       # The actual value
    ttl = Column(Integer, nullable=True)              # Time to live
    priority = Column(Integer, nullable=True)         # For MX records
    
    scan = relationship("Scan", back_populates="dns_records")


class WhoisData(Base):
    """
    WHOIS information for a domain.
    
    Includes: registrar, creation date, expiration date, name servers
    """
    __tablename__ = "whois_data"
    
    id = Column(Integer, primary_key=True, index=True)
    scan_id = Column(Integer, ForeignKey("scans.id"), nullable=False, unique=True)
    
    registrar = Column(String(255), nullable=True)
    creation_date = Column(DateTime, nullable=True)
    expiration_date = Column(DateTime, nullable=True)
    updated_date = Column(DateTime, nullable=True)
    name_servers = Column(JSON, nullable=True)  # List of name servers
    registrant_country = Column(String(100), nullable=True)
    raw_data = Column(Text, nullable=True)  # Full WHOIS response
    
    scan = relationship("Scan", back_populates="whois_data")


class Subdomain(Base):
    """
    Subdomains discovered during scanning.
    
    Examples: www.google.com, mail.google.com, api.google.com
    """
    __tablename__ = "subdomains"
    
    id = Column(Integer, primary_key=True, index=True)
    scan_id = Column(Integer, ForeignKey("scans.id"), nullable=False)
    
    subdomain_name = Column(String(255), nullable=False)  # www, mail, api
    full_domain = Column(String(255), nullable=False)     # www.google.com
    ip_address = Column(String(45), nullable=True)        # Resolved IP
    is_alive = Column(Boolean, default=False)             # Does it respond?
    http_status = Column(Integer, nullable=True)          # HTTP response code
    
    scan = relationship("Scan", back_populates="subdomains")