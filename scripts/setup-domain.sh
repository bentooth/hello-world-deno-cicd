#!/bin/bash

# Usage: ./setup-domain.sh your-domain.com

if [ -z "$1" ]; then
    echo "Usage: $0 your-domain.com"
    exit 1
fi

DOMAIN=$1
echo "Setting up domain: $DOMAIN"

# Create Nginx configuration
cat > /tmp/nginx-site.conf << EOF
server {
    listen 80;
    server_name $DOMAIN www.$DOMAIN;

    location / {
        proxy_pass http://localhost:8000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

# Copy config to sites-available
sudo cp /tmp/nginx-site.conf /etc/nginx/sites-available/$DOMAIN

# Enable the site
sudo ln -sf /etc/nginx/sites-available/$DOMAIN /etc/nginx/sites-enabled/

# Remove default site if it exists
sudo rm -f /etc/nginx/sites-enabled/default

# Test Nginx configuration
sudo nginx -t

# Reload Nginx
sudo systemctl reload nginx

echo "Nginx configured for $DOMAIN"

# Install Certbot for SSL
echo "Installing Certbot for SSL..."
sudo apt update
sudo apt install -y certbot python3-certbot-nginx

# Get SSL certificate
echo "Getting SSL certificate..."
sudo certbot --nginx -d $DOMAIN -d www.$DOMAIN --non-interactive --agree-tos --email admin@$DOMAIN --redirect

echo "Domain setup complete!"
echo "Your site should now be available at:"
echo "  https://$DOMAIN"
echo "  https://www.$DOMAIN"