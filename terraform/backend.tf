# Terraform remote backend configuration
# The platform team should configure backend variables in Jenkins using backend-config files
# or CLI arguments during 'terraform init'.

terraform {
  backend "s3" {
    bucket  = "platform-terraform-state-bucket"
    key     = "environments/env-name/terraform.tfstate"
    region  = "us-east-1"
    encrypt = true
  }
}
