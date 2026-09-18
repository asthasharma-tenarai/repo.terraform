# Secure reviewer test cases to ensure a clean Terraform review.

resource "aws_s3_bucket" "archive_bucket" {
  bucket        = "reviewer-action-archive-demo-4201"
  force_destroy = false
}

resource "aws_s3_bucket_public_access_block" "archive_bucket_block" {
  bucket = aws_s3_bucket.archive_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "archive_bucket_versioning" {
  bucket = aws_s3_bucket.archive_bucket.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "archive_bucket_lifecycle" {
  bucket = aws_s3_bucket.archive_bucket.id

  rule {
    id     = "archive-objects"
    status = "Enabled"

    filter {
      prefix = "archive/"
    }

    expiration {
      days = 30
    }
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "archive_bucket_encryption" {
  bucket = aws_s3_bucket.archive_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_iam_role" "app_runtime" {
  name = "reviewer-action-app-runtime"

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

resource "aws_iam_role_policy_attachment" "app_runtime_readonly_attach" {
  role       = aws_iam_role.app_runtime.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
}

resource "aws_dynamodb_table" "sessions" {
  name                        = "reviewer-action-sessions"
  billing_mode                = "PAY_PER_REQUEST"
  hash_key                    = "session_id"
  range_key                   = "created_at"
  deletion_protection_enabled = true

  attribute {
    name = "session_id"
    type = "S"
  }

  attribute {
    name = "created_at"
    type = "S"
  }

  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled = true
  }
}

resource "aws_elasticsearch_domain" "search_cluster" {
  domain_name = "reviewer-action-es"

  cluster_config {
    instance_type = "m3.medium.elasticsearch"
  }

  ebs_options {
    ebs_enabled = true
    volume_size = 10
  }

  domain_endpoint_options {
    enforce_https       = true
    tls_security_policy = "Policy-Min-TLS-1-2-2019-07"
  }

  access_policies = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "RestrictToTLS"
      Effect = "Allow"
      Principal = {
        AWS = "arn:aws:iam::123456789012:root"
      }
      Action   = ["es:ESHttpGet"]
      Resource = "arn:aws:es:us-east-1:123456789012:domain/reviewer-action-es/*"
      Condition = {
        Bool = {
          "aws:SecureTransport" = "true"
        }
      }
    }]
  })
}
