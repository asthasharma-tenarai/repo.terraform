# Secure Terraform example for learning and review.

terraform {
  required_version = ">= 1.3.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

variable "database_username" {
  description = "Database admin username for the RDS instance"
  type        = string
  default     = "admin"
}

resource "aws_security_group" "open_ssh" {
  name = "secure-bastion-sg"

  ingress {
    description = "SSH from the trusted admin IP only"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["203.0.113.50/32"]
  }

  egress {
    description = "Allow outbound HTTPS to the approved update source only"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["203.0.113.50/32"]
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

resource "aws_launch_template" "app" {
  name_prefix   = "secure-app-"
  image_id      = "ami-0c02fb55956c7d316"
  instance_type = "t3.micro"

  network_interfaces {
    associate_public_ip_address = false
    security_groups             = [aws_security_group.open_ssh.id]
  }

  metadata_options {
    http_tokens = "required"
  }

  user_data = base64encode(<<-EOF
    #!/bin/bash
    echo "setup" > /tmp/setup.txt
  EOF
  )
}

resource "aws_autoscaling_group" "app" {
  name                = "secure-app-asg"
  desired_capacity    = 2
  min_size            = 1
  max_size            = 4
  health_check_type   = "ELB"
  vpc_zone_identifier = ["subnet-0123456789abcdef0"]

  launch_template {
    id      = aws_launch_template.app.id
    version = "$Latest"
  }
}

resource "random_password" "example_db_password" {
  length           = 24
  special          = true
  override_special = "!@#%&*()-_=+[]{}:<>?"
}

resource "aws_secretsmanager_secret" "example_db_secret" {
  name = "example-db/credentials"
}

resource "aws_secretsmanager_secret_version" "example_db_secret_version" {
  secret_id = aws_secretsmanager_secret.example_db_secret.id
  secret_string = jsonencode({
    username = var.database_username
    password = random_password.example_db_password.result
  })
}

resource "aws_db_instance" "example_db" {
  identifier              = "example-db"
  engine                  = "mysql"
  instance_class          = "db.t3.micro"
  allocated_storage       = 50
  username                = jsondecode(aws_secretsmanager_secret_version.example_db_secret_version.secret_string).username
  password                = jsondecode(aws_secretsmanager_secret_version.example_db_secret_version.secret_string).password
  publicly_accessible     = false
  skip_final_snapshot     = false
  storage_encrypted       = true
  backup_retention_period = 7
  deletion_protection     = false
  multi_az                = true
}