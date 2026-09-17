# Secure Terraform example for learning and review.

terraform {
  required_version = ">= 1.3.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

resource "aws_security_group" "open_ssh" {
  name = "secure-bastion-sg"

  ingress {
    description = "SSH from the internal admin network only"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8"]
  }

  egress {
    description = "Allow HTTPS and HTTP outbound for updates"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow HTTPS outbound for updates"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_s3_bucket" "example_data" {
  bucket        = "example-data-bucket-12345"
  force_destroy = false
}

resource "aws_s3_bucket_public_access_block" "example_data_block" {
  bucket = aws_s3_bucket.example_data.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "example_data_versioning" {
  bucket = aws_s3_bucket.example_data.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "example_data_encryption" {
  bucket = aws_s3_bucket.example_data.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_iam_policy" "read_only_bucket" {
  name = "s3-read-only-example-data"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = ["s3:GetObject", "s3:ListBucket"]
      Resource = [
        "arn:aws:s3:::example-data-bucket-12345",
        "arn:aws:s3:::example-data-bucket-12345/*"
      ]
    }]
  })
}

resource "aws_instance" "app" {
  ami                         = "ami-0c02fb55956c7d316"
  instance_type               = "t3.small"
  associate_public_ip_address = false
  vpc_security_group_ids      = [aws_security_group.open_ssh.id]

  metadata_options {
    http_tokens = "required"
  }

  user_data = <<-EOF
    #!/bin/bash
    echo "setup" > /tmp/setup.txt
  EOF
}

resource "aws_db_instance" "example_db" {
  identifier              = "example-db"
  engine                  = "mysql"
  instance_class          = "db.t3.small"
  allocated_storage       = 10
  username                = "admin"
  password                = "P@ssw0rd!Example2026"
  publicly_accessible     = false
  skip_final_snapshot     = false
  storage_encrypted       = true
  backup_retention_period = 7
  deletion_protection     = true
}
