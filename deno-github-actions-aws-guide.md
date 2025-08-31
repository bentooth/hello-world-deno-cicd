# Deno 2 + GitHub Actions CI/CD to AWS: Complete Guide

## Overview
This guide walks you through setting up a complete CI/CD pipeline using GitHub Actions to deploy a Deno 2 application to AWS EC2. We'll create a simple Hello World API and automate its deployment.

## Prerequisites
- GitHub account
- AWS account with EC2 access
- Basic knowledge of Git and terminal commands
- AWS CLI installed locally (optional but recommended)

## Table of Contents
1. [Project Setup](#1-project-setup)
2. [Create Hello World Deno API](#2-create-hello-world-deno-api)
3. [AWS EC2 Setup](#3-aws-ec2-setup)
4. [GitHub Secrets Configuration](#4-github-secrets-configuration)
5. [GitHub Actions Workflow](#5-github-actions-workflow)
6. [Deployment Script](#6-deployment-script)
7. [Testing the Pipeline](#7-testing-the-pipeline)
8. [Monitoring and Troubleshooting](#8-monitoring-and-troubleshooting)

---

## 1. Project Setup

### Initialize your project
```bash
mkdir hello-world-deno-cicd
cd hello-world-deno-cicd
git init
```

### Create project structure
```
hello-world-deno-cicd/
├── .github/
│   └── workflows/
│       └── deploy.yml
├── src/
│   └── main.ts
├── scripts/
│   └── deploy.sh
├── deno.json
└── README.md
```

## 2. Create Hello World Deno API

### Create `deno.json` configuration
```json
{
  "tasks": {
    "dev": "deno run --watch --allow-net --allow-env src/main.ts",
    "start": "deno run --allow-net --allow-env src/main.ts",
    "test": "deno test --allow-net",
    "fmt": "deno fmt",
    "lint": "deno lint"
  },
  "imports": {
    "@std/assert": "jsr:@std/assert@^1.0.0"
  }
}
```

### Create `src/main.ts` - Hello World API
```typescript

const port = parseInt(Deno.env.get("PORT") || "8000");

const handler = (req: Request): Response => {
  const url = new URL(req.url);
  
  switch (url.pathname) {
    case "/":
      return new Response(JSON.stringify({ 
        message: "Hello World from Deno 2!",
        timestamp: new Date().toISOString(),
        version: "1.0.0"
      }), {
        headers: { "content-type": "application/json" },
      });
    
    case "/health":
      return new Response(JSON.stringify({ 
        status: "healthy",
        uptime: performance.now()
      }), {
        headers: { "content-type": "application/json" },
      });
    
    default:
      return new Response("Not Found", { status: 404 });
  }
};

console.log(`Server running on http://localhost:${port}/`);
Deno.serve({ port }, handler);
```

### Create `src/main.test.ts` - Basic tests
```typescript
import { assertEquals } from "@std/assert";

Deno.test("API Health Check", async () => {
  // Start server for testing
  const ac = new AbortController();
  const server = Deno.serve(
    { port: 8000, signal: ac.signal, onListen: () => {} },
    (req: Request) => {
      const url = new URL(req.url);
      if (url.pathname === "/health") {
        return new Response(JSON.stringify({ 
          status: "healthy",
          uptime: performance.now()
        }), {
          headers: { "content-type": "application/json" },
        });
      }
      return new Response("Not Found", { status: 404 });
    }
  );
  
  // Give server time to start
  await new Promise(resolve => setTimeout(resolve, 100));
  
  // Test the endpoint
  const response = await fetch("http://localhost:8000/health");
  assertEquals(response.status, 200);
  const data = await response.json();
  assertEquals(data.status, "healthy");
  
  // Cleanup
  ac.abort();
  await server.finished;
});
```

## 3. AWS EC2 Setup

### Step 1: Launch EC2 Instance
1. Log into AWS Console
2. Navigate to EC2 Dashboard
3. Click "Launch Instance"
4. Configure:
   - **Name**: `deno-api-server`
   - **OS**: Ubuntu Server 22.04 LTS
   - **Instance Type**: t2.micro (free tier eligible)
   - **Key Pair**: Create new or use existing (download `.pem` file)
   - **Security Group**: Create with rules:
     - SSH (port 22) from your IP
     - HTTP (port 80) from anywhere
     - Custom TCP (port 8000) from anywhere

### Step 2: Connect to EC2 Instance
```bash
# Set correct permissions for key file
chmod 400 your-key.pem

# Connect via SSH
ssh -i your-key.pem ubuntu@your-ec2-public-ip
```

### Step 3: Install Deno on EC2
```bash
# On the EC2 instance

# First, install unzip (required for Deno installation)
sudo apt update
sudo apt install unzip -y

# Install Deno
curl -fsSL https://deno.land/install.sh | sh

# Add to PATH (make sure these are on separate lines)
echo 'export DENO_INSTALL="/home/ubuntu/.deno"' >> ~/.bashrc
echo 'export PATH="$DENO_INSTALL/bin:$PATH"' >> ~/.bashrc

# Reload bashrc
source ~/.bashrc

# Verify installation
deno --version
```

### Step 4: Install PM2 for Process Management
```bash
# Install Node.js and npm first
curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
sudo apt-get install -y nodejs

# Install PM2 globally
sudo npm install -g pm2

# Setup PM2 to start on boot
pm2 startup systemd
# Follow the command it outputs
```

### Step 5: Create Application Directory
```bash
# On EC2 instance
mkdir -p /home/ubuntu/app
cd /home/ubuntu/app
```

## 4. GitHub Secrets Configuration

### Required Secrets
Navigate to your GitHub repository → Settings → Secrets and variables → Actions

Add these secrets:
1. **`EC2_HOST`**: Your EC2 public IP or domain
2. **`EC2_USERNAME`**: `ubuntu` (for Ubuntu instances)
3. **`EC2_SSH_KEY`**: Content of your `.pem` file (entire content)
4. **`EC2_TARGET_DIR`**: `/home/ubuntu/app`

### How to add SSH key secret:
```bash
# Copy your key content
cat your-key.pem | pbcopy  # macOS
# or
cat your-key.pem | xclip   # Linux
```
Then paste into GitHub secret value field.

## 5. GitHub Actions Workflow

### Create `.github/workflows/deploy.yml`
```yaml
name: Deploy to AWS EC2

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  test:
    runs-on: ubuntu-latest
    
    steps:
    - uses: actions/checkout@v4
    
    - name: Setup Deno
      uses: denoland/setup-deno@v1
      with:
        deno-version: v2.x
    
    - name: Verify formatting
      run: deno fmt --check
    
    - name: Run linter
      run: deno lint
    
    - name: Run tests
      run: deno test --allow-net
    
    - name: Type check
      run: deno check src/main.ts

  deploy:
    needs: test
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main' && github.event_name == 'push'
    
    steps:
    - uses: actions/checkout@v4
    
    - name: Deploy to EC2
      env:
        HOST: ${{ secrets.EC2_HOST }}
        USERNAME: ${{ secrets.EC2_USERNAME }}
        KEY: ${{ secrets.EC2_SSH_KEY }}
        TARGET: ${{ secrets.EC2_TARGET_DIR }}
      run: |
        # Setup SSH
        echo "$KEY" > deploy_key
        chmod 600 deploy_key
        
        # Add host to known hosts
        ssh-keyscan -H $HOST >> ~/.ssh/known_hosts
        
        # Create deployment directory if it doesn't exist
        ssh -i deploy_key $USERNAME@$HOST "mkdir -p $TARGET"
        
        # Copy files to server
        scp -i deploy_key -r ./src ./deno.json ./scripts $USERNAME@$HOST:$TARGET/
        
        # Run deployment script on server
        ssh -i deploy_key $USERNAME@$HOST "cd $TARGET && bash scripts/deploy.sh"
        
        # Cleanup
        rm -f deploy_key
    
    - name: Health Check
      run: |
        sleep 10
        curl -f http://${{ secrets.EC2_HOST }}:8000/health || exit 1
        echo "Health check passed!"
```

## 6. Deployment Script

### Create `scripts/deploy.sh`
```bash
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
```

## 7. Testing the Pipeline

### Local Testing First
```bash
# Run locally
deno task dev

# Test endpoints
curl http://localhost:8000/
curl http://localhost:8000/health
```

### Trigger GitHub Actions
```bash
# Add all files
git add .

# Commit
git commit -m "Initial Deno API with CI/CD pipeline"

# Add remote (replace with your repo URL)
git remote add origin https://github.com/yourusername/hello-world-deno-cicd.git

# Push to trigger deployment
git push -u origin main
```

### Monitor Deployment
1. Go to GitHub repository → Actions tab
2. Watch the workflow execution
3. Check each step for success/failure

### Verify Deployment
```bash
# Test deployed API
curl http://your-ec2-ip:8000/
curl http://your-ec2-ip:8000/health

# SSH to server and check logs
ssh -i your-key.pem ubuntu@your-ec2-ip
pm2 logs deno-api
pm2 status
```

## 8. Monitoring and Troubleshooting

### Common Issues and Solutions

#### 1. SSH Connection Failed
```bash
# Check security group allows SSH from GitHub Actions
# Add 0.0.0.0/0 for port 22 temporarily during setup
```

#### 2. Deno Command Not Found
```bash
# On EC2, ensure Deno is in PATH
echo $PATH
which deno
# Reinstall if necessary
```

#### 3. Port Already in Use
```bash
# Find and kill process using port 8000
sudo lsof -i :8000
sudo kill -9 <PID>
```

#### 4. PM2 Issues
```bash
# Restart PM2
pm2 kill
pm2 start ecosystem.config.js

# Check logs
pm2 logs --lines 100
```

### Monitoring Commands
```bash
# On EC2 instance

# View application logs
pm2 logs deno-api --lines 50

# Monitor in real-time
pm2 monit

# Check application status
pm2 status

# View system resources
pm2 info deno-api

# Restart application
pm2 restart deno-api

# View error logs
pm2 logs deno-api --err
```

### Setting Up Nginx (Optional but Recommended)

```bash
# Install Nginx
sudo apt update
sudo apt install nginx -y

# Configure reverse proxy
sudo nano /etc/nginx/sites-available/deno-api

# Add configuration:
server {
    listen 80;
    server_name your-domain.com;  # or EC2 public IP

    location / {
        proxy_pass http://localhost:8000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}

# Enable site
sudo ln -s /etc/nginx/sites-available/deno-api /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl restart nginx
```

## Advanced Topics

### Environment Variables
Create `.env` file (don't commit to git):
```env
PORT=8000
NODE_ENV=production
API_KEY=your-secret-key
```

Update deployment to use env file:
```bash
# In deploy.sh
if [ -f .env ]; then
  export $(cat .env | xargs)
fi
```

### Database Connection
For PostgreSQL:
```typescript
import { Client } from "https://deno.land/x/postgres/mod.ts";

const client = new Client({
  user: Deno.env.get("DB_USER"),
  database: Deno.env.get("DB_NAME"),
  hostname: Deno.env.get("DB_HOST"),
  password: Deno.env.get("DB_PASSWORD"),
  port: 5432,
});
```

### Rollback Strategy
```yaml
# Add to GitHub Actions workflow
- name: Create rollback point
  run: |
    ssh -i deploy_key $USERNAME@$HOST "cd $TARGET && tar -czf backup-$(date +%Y%m%d-%H%M%S).tar.gz src deno.json"
```

### Security Best Practices
1. **Use IAM roles** instead of hardcoding AWS credentials
2. **Enable CloudWatch** logging for monitoring
3. **Set up SSL/TLS** with Let's Encrypt
4. **Implement rate limiting** in your API
5. **Regular security updates**: `sudo apt update && sudo apt upgrade`
6. **Use AWS Secrets Manager** for sensitive data

## Conclusion
You now have a complete CI/CD pipeline that:
- ✅ Runs tests automatically on every push
- ✅ Deploys to AWS EC2 on main branch updates
- ✅ Uses PM2 for process management
- ✅ Includes health checks
- ✅ Provides monitoring capabilities

### Next Steps
1. Add custom domain with Route 53
2. Implement SSL with Certbot
3. Set up CloudWatch monitoring
4. Add staging environment
5. Implement blue-green deployments
6. Add database migrations to pipeline

### Resources
- [Deno Documentation](https://deno.land/manual)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [AWS EC2 Documentation](https://docs.aws.amazon.com/ec2/)
- [PM2 Documentation](https://pm2.keymetrics.io/docs/)

---

*Last Updated: 2025*