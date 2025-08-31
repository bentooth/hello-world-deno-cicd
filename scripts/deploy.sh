#!/bin/bash

# Exit on error
set -e

echo "Starting deployment..."

# Navigate to app directory
cd /home/ubuntu/app

# Pull latest code (if using git on server)
# git pull origin main

# Install/Update dependencies
deno cache src/main.ts

# Create PM2 ecosystem file if it doesn't exist
if [ ! -f ecosystem.config.js ]; then
  cat > ecosystem.config.js << EOF
module.exports = {
  apps: [{
    name: 'deno-api',
    script: 'deno',
    args: 'run --allow-net --allow-env src/main.ts',
    env: {
      PORT: 8000
    },
    interpreter: 'none',
    cwd: '/home/ubuntu/app'
  }]
}
EOF
fi

# Stop existing application (if running)
pm2 stop deno-api || true
pm2 delete deno-api || true

# Start application with PM2
pm2 start ecosystem.config.js

# Save PM2 configuration
pm2 save

# Show status
pm2 status

echo "Deployment completed successfully!"