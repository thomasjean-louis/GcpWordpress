terraform {
  backend "gcs" {
    bucket = "wordpress-terraform-bucket-${var.env}"
    prefix = "terraform/state"
  }
}