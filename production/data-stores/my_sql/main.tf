provider "aws" {
  region = "us-east-2"
}

resource "aws_db_instance" "db02" {
  identifier_prefix   = "terraform-up-and-running"
  engine              = "mysql"
  allocated_storage   = 10
  instance_class      = "db.t3.micro"
  skip_final_snapshot = true
  db_name             = "db02_database"

  # How should we set the username and password?
  username = var.db_username
  password = var.db_password
}

terraform {
  backend "s3" {
    # Replace this with your bucket name!
    bucket         = "terraform-storage01"
    key            = "production/data-stores/mysql/terraform.tfstate"
    region         = "us-east-2"

    # Replace this with your DynamoDB table name!
    dynamodb_table = "terraform-up-and-running-locks"
    encrypt        = true
  }
}