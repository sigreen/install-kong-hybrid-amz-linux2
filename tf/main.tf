terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.27"
    }
  }

  required_version = ">= 0.14.9"
}

provider "aws" {
  profile = "default"
  region  = "us-west-2"
}

data "aws_availability_zones" "available" {}


module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "2.77.0"

  name                 = "simongreen-vpc"
  cidr                 = "10.0.0.0/16"
  azs                  = data.aws_availability_zones.available.names
  public_subnets       = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]
  enable_dns_hostnames = true
  enable_dns_support   = true
}

resource "aws_db_subnet_group" "simongreen-sng" {
  name       = "simongreen-sng"
  subnet_ids = module.vpc.public_subnets

  tags = {
    Name = "Simon Green RDS"
  }
}

resource "aws_security_group" "simongreen-rds-sg" {
  name   = "simongreen-rds-sg"
  vpc_id = module.vpc.vpc_id

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "simongreen-rds-sg"
  }
}

resource "aws_db_parameter_group" "simongreen-pg" {
  name   = "simongreen-pg"
  family = "postgres13"

  parameter {
    name  = "log_connections"
    value = "1"
  }
}

resource "aws_db_instance" "simongreen-db-postgres" {
  identifier             = "simongreen-db-postgres"
  instance_class         = "db.t3.micro"
  allocated_storage      = 20
  engine                 = "postgres"
  engine_version         = "13.4"
  username               = "postgres"
  password               = var.db_password
  db_subnet_group_name   = aws_db_subnet_group.simongreen-sng.name
  vpc_security_group_ids = [aws_security_group.simongreen-rds-sg.id]
  parameter_group_name   = aws_db_parameter_group.simongreen-pg.name
  publicly_accessible    = true
  skip_final_snapshot    = true
}

resource "aws_instance" "app_server_cp" {
  ami                         = "${data.aws_ami.amazon-linux-2.id}"
  associate_public_ip_address = true
  instance_type               = "t2.micro"
  key_name                    = "simon-green-uswest2"

  tags = {
    Name = "SimonGreen_CP_AmznLinux2"
  }
}

resource "aws_instance" "app_server_dp" {
  ami                         = "${data.aws_ami.amazon-linux-2.id}"
  associate_public_ip_address = true
  instance_type               = "t2.micro"
  key_name                    = "simon-green-uswest2"

  tags = {
    Name = "SimonGreen_DP_AmznLinux2"
  }
}

output "arn_cp" {
  description = "ARN of the server"
  value = aws_instance.app_server_cp.arn

}

output "arn_dp" {
  description = "ARN of the server"
  value = aws_instance.app_server_dp.arn

}

output "server_name_cp" {
  description = "Name (id) of the server"
  value = aws_instance.app_server_cp.id
}

output "server_name_dp" {
  description = "Name (id) of the server"
  value = aws_instance.app_server_dp.id
}

output "public_ip_cp" {
  description = "Public IP of the server"
  value = aws_instance.app_server_cp.public_ip
}

output "public_ip_dp" {
  description = "Public IP of the server"
  value = aws_instance.app_server_dp.public_ip
}

data "aws_ami" "amazon-linux-2" {
 most_recent = true
 owners = ["amazon"]

 filter {
   name   = "owner-alias"
   values = ["amazon"]
 }


 filter {
   name   = "name"
   values = ["amzn2-ami-hvm*"]
 }
}

variable "db_password" {
  description = "RDS root user password"
  default = "Abcd1234"
  sensitive   = true
}