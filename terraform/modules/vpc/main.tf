locals {
  name_prefix = "modena-${var.environment}"
  
  common_tags = merge(var.tags, {
    Environment = var.environment
    Project     = "modena"
    ManagedBy   = "terraform"
  })
}

# ─────────────────────────────────────────────────────────────────────────────────
# VPC
# ─────────────────────────────────────────────────────────────────────────────────
# WHY: Isolated network for all Modena resources
# HOW: Creates a virtual network with the CIDR block you specify
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true  # Required for EKS
  enable_dns_support   = true  # Required for EKS
  
  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-vpc"
  })
}

# ─────────────────────────────────────────────────────────────────────────────────
# INTERNET GATEWAY
# ─────────────────────────────────────────────────────────────────────────────────
# WHY: Allows VPC to communicate with the internet
# HOW: Attaches to VPC, public subnets route 0.0.0.0/0 through this
#
# INTERVIEW TIP: "IGW is the door to the internet. Without it, VPC is isolated."
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  
  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-igw"
  })
}

# ─────────────────────────────────────────────────────────────────────────────────
# PUBLIC SUBNETS
# ─────────────────────────────────────────────────────────────────────────────────
# WHY: Resources here CAN receive traffic from internet (ALB, NAT Gateway)
# HOW: Route table points 0.0.0.0/0 → Internet Gateway
#
# INTERVIEW TIP: "Public subnet = has route to IGW. That's the ONLY difference."
resource "aws_subnet" "public" {
  count = length(var.public_subnet_cidrs)
  
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true  # Instances get public IPs automatically
  
  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-public-${var.availability_zones[count.index]}"
    Type = "public"
    # These tags are REQUIRED for EKS to find subnets for ALB
    "kubernetes.io/role/elb" = "1"
    "kubernetes.io/cluster/modena-${var.environment}-cluster" = "shared"
  })
}

# ─────────────────────────────────────────────────────────────────────────────────
# PRIVATE SUBNETS
# ─────────────────────────────────────────────────────────────────────────────────
# WHY: Resources here CANNOT receive direct internet traffic (EKS nodes, RDS)
# HOW: Route table points 0.0.0.0/0 → NAT Gateway (outbound only)
#
# FROM YOUR CISCO WORK: Wiz would flag any database in a public subnet!
resource "aws_subnet" "private" {
  count = length(var.private_subnet_cidrs)
  
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]
  
  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-private-${var.availability_zones[count.index]}"
    Type = "private"
    # These tags are REQUIRED for EKS to find subnets for internal load balancers
    "kubernetes.io/role/internal-elb" = "1"
    "kubernetes.io/cluster/modena-${var.environment}-cluster" = "shared"
  })
}

# ─────────────────────────────────────────────────────────────────────────────────
# ELASTIC IP FOR NAT GATEWAY
# ─────────────────────────────────────────────────────────────────────────────────
# WHY: NAT Gateway needs a static public IP
# HOW: AWS allocates a public IP that doesn't change
resource "aws_eip" "nat" {
  count  = var.enable_nat_gateway ? 1 : 0
  domain = "vpc"
  
  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-nat-eip"
  })
  
  depends_on = [aws_internet_gateway.main]
}

# ─────────────────────────────────────────────────────────────────────────────────
# NAT GATEWAY
# ─────────────────────────────────────────────────────────────────────────────────
# WHY: Private subnets need internet access (pull Docker images, etc.)
# HOW: Lives in PUBLIC subnet, translates private IPs to its public IP
#
# TRAFFIC FLOW:
# EKS Node (10.0.3.15) → NAT Gateway (public IP) → Internet → ECR
# Response comes back through NAT, translated back to 10.0.3.15
#
# INTERVIEW TIP: "NAT = Network Address Translation. Outbound yes, inbound no."
resource "aws_nat_gateway" "main" {
  count = var.enable_nat_gateway ? 1 : 0
  
  allocation_id = aws_eip.nat[0].id
  subnet_id     = aws_subnet.public[0].id  # NAT lives in PUBLIC subnet!
  
  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-nat"
  })
  
  depends_on = [aws_internet_gateway.main]
}

# ─────────────────────────────────────────────────────────────────────────────────
# PUBLIC ROUTE TABLE
# ─────────────────────────────────────────────────────────────────────────────────
# WHY: Tells public subnets how to route traffic
# HOW: 0.0.0.0/0 (all traffic) → Internet Gateway
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
  
  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-public-rt"
  })
}

# Associate public subnets with public route table
resource "aws_route_table_association" "public" {
  count = length(var.public_subnet_cidrs)
  
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# ─────────────────────────────────────────────────────────────────────────────────
# PRIVATE ROUTE TABLE
# ─────────────────────────────────────────────────────────────────────────────────
# WHY: Tells private subnets how to route traffic
# HOW: 0.0.0.0/0 (all traffic) → NAT Gateway (not IGW!)
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id
  
  # Only add NAT route if NAT Gateway is enabled
  dynamic "route" {
    for_each = var.enable_nat_gateway ? [1] : []
    content {
      cidr_block     = "0.0.0.0/0"
      nat_gateway_id = aws_nat_gateway.main[0].id
    }
  }
  
  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-private-rt"
  })
}

# Associate private subnets with private route table
resource "aws_route_table_association" "private" {
  count = length(var.private_subnet_cidrs)
  
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}