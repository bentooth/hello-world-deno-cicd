#!/bin/bash

# Exit on error
set -e

echo "Starting deployment..."

# Set up PATH for Deno
export DENO_INSTALL="/home/ubuntu/.deno"
export PATH="$DENO_INSTALL/bin:$PATH"

# Check if Deno is installed
if [ ! -f "/home/ubuntu/.deno/bin/deno" ]; then
  echo "Error: Deno is not installed at /home/ubuntu/.deno/bin/deno"
  echo "Please install Deno on the server first"
  exit 1
fi

echo "Deno found at: /home/ubuntu/.deno/bin/deno"
/home/ubuntu/.deno/bin/deno --version

# Navigate to app directory
cd /home/ubuntu/app

# Pull latest code (if using git on server)
# git pull origin main

# Install/Update dependencies
/home/ubuntu/.deno/bin/deno cache src/main.ts

# Create PM2 ecosystem file if it doesn't exist
if [ ! -f ecosystem.config.js ]; then
  cat > ecosystem.config.js << EOF
module.exports = {
  apps: [{
    name: 'deno-api',
    script: '/home/ubuntu/.deno/bin/deno',
    args: 'run --allow-net --allow-env --allow-sys src/main.ts',
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