provider "aws" {
  region = "us-east-2"
}

####create 3  i am user using count
# resource "aws_iam_user" "user_01" {
#     count = length(var.user_names)
#     name = var.user_names[count.index]
# }

####create 3 i am user using module with count
# using module to create user
# module "users" {
#   source = "../../../modules/landing-zone/iam-user"

#   count     = length(var.user_names)
#   user_name = var.user_names[count.index]
# }

resource "aws_iam_user" "example" {
  for_each = toset(var.user_names)
  name     = each.value
}

output "all_users" {
  value = aws_iam_user.example
}