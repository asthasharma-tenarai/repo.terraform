# Intentionally insecure example for learning only.

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
  ingress {
    from_port   = 22
    to_port     = 22
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

resource "aws_s3_bucket" "example_data" {
  bucket        = "example-data-bucket-12345"
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "example_data_block" {
  bucket = aws_s3_bucket.example_data.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_iam_policy" "wildcard_admin" {
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

resource "aws_instance" "bad" {
  ami                         = "ami-0c02fb55956c7d316"
  instance_type               = "t3.small"
  associate_public_ip_address = false
  vpc_security_group_ids      = [aws_security_group.open_ssh.id]
  user_data                   = <<-EOF
    #!/bin/bash
    echo "setup" > /tmp/setup.txt
  EOF
}

resource "aws_db_instance" "example_db" {
  identifier             = "example-db"
  engine                 = "mysql"
  instance_class         = "db.t3.small"
  allocated_storage      = 10
  username               = "admin"
  password               = "Password123!"
  publicly_accessible    = false
  skip_final_snapshot    = false
  storage_encrypted      = true
  backup_retention_period = 7
  deletion_protection    = true
}
