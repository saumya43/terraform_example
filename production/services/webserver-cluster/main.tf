provider "aws" {
  region = "us-east-2"
  #tags to apply to all resources by default
  default_tags {
    tags = {
      Owner     = "team-foo"
      ManagedBy = "Terraform"
    }
  }
}
terraform {
  backend "s3" {
    # Replace this with your bucket name!
    bucket         = "terraform-storage01"
    key            = "production/services/webserver-cluster/terraform.tfstate"
    region         = "us-east-2"
    # Replace this with your DynamoDB table name!
    dynamodb_table = "terraform-up-and-running-locks"
    encrypt        = true
  }
} 

module "webserver_cluster" {
  source = "../../../modules/services/webserver-cluster"
  cluster_name           = "webservers-production"
  db_remote_state_bucket = "terraform-storage01"
  db_remote_state_key    = "production/data-stores/mysql/terraform.tfstate"
  instance_type = "t2.micro"
  min_size      = 2
  max_size      = 2
  enable_autoscaling   = false
  
  custom_tags = {
    Owner     = "team-foo"
    ManagedBy = "terraform"
}
}
