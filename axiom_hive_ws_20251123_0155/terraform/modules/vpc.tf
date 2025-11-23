# VPC Configuration for Axiom Hive
# Zero-trust network architecture with isolated subnets

data "aws_availability_zones" "available" {
  state = "available"
}

# VPC
resource "aws_vpc" "axiom_hive" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = var.enable_dns_hostnames
  enable_dns_support   = var.enable_dns_support

  tags = {
    Name        = "axiom-hive-vpc"
    Project     = "Axiom Hive"
    Environment = var.environment
  }
}

# Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.axiom_hive.id

  tags = {
    Name        = "axiom-hive-igw"
    Project     = "Axiom Hive"
    Environment = var.environment
  }
}

# NAT Gateways (one per AZ for high availability)
resource "aws_eip" "nat" {
  count = var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : length(var.availability_zones)) : 0

  domain = "vpc"

  tags = {
    Name        = "axiom-hive-nat-eip-${count.index + 1}"
    Project     = "Axiom Hive"
    Environment = var.environment
  }
}

resource "aws_nat_gateway" "nat" {
  count = var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : length(var.availability_zones)) : 0

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = {
    Name        = "axiom-hive-nat-${count.index + 1}"
    Project     = "Axiom Hive"
    Environment = var.environment
  }

  depends_on = [aws_internet_gateway.igw]
}

# Public Subnets
resource "aws_subnet" "public" {
  count = length(var.public_subnets)

  vpc_id                  = aws_vpc.axiom_hive.id
  cidr_block              = var.public_subnets[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name        = "axiom-hive-public-${count.index + 1}"
    Type        = "Public"
    Project     = "Axiom Hive"
    Environment = var.environment
  }
}

# Private Subnets
resource "aws_subnet" "private" {
  count = length(var.private_subnets)

  vpc_id            = aws_vpc.axiom_hive.id
  cidr_block        = var.private_subnets[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = {
    Name        = "axiom-hive-private-${count.index + 1}"
    Type        = "Private"
    Project     = "Axiom Hive"
    Environment = var.environment
  }
}

# Route Tables
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.axiom_hive.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name        = "axiom-hive-public-rt"
    Type        = "Public"
    Project     = "Axiom Hive"
    Environment = var.environment
  }
}

resource "aws_route_table" "private" {
  count = var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : length(var.availability_zones)) : 1

  vpc_id = aws_vpc.axiom_hive.id

  dynamic "route" {
    for_each = var.enable_nat_gateway ? [1] : []
    content {
      cidr_block     = "0.0.0.0/0"
      nat_gateway_id = var.single_nat_gateway ? aws_nat_gateway.nat[0].id : aws_nat_gateway.nat[count.index].id
    }
  }

  tags = {
    Name        = "axiom-hive-private-rt-${count.index + 1}"
    Type        = "Private"
    Project     = "Axiom Hive"
    Environment = var.environment
  }
}

# Route Table Associations
resource "aws_route_table_association" "public" {
  count = length(var.public_subnets)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  count = length(var.private_subnets)

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = var.single_nat_gateway ? aws_route_table.private[0].id : aws_route_table.private[count.index].id
}

# VPC Endpoints for secure AWS service access (no internet required)
resource "aws_vpc_endpoint" "s3" {
  vpc_id       = aws_vpc.axiom_hive.id
  service_name = "com.amazonaws.${var.aws_region}.s3"

  tags = {
    Name        = "axiom-hive-s3-endpoint"
    Project     = "Axiom Hive"
    Environment = var.environment
  }
}

resource "aws_vpc_endpoint" "qldb" {
  vpc_id             = aws_vpc.axiom_hive.id
  service_name       = "com.amazonaws.${var.aws_region}.qldb"
  vpc_endpoint_type  = "Interface"
  subnet_ids         = aws_subnet.private[*].id
  security_group_ids = [aws_security_group.vpc_endpoint.id]

  tags = {
    Name        = "axiom-hive-qldb-endpoint"
    Project     = "Axiom Hive"
    Environment = var.environment
  }
}

resource "aws_vpc_endpoint" "ecr_api" {
  vpc_id             = aws_vpc.axiom_hive.id
  service_name       = "com.amazonaws.${var.aws_region}.ecr.api"
  vpc_endpoint_type  = "Interface"
  subnet_ids         = aws_subnet.private[*].id
  security_group_ids = [aws_security_group.vpc_endpoint.id]

  tags = {
    Name        = "axiom-hive-ecr-api-endpoint"
    Project     = "Axiom Hive"
    Environment = var.environment
  }
}

resource "aws_vpc_endpoint" "ecr_dkr" {
  vpc_id             = aws_vpc.axiom_hive.id
  service_name       = "com.amazonaws.${var.aws_region}.ecr.dkr"
  vpc_endpoint_type  = "Interface"
  subnet_ids         = aws_subnet.private[*].id
  security_group_ids = [aws_security_group.vpc_endpoint.id]

  tags = {
    Name        = "axiom-hive-ecr-dkr-endpoint"
    Project     = "Axiom Hive"
    Environment = var.environment
  }
}

resource "aws_vpc_endpoint" "logs" {
  vpc_id             = aws_vpc.axiom_hive.id
  service_name       = "com.amazonaws.${var.aws_region}.logs"
  vpc_endpoint_type  = "Interface"
  subnet_ids         = aws_subnet.private[*].id
  security_group_ids = [aws_security_group.vpc_endpoint.id]

  tags = {
    Name        = "axiom-hive-logs-endpoint"
    Project     = "Axiom Hive"
    Environment = var.environment
  }
}

# Security Group for VPC Endpoints
resource "aws_security_group" "vpc_endpoint" {
  name_prefix = "axiom-hive-vpc-endpoint-"
  vpc_id      = aws_vpc.axiom_hive.id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  tags = {
    Name        = "axiom-hive-vpc-endpoint-sg"
    Project     = "Axiom Hive"
    Environment = var.environment
  }
}

# Network ACLs for additional security layer
resource "aws_network_acl" "public" {
  vpc_id     = aws_vpc.axiom_hive.id
  subnet_ids = aws_subnet.public[*].id

  # Allow all inbound from VPC
  ingress {
    protocol   = -1
    rule_no    = 100
    action     = "allow"
    cidr_block = var.vpc_cidr
    from_port  = 0
    to_port    = 0
  }

  # Allow HTTPS inbound from internet
  ingress {
    protocol   = "tcp"
    rule_no    = 110
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 443
    to_port    = 443
  }

  # Allow all outbound
  egress {
    protocol   = -1
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  tags = {
    Name        = "axiom-hive-public-nacl"
    Project     = "Axiom Hive"
    Environment = var.environment
  }
}

resource "aws_network_acl" "private" {
  vpc_id     = aws_vpc.axiom_hive.id
  subnet_ids = aws_subnet.private[*].id

  # Allow all inbound from VPC
  ingress {
    protocol   = -1
    rule_no    = 100
    action     = "allow"
    cidr_block = var.vpc_cidr
    from_port  = 0
    to_port    = 0
  }

  # Allow all outbound
  egress {
    protocol   = -1
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  tags = {
    Name        = "axiom-hive-private-nacl"
    Project     = "Axiom Hive"
    Environment = var.environment
  }
}

# Variables
variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
}

variable "private_subnets" {
  description = "List of private subnet CIDRs"
  type        = list(string)
}

variable "public_subnets" {
  description = "List of public subnet CIDRs"
  type        = list(string)
}

variable "enable_nat_gateway" {
  description = "Enable NAT gateway for private subnets"
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "Use single NAT gateway for all private subnets"
  type        = bool
  default     = false
}

variable "enable_dns_hostnames" {
  description = "Enable DNS hostnames in VPC"
  type        = bool
  default     = true
}

variable "enable_dns_support" {
  description = "Enable DNS support in VPC"
  type        = bool
  default     = true
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

# Outputs
output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.axiom_hive.id
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC"
  value       = aws_vpc.axiom_hive.cidr_block
}

output "private_subnets" {
  description = "List of private subnet IDs"
  value       = aws_subnet.private[*].id
}

output "public_subnets" {
  description = "List of public subnet IDs"
  value       = aws_subnet.public[*].id
}

output "nat_gateway_ids" {
  description = "List of NAT Gateway IDs"
  value       = aws_nat_gateway.nat[*].id
}

output "igw_id" {
  description = "Internet Gateway ID"
  value       = aws_internet_gateway.igw.id
}
