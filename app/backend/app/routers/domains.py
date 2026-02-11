# ═══════════════════════════════════════════════════════════════════════════════
# MODENA API - DOMAINS ROUTER
# ═══════════════════════════════════════════════════════════════════════════════
#
# WHY THIS FILE?
# ──────────────
# API endpoints for managing domains:
# - GET /api/domains - List all domains
# - POST /api/domains - Add a new domain
# - GET /api/domains/{id} - Get one domain
# - DELETE /api/domains/{id} - Delete a domain
#
# HOW FASTAPI ROUTERS WORK:
# ─────────────────────────
# Instead of putting all routes in main.py, we organize by resource:
# - routers/domains.py → /api/domains/*
# - routers/scans.py → /api/scans/*
#
# This is like your Dsny CSD Terraform repo structure:
# - monitors for Winn in one folder
# - monitors for Bymx in another folder
# Same code organization principle!
# ═══════════════════════════════════════════════════════════════════════════════

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List

from app.database import get_db
from app.models import Domain
from app.schemas import DomainCreate, DomainResponse, DomainList

router = APIRouter(
    prefix="/api/domains",
    tags=["domains"],  # Groups endpoints in /docs UI
)


@router.get("", response_model=DomainList)
def list_domains(
    skip: int = 0,
    limit: int = 100,
    db: Session = Depends(get_db)
):
    """
    List all domains.
    
    Query params:
    - skip: Number of records to skip (pagination)
    - limit: Max records to return
    """
    domains = db.query(Domain).filter(Domain.is_active == True).offset(skip).limit(limit).all()
    total = db.query(Domain).filter(Domain.is_active == True).count()
    
    return DomainList(domains=domains, total=total)


@router.post("", response_model=DomainResponse, status_code=status.HTTP_201_CREATED)
def create_domain(
    domain_data: DomainCreate,
    db: Session = Depends(get_db)
):
    """
    Add a new domain to scan.
    
    Request body:
    {
        "domain_name": "google.com"
    }
    """
    # Check if domain already exists
    existing = db.query(Domain).filter(Domain.domain_name == domain_data.domain_name).first()
    if existing:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Domain {domain_data.domain_name} already exists"
        )
    
    # Create new domain
    domain = Domain(domain_name=domain_data.domain_name.lower())
    db.add(domain)
    db.commit()
    db.refresh(domain)
    
    return domain


@router.get("/{domain_id}", response_model=DomainResponse)
def get_domain(
    domain_id: int,
    db: Session = Depends(get_db)
):
    """
    Get a specific domain by ID.
    """
    domain = db.query(Domain).filter(Domain.id == domain_id).first()
    if not domain:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Domain with id {domain_id} not found"
        )
    return domain


@router.delete("/{domain_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_domain(
    domain_id: int,
    db: Session = Depends(get_db)
):
    """
    Delete a domain (soft delete - sets is_active=False).
    """
    domain = db.query(Domain).filter(Domain.id == domain_id).first()
    if not domain:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Domain with id {domain_id} not found"
        )
    
    # Soft delete
    domain.is_active = False
    db.commit()
    
    return None