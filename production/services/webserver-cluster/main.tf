provider "aws" {
  region = "us-east-2"
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
}
resource "aws_autoscaling_schedule" "scale_out_during_business_hours" {
  scheduled_action_name = "scale-out-during-business-hours"
  min_size              = 2
  max_size              = 10
  desired_capacity      = 10
  recurrence            = "0 9 * * *"

  autoscaling_group_name = module.webserver_cluster.asg_name
}

resource "aws_autoscaling_schedule" "scale_in_at_night" {
  scheduled_action_name = "scale-in-at-night"
  min_size              = 2
  max_size              = 10
  desired_capacity      = 2
  recurrence            = "0 17 * * *"

  autoscaling_group_name = module.webserver_cluster.asg_name
}