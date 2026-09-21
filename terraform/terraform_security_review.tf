# Secure Terraform review example.
# This version keeps the same coverage areas while removing the risky patterns that would fail review.

resource "aws_s3_bucket" "review_bucket" {
  bucket        = "terraform-review-bucket-demo-1234"
  force_destroy = false
}

resource "aws_s3_bucket_public_access_block" "review_bucket_block" {
  bucket = aws_s3_bucket.review_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_iam_role" "ops_admin" {
  name = "ops-admin-review-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "ops_admin_policy" {
  name = "review-data-readonly"
  role = aws_iam_role.ops_admin.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = ["s3:GetObject", "s3:ListBucket"]
      Resource = [
        aws_s3_bucket.review_bucket.arn,
        "${aws_s3_bucket.review_bucket.arn}/*"
      ]
    }]
  })
}

variable "review_db_username" {
  description = "Database admin username for the review database"
  type        = string
  default     = "review_admin"
}

resource "random_password" "review_db_password" {
  length           = 24
  special          = true
  override_special = "!@#%&*()-_=+[]{}:<>?"
}

resource "aws_secretsmanager_secret" "review_db_secret" {
  name = "review-db/credentials"
}

resource "aws_secretsmanager_secret_version" "review_db_secret_version" {
  secret_id = aws_secretsmanager_secret.review_db_secret.id
  secret_string = jsonencode({
    username = var.review_db_username
    password = random_password.review_db_password.result
  })
}

resource "aws_db_instance" "review_db" {
  identifier                = "review-db-safe"
  engine                    = "postgres"
  instance_class            = "db.t3.micro"
  allocated_storage         = 20
  username                  = jsondecode(aws_secretsmanager_secret_version.review_db_secret_version.secret_string).username
  password                  = jsondecode(aws_secretsmanager_secret_version.review_db_secret_version.secret_string).password
  publicly_accessible       = false
  skip_final_snapshot       = false
  storage_encrypted         = true
  backup_retention_period   = 7
  deletion_protection       = true
  multi_az                  = true
  copy_tags_to_snapshot     = true
  final_snapshot_identifier = "review-db-safe-final"
}

resource "aws_s3_bucket" "cloudtrail_logs" {
  bucket        = "review-cloudtrail-logs-12345"
  force_destroy = false
}

resource "aws_s3_bucket_public_access_block" "cloudtrail_logs_block" {
  bucket = aws_s3_bucket.cloudtrail_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "cloudtrail_logs_versioning" {
  bucket = aws_s3_bucket.cloudtrail_logs.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "cloudtrail_logs_encryption" {
  bucket = aws_s3_bucket.cloudtrail_logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_policy" "cloudtrail_logs_policy" {
  bucket = aws_s3_bucket.cloudtrail_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "AWSCloudTrailWrite"
      Effect = "Allow"
      Principal = {
        Service = "cloudtrail.amazonaws.com"
      }
      Action   = "s3:PutObject"
      Resource = "${aws_s3_bucket.cloudtrail_logs.arn}/AWSLogs/${data.aws_caller_identity.current.account_id}/*"
      Condition = {
        StringEquals = {
          "s3:x-amz-acl" = "bucket-owner-full-control"
        }
      }
      }, {
      Sid    = "AWSCloudTrailAclCheck"
      Effect = "Allow"
      Principal = {
        Service = "cloudtrail.amazonaws.com"
      }
      Action   = "s3:GetBucketAcl"
      Resource = aws_s3_bucket.cloudtrail_logs.arn
    }]
  })
}

data "aws_caller_identity" "current" {}

resource "aws_cloudtrail" "global_trail" {
  name                          = "review-cloudtrail"
  s3_bucket_name                = aws_s3_bucket.cloudtrail_logs.id
  include_global_service_events = true
  is_multi_region_trail         = true
  enable_logging                = true
}

resource "aws_security_group" "legacy_web" {
  name = "legacy-web-review"

  ingress {
    description = "Allow HTTPS from the trusted admin network only"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["203.0.113.50/32"]
  }

  egress {
    description = "Allow HTTPS and HTTP outbound for required services"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow HTTPS outbound for required services"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_s3_bucket_versioning" "review_bucket_versioning" {
  bucket = aws_s3_bucket.review_bucket.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "review_bucket_lifecycle" {
  bucket = aws_s3_bucket.review_bucket.id

  rule {
    id     = "review-bucket-expire-old-objects"
    status = "Enabled"

    filter {
      prefix = "archive/"
    }

    expiration {
      days = 30
    }
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "review_bucket_encryption" {
  bucket = aws_s3_bucket.review_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}
