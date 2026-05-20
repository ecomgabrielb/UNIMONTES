terraform {
  backend "s3" {
    bucket         = "resilient-web-server-tf-state-934199829903"
    key            = "terraform-students/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "resilient-web-server-tf-locks"
  }
}
