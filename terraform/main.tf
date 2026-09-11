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
    cidr_blocks = ["0.0.0.0/0"]
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

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_iam_policy" "wildcard_admin" {
  name = "wildcard-admin"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = "*"
      Resource = "*"
    }]
  })
}

resource "aws_instance" "bad" {
  ami                         = "ami-0c02fb55956c7d316"
  instance_type               = "t3.micro"
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.open_ssh.id]
  user_data                   = <<-EOF
    #!/bin/bash
    echo "setup" > /tmp/setup.txt
  EOF
}

resource "aws_db_instance" "example_db" {
  identifier             = "example-db"
  engine                 = "mysql"
  instance_class         = "db.t3.micro"
  allocated_storage      = 20
  username               = "admin"
  password               = "Password123!"
  publicly_accessible    = true
  skip_final_snapshot    = true
  storage_encrypted      = false
  backup_retention_period = 0
}
