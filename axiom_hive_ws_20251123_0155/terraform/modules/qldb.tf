# QLDB Ledger for Immutable Audit Trail

resource "aws_qldb_ledger" "axiom_audit" {
  name                = var.ledger_name
  permissions_mode    = var.permissions_mode
  deletion_protection = var.deletion_protection

  tags = {
    Name        = "Axiom Hive Audit Ledger"
    Purpose     = "Immutable transaction logging"
    Project     = "Axiom Hive"
    Environment = var.environment
  }
}

# IAM Role for QLDB Stream
resource "aws_iam_role" "qldb_stream_role" {
  count = var.enable_stream ? 1 : 0

  name = "axiom-hive-qldb-stream-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "qldb.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "Axiom Hive QLDB Stream Role"
    Project     = "Axiom Hive"
    Environment = var.environment
  }
}

resource "aws_iam_role_policy" "qldb_stream_policy" {
  count = var.enable_stream ? 1 : 0

  name = "axiom-hive-qldb-stream-policy"
  role = aws_iam_role.qldb_stream_role[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "kinesis:PutRecord",
          "kinesis:PutRecords",
          "kinesis:DescribeStream"
        ]
        Resource = aws_kinesis_stream.audit_kinesis[0].arn
      }
    ]
  })
}

# QLDB Stream for real-time audit processing (optional)
resource "aws_qldb_stream" "audit_stream" {
  count = var.enable_stream ? 1 : 0

  ledger_name        = aws_qldb_ledger.axiom_audit.name
  stream_name        = "${var.ledger_name}-stream"
  role_arn           = aws_iam_role.qldb_stream_role[0].arn
  inclusive_start_time = timestamp()

  kinesis_configuration {
    stream_arn = aws_kinesis_stream.audit_kinesis[0].arn
    aggregation_enabled = true
  }

  tags = {
    Name        = "Axiom Hive Audit Stream"
    Purpose     = "Real-time audit data processing"
    Project     = "Axiom Hive"
    Environment = var.environment
  }
}

# Kinesis Stream for audit data (if streaming enabled)
resource "aws_kinesis_stream" "audit_kinesis" {
  count = var.enable_stream ? 1 : 0

  name             = "${var.ledger_name}-kinesis"
  shard_count      = var.kinesis_shard_count
  retention_period = var.kinesis_retention_hours

  tags = {
    Name        = "Axiom Hive Audit Kinesis"
    Purpose     = "Audit data streaming"
    Project     = "Axiom Hive"
    Environment = var.environment
  }
}

# IAM Policy for QLDB access
resource "aws_iam_policy" "qldb_access" {
  name        = "axiom-hive-qldb-access"
  description = "IAM policy for Axiom Hive QLDB access"

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
        Resource = aws_qldb_ledger.axiom_audit.arn
      },
      {
        Effect = "Allow"
        Action = [
          "qldb:CreateLedger",
          "qldb:DeleteLedger",
          "qldb:DescribeLedger",
          "qldb:ListLedgers",
          "qldb:UpdateLedger"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:ResourceTag/Project" = "Axiom Hive"
          }
        }
      }
    ]
  })
}

# CloudWatch Alarms for QLDB monitoring
resource "aws_cloudwatch_metric_alarm" "qldb_read_capacity" {
  alarm_name          = "axiom-hive-qldb-read-capacity"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "ReadIOs"
  namespace           = "AWS/QLDB"
  period              = "300"
  statistic           = "Average"
  threshold           = var.read_capacity_threshold
  alarm_description   = "QLDB read capacity utilization is high"
  alarm_actions       = var.alarm_sns_topic_arn != "" ? [var.alarm_sns_topic_arn] : []

  dimensions = {
    LedgerName = aws_qldb_ledger.axiom_audit.name
  }
}

resource "aws_cloudwatch_metric_alarm" "qldb_write_capacity" {
  alarm_name          = "axiom-hive-qldb-write-capacity"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "WriteIOs"
  namespace           = "AWS/QLDB"
  period              = "300"
  statistic           = "Average"
  threshold           = var.write_capacity_threshold
  alarm_description   = "QLDB write capacity utilization is high"
  alarm_actions       = var.alarm_sns_topic_arn != "" ? [var.alarm_sns_topic_arn] : []

  dimensions = {
    LedgerName = aws_qldb_ledger.axiom_audit.name
  }
}

# Variables for this module
variable "ledger_name" {
  description = "Name of the QLDB ledger"
  type        = string
}

variable "permissions_mode" {
  description = "Permissions mode for the ledger"
  type        = string
  default     = "STANDARD"
  validation {
    condition     = contains(["ALLOW_ALL", "STANDARD"], var.permissions_mode)
    error_message = "Permissions mode must be ALLOW_ALL or STANDARD"
  }
}

variable "deletion_protection" {
  description = "Enable deletion protection for the ledger"
  type        = bool
  default     = true
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "enable_stream" {
  description = "Enable QLDB streaming to Kinesis"
  type        = bool
  default     = false
}

variable "kinesis_shard_count" {
  description = "Number of Kinesis shards"
  type        = number
  default     = 1
}

variable "kinesis_retention_hours" {
  description = "Kinesis data retention in hours"
  type        = number
  default     = 24
}

variable "read_capacity_threshold" {
  description = "Threshold for read capacity alarm"
  type        = number
  default     = 80
}

variable "write_capacity_threshold" {
  description = "Threshold for write capacity alarm"
  type        = number
  default     = 80
}

variable "alarm_sns_topic_arn" {
  description = "SNS topic ARN for alarms"
  type        = string
  default     = ""
}

# Outputs
output "ledger_name" {
  description = "Name of the created QLDB ledger"
  value       = aws_qldb_ledger.axiom_audit.name
}

output "ledger_arn" {
  description = "ARN of the created QLDB ledger"
  value       = aws_qldb_ledger.axiom_audit.arn
}

output "stream_arn" {
  description = "ARN of the QLDB stream (if enabled)"
  value       = var.enable_stream ? aws_qldb_stream.audit_stream[0].arn : null
}

output "kinesis_stream_arn" {
  description = "ARN of the Kinesis stream (if enabled)"
  value       = var.enable_stream ? aws_kinesis_stream.audit_kinesis[0].arn : null
}
