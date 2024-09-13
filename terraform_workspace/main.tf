#create kms keys to hold secrets to encrypt and decrypt user information
provider "aws" {
  region = "us-east-2"
}

data "aws_caller_identity" "self" {}

data "aws_iam_policy_document" "cmk_admin_policy" {
  statement {
    effect    = "Allow"
    resources = ["*"]
    actions   = ["kms:*"]
    principals {
      type        = "AWS"
      identifiers = [data.aws_caller_identity.self.arn]
    }
  }
}
resource "aws_kms_key" "cmk" {
  policy = data.aws_iam_policy_document.cmk_admin_policy.json
}

resource "aws_kms_alias" "cmk" {
  name          = "alias/kms-cmk-example"
  target_key_id = aws_kms_key.cmk.id
}

# resource "aws_instance" "example" {
#   ami           = "ami-0fb653ca2d3203ac1"
#   instance_type = "t2.micro"
# }

# terraform {
#   backend "s3" {
#     # Replace this with your bucket name!
#     bucket         = "terraform-storage01"
#     key            = "workspaces-example/terraform.tfstate"
#     region         = "us-east-2"

#     # Replace this with your DynamoDB table name!
#     dynamodb_table = "terraform-up-and-running-locks"
#     encrypt        = true
#   }
# }