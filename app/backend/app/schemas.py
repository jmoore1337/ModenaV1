# ═══════════════════════════════════════════════════════════════════════════════
# MODENA BACKEND - PYDANTIC SCHEMAS
# ═══════════════════════════════════════════════════════════════════════════════
#
# WHY THIS FILE?
# ──────────────
# Defines the SHAPE of API requests and responses.
# Pydantic validates incoming data and serializes outgoing data.
#
# MODELS vs SCHEMAS:
# ──────────────────
# models.py  = Database tables (SQLAlchemy)
# schemas.py = API data shapes (Pydantic)
#
# They're similar but separate because:
# - You might not want to expose all database fields via API
# - API might accept different fields for create vs update
# - Validation rules differ between DB and API
#
# INTERVIEW TIP:
# ──────────────
# "I separate database models from API schemas. This gives me control over
#  what data is exposed, allows different validation rules, and makes the
#  API contract independent of the database schema."
# ═══════════════════════════════════════════════════════════════════════════════

from datetime import datetime
from typing import Optional, List
from pydantic import BaseModel, Field


# ─────────────────────────────────────────────────────────────────────────────────
# DOMAIN SCHEMAS
# ─────────────────────────────────────────────────────────────────────────────────

class DomainCreate(BaseModel):
    """Schema for creating a new domain."""
    domain_name: str = Field(..., min_length=3, max_length=255, example="google.com")


class DomainResponse(BaseModel):
    """Schema for domain in API responses."""
    id: int
    domain_name: str
    created_at: datetime
    is_active: bool
    
    class Config:
        from_attributes = True  # Allows conversion from SQLAlchemy model


class DomainList(BaseModel):
    """Schema for list of domains."""
    domains: List[DomainResponse]
    total: int


# ─────────────────────────────────────────────────────────────────────────────────
# DNS RECORD SCHEMAS
# ─────────────────────────────────────────────────────────────────────────────────

class DNSRecordResponse(BaseModel):
    """Schema for DNS record in API responses."""
    record_type: str
    record_value: str
    ttl: Optional[int] = None
    priority: Optional[int] = None
    
    class Config:
        from_attributes = True


# ─────────────────────────────────────────────────────────────────────────────────
# WHOIS SCHEMAS
# ─────────────────────────────────────────────────────────────────────────────────

class WhoisResponse(BaseModel):
    """Schema for WHOIS data in API responses."""
    registrar: Optional[str] = None
    creation_date: Optional[datetime] = None
    expiration_date: Optional[datetime] = None
    updated_date: Optional[datetime] = None
    name_servers: Optional[List[str]] = None
    registrant_country: Optional[str] = None
    
    class Config:
        from_attributes = True


# ─────────────────────────────────────────────────────────────────────────────────
# SUBDOMAIN SCHEMAS
# ─────────────────────────────────────────────────────────────────────────────────

class SubdomainResponse(BaseModel):
    """Schema for subdomain in API responses."""
    subdomain_name: str
    full_domain: str
    ip_address: Optional[str] = None
    is_alive: bool
    http_status: Optional[int] = None
    
    class Config:
        from_attributes = True


# ─────────────────────────────────────────────────────────────────────────────────
# SCAN SCHEMAS
# ─────────────────────────────────────────────────────────────────────────────────

class ScanCreate(BaseModel):
    """Schema for starting a new scan."""
    domain_name: str = Field(..., min_length=3, max_length=255)
    include_subdomains: bool = True
    include_whois: bool = True


class ScanResponse(BaseModel):
    """Schema for scan in API responses."""
    id: int
    domain_id: int
    started_at: datetime
    completed_at: Optional[datetime] = None
    status: str
    error_message: Optional[str] = None
    
    class Config:
        from_attributes = True


class ScanResultResponse(BaseModel):
    """Schema for complete scan results."""
    scan: ScanResponse
    domain: DomainResponse
    dns_records: List[DNSRecordResponse]
    whois: Optional[WhoisResponse] = None
    subdomains: List[SubdomainResponse]


# ─────────────────────────────────────────────────────────────────────────────────
# HEALTH CHECK
# ─────────────────────────────────────────────────────────────────────────────────

class HealthResponse(BaseModel):
    """Schema for health check response."""
    status: str
    version: str
    environment: str
    database_connected: bool