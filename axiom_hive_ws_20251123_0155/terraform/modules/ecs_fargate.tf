# ECS Fargate Configuration for Axiom Hive Microservices

# ECS Cluster
resource "aws_ecs_cluster" "axiom_hive" {
  name = var.cluster_name

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = {
    Name        = "axiom-hive-cluster"
    Project     = "Axiom Hive"
    Environment = var.environment
  }
}

# ECS Task Execution Role
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "axiom-hive-ecs-task-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "Axiom Hive ECS Task Execution Role"
    Project     = "Axiom Hive"
    Environment = var.environment
  }
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# ECS Task Role (for application permissions)
resource "aws_iam_role" "ecs_task_role" {
  name = "axiom-hive-ecs-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "Axiom Hive ECS Task Role"
    Project     = "Axiom Hive"
    Environment = var.environment
  }
}

# Custom policy for ECS tasks
resource "aws_iam_role_policy" "ecs_task_policy" {
  name = "axiom-hive-ecs-task-policy"
  role = aws_iam_role.ecs_task_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "qldb:GetBlock",
          "qldb:GetDigest",
          "qldb:GetRevision",
          "qldb:ListTables",
          "qldb:Query",
          "qldb:SendCommand"
        ]
        Resource = var.qldb_ledger_arn
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:log-group:/axiom-hive/${var.environment}:*"
      }
    ]
  })
}

# CloudWatch Log Groups
resource "aws_cloudwatch_log_group" "ecs_services" {
  for_each = var.services

  name              = "/axiom-hive/${var.environment}/${each.key}"
  retention_in_days = 30

  tags = {
    Name        = "axiom-hive-${each.key}-logs"
    Service     = each.key
    Project     = "Axiom Hive"
    Environment = var.environment
  }
}

# ECS Task Definitions
resource "aws_ecs_task_definition" "services" {
  for_each = var.services

  family                   = "axiom-hive-${each.key}"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = each.value.cpu
  memory                   = each.value.memory
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name  = each.key
      image = each.value.image

      essential = true

      portMappings = [
        {
          containerPort = each.value.container_port
          hostPort      = each.value.host_port
          protocol      = "tcp"
        }
      ]

      environment = concat(
        [
          {
            name  = "ENVIRONMENT"
            value = var.environment
          },
          {
            name  = "SERVICE_NAME"
            value = each.key
          }
        ],
        each.value.environment != null ? [
          for env_key, env_value in each.value.environment : {
            name  = env_key
            value = env_value
          }
        ] : []
      )

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/axiom-hive/${var.environment}/${each.key}"
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }

      healthCheck = {
        command = [
          "CMD-SHELL",
          "curl -f http://localhost:${each.value.container_port}/health || exit 1"
        ]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }

      # Security: Read-only root filesystem
      readonlyRootFilesystem = true

      # Security: Non-privileged user
      user = "1001:1001"
    }
  ])

  tags = {
    Name        = "axiom-hive-${each.key}-task"
    Service     = each.key
    Project     = "Axiom Hive"
    Environment = var.environment
  }
}

# ECS Services
resource "aws_ecs_service" "services" {
  for_each = var.services

  name            = "axiom-hive-${each.key}"
  cluster         = aws_ecs_cluster.axiom_hive.id
  task_definition = aws_ecs_task_definition.services[each.key].arn
  desired_count   = each.value.desired_count

  launch_type = "FARGATE"

  network_configuration {
    security_groups = [aws_security_group.ecs_service[each.key].id]
    subnets         = var.subnet_ids
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.services[each.key].arn
    container_name   = each.key
    container_port   = each.value.container_port
  }

  depends_on = [
    aws_lb_listener.services[each.key]
  ]

  tags = {
    Name        = "axiom-hive-${each.key}-service"
    Service     = each.key
    Project     = "Axiom Hive"
    Environment = var.environment
  }

  # Enable rolling updates
  deployment_controller {
    type = "ECS"
  }

  # Health check grace period
  health_check_grace_period_seconds = 60
}

# Internal Load Balancer for service-to-service communication
resource "aws_lb" "internal" {
  name               = "axiom-hive-internal-alb"
  internal           = true
  load_balancer_type = "application"
  security_groups    = [aws_security_group.internal_alb.id]
  subnets            = var.subnet_ids

  tags = {
    Name        = "axiom-hive-internal-alb"
    Project     = "Axiom Hive"
    Environment = var.environment
  }
}

# Target Groups for each service
resource "aws_lb_target_group" "services" {
  for_each = var.services

  name        = "axiom-hive-${each.key}-tg"
  port        = each.value.container_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200"
    path                = "/health"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 2
  }

  tags = {
    Name        = "axiom-hive-${each.key}-tg"
    Service     = each.key
    Project     = "Axiom Hive"
    Environment = var.environment
  }
}

# Internal ALB Listeners
resource "aws_lb_listener" "services" {
  for_each = var.services

  load_balancer_arn = aws_lb.internal.arn
  port              = each.value.host_port
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.services[each.key].arn
  }
}

# Security Groups
resource "aws_security_group" "internal_alb" {
  name_prefix = "axiom-hive-internal-alb-"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 8080
    to_port     = 8084
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "axiom-hive-internal-alb-sg"
    Project     = "Axiom Hive"
    Environment = var.environment
  }
}

resource "aws_security_group" "ecs_service" {
  for_each = var.services

  name_prefix = "axiom-hive-${each.key}-"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = each.value.container_port
    to_port         = each.value.container_port
    protocol        = "tcp"
    security_groups = [aws_security_group.internal_alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "axiom-hive-${each.key}-sg"
    Service     = each.key
    Project     = "Axiom Hive"
    Environment = var.environment
  }
}

# Auto Scaling
resource "aws_appautoscaling_target" "ecs_target" {
  for_each = var.services

  max_capacity       = 10
  min_capacity       = 1
  resource_id        = "service/${aws_ecs_cluster.axiom_hive.name}/axiom-hive-${each.key}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "ecs_cpu" {
  for_each = var.services

  name               = "axiom-hive-${each.key}-cpu-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs_target[each.key].resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_target[each.key].scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_target[each.key].service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value = 70.0
  }
}

resource "aws_appautoscaling_policy" "ecs_memory" {
  for_each = var.services

  name               = "axiom-hive-${each.key}-memory-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs_target[each.key].resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_target[each.key].scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_target[each.key].service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }
    target_value = 80.0
  }
}

# Variables
variable "cluster_name" {
  description = "Name of the ECS cluster"
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block of the VPC"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for ECS services"
  type        = list(string)
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "qldb_ledger_arn" {
  description = "ARN of the QLDB ledger"
  type        = string
}

variable "services" {
  description = "Map of services to deploy"
  type = map(object({
    name           = string
    image          = string
    cpu            = number
    memory         = number
    desired_count  = number
    container_port = number
    host_port      = number
    environment    = optional(map(string))
  }))
}

# Outputs
output "cluster_name" {
  description = "Name of the ECS cluster"
  value       = aws_ecs_cluster.axiom_hive.name
}

output "cluster_arn" {
  description = "ARN of the ECS cluster"
  value       = aws_ecs_cluster.axiom_hive.arn
}

output "service_arns" {
  description = "Map of service ARNs"
  value       = { for k, v in aws_ecs_service.services : k => v.id }
}

output "internal_alb_dns_name" {
  description = "DNS name of the internal ALB"
  value       = aws_lb.internal.dns_name
}
