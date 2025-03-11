variable "gcp_credentials" {
  description = "The GCP credentials file for the environment"
  type        = string
}

variable "cloudflare_api_token" {
  description = "Cloudflare API token"
  type        = string
}

variable "env" {
  description = "Target env (dev or prod)"
  type        = string
}

variable "gcp_project_id" {
  description = "The GCP project ID for the environment"
  type        = string
}

variable "region" {
  description = "GCP Region"
  type        = string
  default     = "europe-west4"
}

variable "credentials_file" {
  description = "Path to GCP credentials file"
  type        = string
}

variable "domain" {
  description = "Domain name for the website"
  type        = string
}

variable "email" {
  description = "Email for Let's Encrypt SSL certificate"
  type        = string
}


variable "cloudflare_zone_id" {
  description = "The Cloudflare zone ID for the domain"
  type        = string
}