# Intentionally insecure Terraform review example.
# This is intentionally different from main.tf and covers additional risk patterns.

resource "aws_s3_bucket" "review_bucket" {
  bucket        = "terraform-review-bucket-demo-1234"
  force_destroy = true
}

resource "aws_s3_bucket_acl" "review_bucket_acl" {
  bucket = aws_s3_bucket.review_bucket.id
  acl    = "private"
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
  identifier             = "review-db-unsafe"
  engine                 = "postgres"
  instance_class         = "db.t3.small"
  allocated_storage      = 10
  username               = "adminuser"
  password               = "SuperSecretPass123!"
  publicly_accessible    = false
  skip_final_snapshot    = false
  storage_encrypted      = true
  backup_retention_period = 7
  deletion_protection    = true
}

resource "aws_cloudtrail" "global_trail" {
  name                          = "review-cloudtrail"
  s3_bucket_name               = aws_s3_bucket.review_bucket.id
  include_global_service_events = true
  is_multi_region_trail        = true
  enable_logging               = true
}

resource "aws_iam_access_key" "review_key" {
  user   = aws_iam_user.ops_admin.name
  status = "Inactive"
}

resource "aws_security_group" "legacy_web" {
  name = "legacy-web-review"

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["203.0.113.50/32"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_s3_bucket_versioning" "review_bucket_versioning" {
  bucket = aws_s3_bucket.review_bucket.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_iam_policy_attachment" "review_attach" {
  name       = "review-attachment"
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
  groups     = []
  users      = [aws_iam_user.ops_admin.name]
  roles      = []
}
