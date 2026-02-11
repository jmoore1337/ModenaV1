#!/bin/bash

# ═══════════════════════════════════════════════════════════════════════════════
# init-backend.sh - Creates S3 bucket and DynamoDB table for Terraform state
# ═══════════════════════════════════════════════════════════════════════════════
#
# WHAT THIS SCRIPT DOES:
# ──────────────────────
# 1. Creates an S3 bucket to store Terraform state files
# 2. Enables versioning on the bucket (so you can rollback state)
# 3. Enables encryption on the bucket (security)
# 4. Creates a DynamoDB table for state locking
#
# WHY A SCRIPT INSTEAD OF TERRAFORM?
# ──────────────────────────────────
# Chicken and egg problem:
#   - Terraform needs S3 bucket to store state
#   - But to create S3 bucket with Terraform, you need... state storage
#
# Solution: Create the bucket with AWS CLI first, then use Terraform for everything else.
#
# USAGE:
# ──────
# ./scripts/init-backend.sh
#
# ═══════════════════════════════════════════════════════════════════════════════

set -e  # Exit immediately if any command fails

# ─────────────────────────────────────────────────────────────────────────────
# CONFIGURATION  You create the names here,
# ─────────────────────────────────────────────────────────────────────────────
AWS_REGION="us-east-1"
BUCKET_NAME="modena-terraform-state-$(aws sts get-caller-identity --query Account --output text)"
DYNAMODB_TABLE="modena-terraform-locks"

# ─────────────────────────────────────────────────────────────────────────────
# COLORS FOR OUTPUT
# ─────────────────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}═══════════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  TERRAFORM BACKEND INITIALIZATION${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════════${NC}"
echo ""

# ─────────────────────────────────────────────────────────────────────────────
# STEP 1: CREATE S3 BUCKET
# ─────────────────────────────────────────────────────────────────────────────
echo -e "${YELLOW}STEP 1: Creating S3 bucket for Terraform state...${NC}"
echo -e "  Bucket name: ${GREEN}${BUCKET_NAME}${NC}"
echo ""

# Check if bucket already exists
if aws s3api head-bucket --bucket "$BUCKET_NAME" 2>/dev/null; then
    echo -e "  ${GREEN}✓ Bucket already exists${NC}"
else
    # Create the bucket
    # Note: us-east-1 doesn't need LocationConstraint, other regions do
    if [ "$AWS_REGION" = "us-east-1" ]; then
        aws s3api create-bucket \
            --bucket "$BUCKET_NAME" \
            --region "$AWS_REGION"
    else
        aws s3api create-bucket \
            --bucket "$BUCKET_NAME" \
            --region "$AWS_REGION" \
            --create-bucket-configuration LocationConstraint="$AWS_REGION"
    fi
    echo -e "  ${GREEN}✓ Bucket created${NC}"
fi

echo ""

# ─────────────────────────────────────────────────────────────────────────────
# STEP 2: ENABLE VERSIONING ON S3 BUCKET
# ─────────────────────────────────────────────────────────────────────────────
# WHY VERSIONING?
# ───────────────
# If you accidentally corrupt the state file, you can restore a previous version.
# This has saved many engineers from disaster.
# ─────────────────────────────────────────────────────────────────────────────
echo -e "${YELLOW}STEP 2: Enabling versioning on S3 bucket...${NC}"

aws s3api put-bucket-versioning \
    --bucket "$BUCKET_NAME" \
    --versioning-configuration Status=Enabled

echo -e "  ${GREEN}✓ Versioning enabled${NC}"
echo "" 

# ─────────────────────────────────────────────────────────────────────────────
# STEP 3: ENABLE SERVER-SIDE ENCRYPTION
# ─────────────────────────────────────────────────────────────────────────────
# WHY ENCRYPTION?
# ───────────────
# State files contain sensitive data:
#   - Database passwords
#   - Private IPs
#   - Resource configurations
# Encryption ensures this data is protected at rest.
# ─────────────────────────────────────────────────────────────────────────────
echo -e "${YELLOW}STEP 3: Enabling encryption on S3 bucket...${NC}"

aws s3api put-bucket-encryption \
    --bucket "$BUCKET_NAME" \
    --server-side-encryption-configuration '{
        "Rules": [
            {
                "ApplyServerSideEncryptionByDefault": {
                    "SSEAlgorithm": "AES256"
                },
                "BucketKeyEnabled": true
            }
        ]
    }'

echo -e "  ${GREEN}✓ Encryption enabled (AES-256)${NC}"
echo ""

# ─────────────────────────────────────────────────────────────────────────────
# STEP 4: BLOCK PUBLIC ACCESS
# ─────────────────────────────────────────────────────────────────────────────
# WHY BLOCK PUBLIC ACCESS?
# ────────────────────────
# State files should NEVER be public.
# This setting prevents accidental public exposure.
# ─────────────────────────────────────────────────────────────────────────────
echo -e "${YELLOW}STEP 4: Blocking public access on S3 bucket...${NC}"

aws s3api put-public-access-block \
    --bucket "$BUCKET_NAME" \
    --public-access-block-configuration '{
        "BlockPublicAcls": true,
        "IgnorePublicAcls": true,
        "BlockPublicPolicy": true,
        "RestrictPublicBuckets": true
    }'

echo -e "  ${GREEN}✓ Public access blocked${NC}"
echo ""

# ─────────────────────────────────────────────────────────────────────────────
# STEP 5: CREATE DYNAMODB TABLE FOR STATE LOCKING
# ─────────────────────────────────────────────────────────────────────────────
# WHY DYNAMODB?
# ─────────────
# DynamoDB supports "conditional writes" which means:
#   "Only write this record IF it doesn't already exist"
# This is perfect for locking — only one person can acquire the lock.
#
# TABLE STRUCTURE:
# ────────────────
# Primary Key: LockID (String)
# This is all Terraform needs. It writes a record with LockID = state file path.
# ─────────────────────────────────────────────────────────────────────────────
echo -e "${YELLOW}STEP 5: Creating DynamoDB table for state locking...${NC}"
echo -e "  Table name: ${GREEN}${DYNAMODB_TABLE}${NC}"
echo ""

# Check if table already exists
if aws dynamodb describe-table --table-name "$DYNAMODB_TABLE" 2>/dev/null; then
    echo -e "  ${GREEN}✓ Table already exists${NC}"
else
    aws dynamodb create-table \
        --table-name "$DYNAMODB_TABLE" \
        --attribute-definitions AttributeName=LockID,AttributeType=S \
        --key-schema AttributeName=LockID,KeyType=HASH \
        --billing-mode PAY_PER_REQUEST \
        --region "$AWS_REGION"
    
    echo -e "  ${GREEN}✓ Table created${NC}"
    
    # Wait for table to be active
    echo -e "  Waiting for table to be active..."
    aws dynamodb wait table-exists --table-name "$DYNAMODB_TABLE"
    echo -e "  ${GREEN}✓ Table is active${NC}"
fi

echo ""

# ─────────────────────────────────────────────────────────────────────────────
# DONE
# ─────────────────────────────────────────────────────────────────────────────
echo -e "${BLUE}═══════════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  TERRAFORM BACKEND INITIALIZED SUCCESSFULLY${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "  S3 Bucket:      ${GREEN}${BUCKET_NAME}${NC}"
echo -e "  DynamoDB Table: ${GREEN}${DYNAMODB_TABLE}${NC}"
echo ""
echo -e "${YELLOW}  NEXT STEPS:${NC}"
echo -e "  1. Update terraform/environments/dev/backend.tf with:"
echo -e "     bucket = \"${BUCKET_NAME}\""
echo -e "     dynamodb_table = \"${DYNAMODB_TABLE}\""
echo ""
echo -e "  2. Run: cd terraform/environments/dev && terraform init"
echo ""