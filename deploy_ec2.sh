#!/bin/bash
# ==============================================================================
# Setup script for NGINX Plus Artifact Demo on EC2 (Ubuntu 22.04 / Debian)
# Run with: sudo bash deploy_ec2.sh
# ==============================================================================
set -e

if [ "$EUID" -ne 0 ]; then
  echo "[-] Please run as root (e.g. sudo bash deploy_ec2.sh)"
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== [1/6] Checking Prerequisites ==="
if [ ! -f "$SCRIPT_DIR/license.crt" ] || [ ! -f "$SCRIPT_DIR/license.key" ]; then
    echo "[-] Error: license.crt or license.key not found in $SCRIPT_DIR!"
    exit 1
fi

apt-get update -y
apt-get install -y ca-certificates apt-transport-https lsb-release gnupg curl python3

echo "=== [2/6] Configuring NGINX Plus Repository ==="
mkdir -p /etc/ssl/nginx /etc/apt/apt.conf.d /etc/nginx
cp "$SCRIPT_DIR/license.crt" /etc/ssl/nginx/nginx-repo.crt
cp "$SCRIPT_DIR/license.key" /etc/ssl/nginx/nginx-repo.key
chmod 600 /etc/ssl/nginx/nginx-repo.key

if [ -f "$SCRIPT_DIR/license.jwt" ]; then
    cp "$SCRIPT_DIR/license.jwt" /etc/nginx/license.jwt
fi

curl -fsSL https://cs.nginx.com/static/keys/nginx_signing.key | gpg --dearmor --yes -o /etc/apt/trusted.gpg.d/nginx.gpg
printf "deb [signed-by=/etc/apt/trusted.gpg.d/nginx.gpg] https://pkgs.nginx.com/plus/ubuntu `lsb_release -cs` nginx-plus\n" > /etc/apt/sources.list.d/nginx-plus.list
printf "Acquire::https::pkgs.nginx.com::User-Agent \"nginx-install\";\nAcquire::https::pkgs.nginx.com::SslCert \"/etc/ssl/nginx/nginx-repo.crt\";\nAcquire::https::pkgs.nginx.com::SslKey \"/etc/ssl/nginx/nginx-repo.key\";\n" > /etc/apt/apt.conf.d/90nginx-plus

echo "=== [3/6] Installing NGINX Plus ==="
apt-get update -y
apt-get install -y nginx-plus

echo "=== [4/6] Setting Up Directories and Permissions ==="
mkdir -p /var/cache/nginx/artifacts /opt/nginx-plus-demo
chown -R nginx:nginx /var/cache/nginx/artifacts

echo "=== [5/6] Deploying Configurations and Origin ==="
cp "$SCRIPT_DIR/origin.py" /opt/nginx-plus-demo/origin.py

# Back up original nginx.conf
if [ -f /etc/nginx/nginx.conf ] && [ ! -f /etc/nginx/nginx.conf.orig ]; then
    cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.orig
fi
cp "$SCRIPT_DIR/nginx.conf" /etc/nginx/nginx.conf

# Start Mock Origin
pkill -f "origin.py" 2>/dev/null || true
nohup python3 /opt/nginx-plus-demo/origin.py >/opt/nginx-plus-demo/origin.log 2>&1 &
echo $! >/opt/nginx-plus-demo/origin.pid
echo "[+] Mock Origin started with PID $(cat /opt/nginx-plus-demo/origin.pid)"

echo "=== [6/6] Testing and Reloading NGINX Plus ==="
nginx -t
systemctl restart nginx || nginx

echo ""
echo "=== Deployment Complete ==="
echo "Check NGINX Plus status:"
curl -s http://127.0.0.1:8080/
echo ""
echo "Check Mock Origin health:"
curl -s http://127.0.0.1:8081/health
echo ""
echo "Ready! You can now run: bash test_demo.sh"
