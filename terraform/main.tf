# Intentionally insecure example for learning only.
# This exposes SSH on the public internet and attaches a public IP.

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

resource "aws_security_group" "unsafe" {
  name        = "unsafe-public-ssh"
  description = "Deliberately insecure SG"

  ingress {
    description = "Allow SSH from anywhere"
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

resource "aws_instance" "web" {
  ami                         = "ami-0c02fb55956c7d316"
  instance_type               = "t3.micro"
  associate_public_ip_address = true
  security_groups             = [aws_security_group.unsafe.name]

  tags = {
    Name = "unsafe-demo-instance"
  }
}
