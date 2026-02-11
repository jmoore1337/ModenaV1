# ═══════════════════════════════════════════════════════════════════════════════
# MODENA API - SCANS ROUTER
# ═══════════════════════════════════════════════════════════════════════════════
#
# WHY THIS FILE?
# ──────────────
# API endpoints for running scans:
# - POST /api/scans - Start a new scan
# - GET /api/scans/{id} - Get scan results
# - GET /api/scans - List all scans
#
# THE SCAN FLOW:
# ──────────────
# 1. POST /api/scans {"domain_name": "google.com"}
# 2. Backend creates Domain if not exists
# 3. Backend creates Scan record (status: running)
# 4. Backend runs scrapers (DNS, WHOIS, subdomains)
# 5. Backend saves results to database
# 6. Backend updates Scan (status: completed)
# 7. Returns scan results
#
# THIS IS YOUR APP'S MAIN FUNCTIONALITY!
# ═══════════════════════════════════════════════════════════════════════════════

from datetime import datetime
from fastapi import APIRouter, Depends, HTTPException, status, BackgroundTasks
from sqlalchemy.orm import Session
from typing import List

from app.database import get_db
from app.models import Domain, Scan, DNSRecord, WhoisData, Subdomain
from app.schemas import ScanCreate, ScanResponse, ScanResultResponse
from app.scrapers import scan_dns_records, scan_whois, scan_subdomains

import logging

logger = logging.getLogger(__name__)

router = APIRouter(
    prefix="/api/scans",
    tags=["scans"],
)


@router.post("", response_model=ScanResultResponse, status_code=status.HTTP_201_CREATED)
def create_scan(
    scan_data: ScanCreate,
    db: Session = Depends(get_db)
):
    """
    Start a new scan for a domain.
    
    This is SYNCHRONOUS - waits for scan to complete.
    For production, you'd want this to be async (return scan ID, poll for results).
    
    Request body:
    {
        "domain_name": "google.com",
        "include_subdomains": true,
        "include_whois": true
    }
    """
    domain_name = scan_data.domain_name.lower()
    logger.info(f"Starting scan for {domain_name}")
    
    # ─────────────────────────────────────────────────────────────────────────
    # STEP 1: Get or create domain
    # ─────────────────────────────────────────────────────────────────────────
    domain = db.query(Domain).filter(Domain.domain_name == domain_name).first()
    if not domain:
        domain = Domain(domain_name=domain_name)
        db.add(domain)
        db.commit()
        db.refresh(domain)
        logger.info(f"Created new domain: {domain_name}")
    
    # ─────────────────────────────────────────────────────────────────────────
    # STEP 2: Create scan record
    # ─────────────────────────────────────────────────────────────────────────
    scan = Scan(
        domain_id=domain.id,
        status="running"
    )
    db.add(scan)
    db.commit()
    db.refresh(scan)
    logger.info(f"Created scan {scan.id} for {domain_name}")
    
    try:
        # ─────────────────────────────────────────────────────────────────────
        # STEP 3: Run DNS scan (always)
        # ─────────────────────────────────────────────────────────────────────
        logger.info(f"Running DNS scan for {domain_name}")
        dns_results = scan_dns_records(domain_name)
        
        for record in dns_results:
            dns_record = DNSRecord(
                scan_id=scan.id,
                record_type=record["record_type"],
                record_value=record["record_value"],
                ttl=record.get("ttl"),
                priority=record.get("priority"),
            )
            db.add(dns_record)
        
        # ─────────────────────────────────────────────────────────────────────
        # STEP 4: Run WHOIS scan (if requested)
        # ─────────────────────────────────────────────────────────────────────
        if scan_data.include_whois:
            logger.info(f"Running WHOIS scan for {domain_name}")
            whois_result = scan_whois(domain_name)
            
            if whois_result:
                whois_data = WhoisData(
                    scan_id=scan.id,
                    registrar=whois_result.get("registrar"),
                    creation_date=whois_result.get("creation_date"),
                    expiration_date=whois_result.get("expiration_date"),
                    updated_date=whois_result.get("updated_date"),
                    name_servers=whois_result.get("name_servers"),
                    registrant_country=whois_result.get("registrant_country"),
                    raw_data=whois_result.get("raw_data"),
                )
                db.add(whois_data)
        
        # ─────────────────────────────────────────────────────────────────────
        # STEP 5: Run subdomain scan (if requested)
        # ─────────────────────────────────────────────────────────────────────
        if scan_data.include_subdomains:
            logger.info(f"Running subdomain scan for {domain_name}")
            subdomain_results = scan_subdomains(domain_name)
            
            for sub in subdomain_results:
                subdomain = Subdomain(
                    scan_id=scan.id,
                    subdomain_name=sub["subdomain_name"],
                    full_domain=sub["full_domain"],
                    ip_address=sub.get("ip_address"),
                    is_alive=sub.get("is_alive", False),
                    http_status=sub.get("http_status"),
                )
                db.add(subdomain)
        
        # ─────────────────────────────────────────────────────────────────────
        # STEP 6: Mark scan as completed
        # ─────────────────────────────────────────────────────────────────────
        scan.status = "completed"
        scan.completed_at = datetime.utcnow()
        db.commit()
        
        logger.info(f"Scan {scan.id} completed for {domain_name}")
        
    except Exception as e:
        # ─────────────────────────────────────────────────────────────────────
        # Handle errors
        # ─────────────────────────────────────────────────────────────────────
        logger.error(f"Scan {scan.id} failed: {str(e)}")
        scan.status = "failed"
        scan.error_message = str(e)
        scan.completed_at = datetime.utcnow()
        db.commit()
        
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Scan failed: {str(e)}"
        )
    
    # ─────────────────────────────────────────────────────────────────────────
    # STEP 7: Refresh and return results
    # ─────────────────────────────────────────────────────────────────────────
    db.refresh(scan)
    
    return ScanResultResponse(
        scan=scan,
        domain=domain,
        dns_records=scan.dns_records,
        whois=scan.whois_data,
        subdomains=scan.subdomains,
    )


@router.get("/{scan_id}", response_model=ScanResultResponse)
def get_scan(
    scan_id: int,
    db: Session = Depends(get_db)
):
    """
    Get results of a specific scan.
    """
    scan = db.query(Scan).filter(Scan.id == scan_id).first()
    if not scan:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Scan {scan_id} not found"
        )
    
    return ScanResultResponse(
        scan=scan,
        domain=scan.domain,
        dns_records=scan.dns_records,
        whois=scan.whois_data,
        subdomains=scan.subdomains,
    )


@router.get("", response_model=List[ScanResponse])
def list_scans(
    skip: int = 0,
    limit: int = 50,
    db: Session = Depends(get_db)
):
    """
    List all scans (most recent first).
    """
    scans = (
        db.query(Scan)
        .order_by(Scan.started_at.desc())
        .offset(skip)
        .limit(limit)
        .all()
    )
    return scans