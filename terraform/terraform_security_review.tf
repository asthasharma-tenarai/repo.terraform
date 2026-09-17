# Secure Terraform review example.
# This version keeps the same coverage areas while removing the risky patterns that would fail review.

resource "aws_s3_bucket" "review_bucket" {
  bucket        = "terraform-review-bucket-demo-1234"
  force_destroy = false
}

resource "aws_s3_bucket_acl" "review_bucket_acl" {
  bucket = aws_s3_bucket.review_bucket.id
  acl    = "private"
}

resource "aws_s3_bucket_public_access_block" "review_bucket_block" {
  bucket = aws_s3_bucket.review_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_iam_user" "ops_admin" {
  name = "ops-admin-review"
}

resource "aws_iam_user_policy" "ops_admin_policy" {
  name = "review-data-readonly"
  user = aws_iam_user.ops_admin.name

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

resource "aws_db_instance" "review_db" {
  identifier              = "review-db-safe"
  engine                  = "postgres"
  instance_class          = "db.t3.small"
  allocated_storage       = 10
  username                = "adminuser"
  password                = "P@ssw0rd!Review2026"
  publicly_accessible     = false
  skip_final_snapshot     = false
  storage_encrypted       = true
  backup_retention_period = 7
  deletion_protection     = true
}

resource "aws_cloudtrail" "global_trail" {
  name                          = "review-cloudtrail"
  s3_bucket_name                = aws_s3_bucket.review_bucket.id
  include_global_service_events = true
  is_multi_region_trail         = true
  enable_logging                = true
}

resource "aws_security_group" "legacy_web" {
  name = "legacy-web-review"

  ingress {
    description = "Allow HTTPS from internal management CIDR only"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8"]
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

resource "aws_s3_bucket_server_side_encryption_configuration" "review_bucket_encryption" {
  bucket = aws_s3_bucket.review_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}
