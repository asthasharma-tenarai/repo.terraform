# Different reviewer test cases to avoid overlapping with the existing Terraform examples.

resource "aws_s3_bucket" "archive_bucket" {
  bucket        = "reviewer-action-archive-demo-4201"
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "archive_bucket_block" {
  bucket = aws_s3_bucket.archive_bucket.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "archive_bucket_policy" {
  bucket = aws_s3_bucket.archive_bucket.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "PublicReadWrite"
      Effect = "Allow"
      Principal = "*"
      Action = ["s3:GetObject", "s3:PutObject"]
      Resource = [
        "${aws_s3_bucket.archive_bucket.arn}/*"
      ]
    }]
  })
}

resource "aws_iam_role" "app_runtime_admin" {
  name = "reviewer-action-app-runtime-admin"

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

resource "aws_iam_role_policy_attachment" "app_runtime_admin_attach" {
  role       = aws_iam_role.app_runtime_admin.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

resource "aws_iam_access_key" "app_runtime_key" {
  user    = "ops-admin-review"
  status  = "Active"
}

resource "aws_dynamodb_table" "sessions" {
  name           = "reviewer-action-sessions"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "session_id"
  range_key      = "created_at"
  deletion_protection_enabled = false

  attribute {
    name = "session_id"
    type = "S"
  }

  attribute {
    name = "created_at"
    type = "S"
  }

  point_in_time_recovery {
    enabled = false
  }

  server_side_encryption {
    enabled     = false
    kms_key_arn = null
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
    enforce_https       = false
    tls_security_policy = "Policy-Min-TLS-1-0-2019-07"
  }

  access_policies = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = "*"
      Action = "es:*"
      Resource = "*"
    }]
  })
}
