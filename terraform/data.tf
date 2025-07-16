# Remote state do S3
data "terraform_remote_state" "s3" {
  backend = "s3"
  config = {
    bucket = "example-aws-terraform-terraform-state"
    key    = "example-aws-app-infra/terraform.tfstate"
    region = "us-east-1"
  }
}

# Remote state da API
data "terraform_remote_state" "api_rest" {
  backend = "s3"
  config = {
    bucket = "example-aws-terraform-terraform-state"
    key    = "example-aws-api/terraform.tfstate"
    region = "us-east-1"
  }
}

# Referência ao bucket S3 existente
data "aws_s3_bucket" "website" {
  bucket = data.terraform_remote_state.s3.outputs.bucket_name
}