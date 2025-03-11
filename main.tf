provider "google" {
  credentials = jsondecode(var.gcp_credentials) # GCP credentials from GitHub secrets
  project     = var.gcp_project_id        # GCP project ID for dev/prod
  region      = var.region       
       
}

terraform {
  backend "gcs" {}
}

terraform {
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5"
    }
  }
}



provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

resource "google_compute_instance" "wordpress_dev" {
  count        = var.env == "dev" ? 1 : 0  # Only create in dev environment
  name         = "wordpress-dev"
  machine_type = "e2-micro"  
  zone         = var.region
  tags         = ["wordpress", "http-server", "https-server"]
  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11-bullseye-v20220125"  # A base OS image
    }
  }

  metadata_startup_script = <<-EOT
    #! /bin/bash
    # Install LAMP stack and WordPress
    apt-get update
    apt-get install -y apache2 mysql-server php php-mysql libapache2-mod-php wget curl
    wget https://wordpress.org/latest.tar.gz
    tar -xzvf latest.tar.gz
    mv wordpress/* /var/www/html/
    chown -R www-data:www-data /var/www/html
    systemctl enable apache2
    systemctl start apache2

    # Install Certbot for Let's Encrypt
    apt-get install -y certbot python3-certbot-apache
    certbot --apache --non-interactive --agree-tos -m ${var.email} -d ${var.domain}

    # Restart Apache to apply HTTPS
    systemctl restart apache2
  EOT

  network_interface {
    network = "default"
    access_config {
      # Allocate a public IP
    }
  }

  service_account {
    scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  }
}



# Cloudflare configuration for HTTPS
resource "cloudflare_dns_record" "wordpress_dns_cf" {
  count   = var.env == "dev" ? 1 : 0  # Create DNS records in Cloudflare for dev only
  zone_id = var.cloudflare_zone_id
  name    = var.domain
  content   = google_compute_instance.wordpress_dev[0].network_interface[0].access_config[0].nat_ip
  type    = "A"
  ttl     = 300
  proxied = true
}