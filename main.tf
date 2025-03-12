provider "google" {
  credentials = var.gcp_credentials # GCP credentials from GitHub secrets
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
  zone         = var.zone
  tags         = ["wordpress", "http-server", "https-server"]
  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11-bullseye-v20250212"  # Base OS image
    }
  }
  
 
  metadata_startup_script = <<-EOT
     #! /bin/bash
    sudo apt update 

    # Install NGINX, MySQL et PHP
    sudo apt install -y nginx mariadb-server php-fpm php-mysql unzip wget certbot python3-certbot-nginx

    # Start and activate services
    sudo systemctl start nginx
    sudo systemctl enable nginx
    sudo systemctl start mysql
    sudo systemctl enable mysql
    sudo systemctl start php7.4-fpm
    sudo systemctl enable php7.4-fpm

    # Donwload and install WordPress
    wget https://wordpress.org/latest.tar.gz
    tar -xzf latest.tar.gz
    sudo mv wordpress/* /var/www/html/

    # Configure permissions
    sudo chown -R www-data:www-data /var/www/html
    sudo chmod -R 755 /var/www/html

    # Configure MySQL
    sudo mysql -e "CREATE DATABASE wordpress;"
    sudo mysql -e "CREATE USER 'wordpressuser'@'localhost' IDENTIFIED BY 'password';"
    sudo mysql -e "GRANT ALL PRIVILEGES ON wordpress.* TO 'wordpressuser'@'localhost';"
    sudo mysql -e "FLUSH PRIVILEGES;"

    # Configure WordPress
    sudo mv /var/www/html/wp-config-sample.php /var/www/html/wp-config.php
    sudo sed -i "s/database_name_here/wordpress/g" /var/www/html/wp-config.php
    sudo sed -i "s/username_here/wordpressuser/g" /var/www/html/wp-config.php
    sudo sed -i "s/password_here/password/g" /var/www/html/wp-config.php

    # Configure NGINX for WordPress
    cat <<EOF | sudo tee /etc/nginx/sites-available/wordpress
    server {
        listen 80;
        server_name ${var.domain};
        root /var/www/html;
        index index.php index.html index.htm;
        location / {
            try_files \$uri \$uri/ /index.php?\$args;
        }
        location ~ \.php$ {
            include snippets/fastcgi-php.conf;
            fastcgi_pass unix:/var/run/php/php7.4-fpm.sock;
            fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
            include fastcgi_params;
        }
    }
    EOF
    sudo ln -s /etc/nginx/sites-available/wordpress /etc/nginx/sites-enabled/
    sudo nginx -t
    sudo systemctl reload nginx

    # Install Certbot for Let's Encrypt (auto-create TXT record in Cloudflare)
    sudo certbot --nginx --non-interactive --agree-tos --email ${var.email} -d ${var.domain}

    # Restart NGINX to enable SSL
    sudo systemctl reload nginx
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
  ttl     = 1
}