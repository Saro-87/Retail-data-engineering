terraform {
  backend "s3" {
    bucket       = "retail-data-engineering-saravanan-terraform-state"
    key          = "retail-data-engineering/dev/terraform.tfstate"
    region       = "ap-south-1"
    use_lockfile = true
    encrypt      = true
  }
}