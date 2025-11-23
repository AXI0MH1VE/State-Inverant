terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket = "axiom-hive-terraform-state"
    key    = "axiom-hive.tfstate"
    region = "us-east-1"
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "Axiom Hive"
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}

# VPC Module
module "vpc" {
  source = "./modules/vpc"

  vpc_cidr             = var.vpc_cidr
  availability_zones   = var.availability_zones
  private_subnets      = var.private_subnets
  public_subnets       = var.public_subnets
  enable_nat_gateway   = true
  single_nat_gateway   = var.environment == "dev"
  enable_dns_hostnames = true
  enable_dns_support   = true
  aws_region           = var.aws_region
  environment          = var.environment
}

# QLDB Module
module "qldb" {
  source = "./modules/qldb"

  ledger_name = var.qldb_ledger_name
  permissions_mode = "STANDARD"
}

# ECS Fargate Module
module "ecs_fargate" {
  source = "./modules/ecs_fargate"

  cluster_name    = "axiom-hive-cluster"
  vpc_id          = module.vpc.vpc_id
  vpc_cidr        = module.vpc.vpc_cidr_block
  subnet_ids      = module.vpc.private_subnets
  aws_region      = var.aws_region
  environment     = var.environment
  qldb_ledger_arn = module.qldb.ledger_arn

  services = {
    gateway = {
      name           = "service-gateway"
      image          = var.gateway_image
      cpu            = 256
      memory         = 512
      desired_count  = 2
      container_port = 8080
      host_port      = 8080
    }
    guardian_legal = {
      name           = "guardian-legal"
      image          = var.guardian_legal_image
      cpu            = 256
      memory         = 512
      desired_count  = 2
      container_port = 8081
      host_port      = 8081
    }
    guardian_safety = {
      name           = "guardian-safety"
      image          = var.guardian_safety_image
      cpu            = 512
      memory         = 1024
      desired_count  = 2
      container_port = 8082
      host_port      = 8082
    }
    guardian_audit = {
      name           = "guardian-audit"
      image          = var.guardian_audit_image
      cpu            = 256
      memory         = 512
      desired_count  = 2
      container_port = 8083
      host_port      = 8083
    }
    drone = {
      name           = "service-drone"
      image          = var.drone_image
      cpu            = 1024
      memory         = 2048
      desired_count  = 1
      container_port = 8084
      host_port      = 8084
    }
  }
}

# Application Load Balancer for Web UI
resource "aws_lb" "axiom_hive_alb" {
  name               = "axiom-hive-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = module.vpc.public_subnets

  enable_deletion_protection = var.environment == "prod"
}

resource "aws_lb_target_group" "web_tg" {
  name        = "axiom-hive-web-tg"
  port        = 3000
  protocol    = "HTTP"
  vpc_id      = module.vpc.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200"
    path                = "/api/health"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 2
  }
}

resource "aws_lb_listener" "web_listener" {
  load_balancer_arn = aws_lb.axiom_hive_alb.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = aws_acm_certificate.axiom_hive_cert.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web_tg.arn
  }
}

# Security Groups
resource "aws_security_group" "alb_sg" {
  name_prefix = "axiom-hive-alb-"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ACM Certificate (placeholder - would need actual domain)
resource "aws_acm_certificate" "axiom_hive_cert" {
  domain_name       = var.domain_name
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

# CloudWatch Logs
resource "aws_cloudwatch_log_group" "axiom_hive_logs" {
  name              = "/axiom-hive/${var.environment}"
  retention_in_days = 30
}

# Outputs
output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.axiom_hive_alb.dns_name
}

output "qldb_ledger_name" {
  description = "Name of the QLDB ledger"
  value       = module.qldb.ledger_name
}

output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.vpc_id
}
