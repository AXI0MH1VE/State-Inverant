# AWS Region
variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

# Environment
variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod"
  }
}

# VPC Configuration
variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

variable "private_subnets" {
  description = "List of private subnet CIDRs"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "public_subnets" {
  description = "List of public subnet CIDRs"
  type        = list(string)
  default     = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
}

# QLDB Configuration
variable "qldb_ledger_name" {
  description = "Name of the QLDB ledger for audit logging"
  type        = string
  default     = "axiom-audit-ledger"
}

# Container Images
variable "gateway_image" {
  description = "Docker image for service-gateway"
  type        = string
  default     = "axiomhive/service-gateway:latest"
}

variable "guardian_legal_image" {
  description = "Docker image for guardian-legal"
  type        = string
  default     = "axiomhive/guardian-legal:latest"
}

variable "guardian_safety_image" {
  description = "Docker image for guardian-safety"
  type        = string
  default     = "axiomhive/guardian-safety:latest"
}

variable "guardian_audit_image" {
  description = "Docker image for guardian-audit"
  type        = string
  default     = "axiomhive/guardian-audit:latest"
}

variable "drone_image" {
  description = "Docker image for service-drone"
  type        = string
  default     = "axiomhive/service-drone:latest"
}

# Domain Configuration
variable "domain_name" {
  description = "Domain name for SSL certificate"
  type        = string
  default     = "axiomhive.org"
}

# Security Configuration
variable "enable_deletion_protection" {
  description = "Enable deletion protection for critical resources"
  type        = bool
  default     = false
}

# Monitoring Configuration
variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 30
}

# Scaling Configuration
variable "min_capacity" {
  description = "Minimum capacity for auto-scaling"
  type        = number
  default     = 1
}

variable "max_capacity" {
  description = "Maximum capacity for auto-scaling"
  type        = number
  default     = 10
}

# Backup Configuration
variable "backup_retention_days" {
  description = "Backup retention period in days"
  type        = number
  default     = 7
}
