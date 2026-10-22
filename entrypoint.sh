#!/bin/bash
set -e

mkdir -p /var/cache/nginx/artifacts /var/log/nginx /opt/nginx-plus-demo
chown -R nginx:nginx /var/cache/nginx/artifacts /var/log/nginx

echo ">>> Starting Mock Artifactory Origin..."
python3 /opt/nginx-plus-demo/origin.py > /var/log/origin.log 2>&1 &
ORIGIN_PID=$!
echo $ORIGIN_PID > /opt/nginx-plus-demo/origin.pid
echo ">>> Mock Origin started with PID $ORIGIN_PID."

cleanup() {
    echo ">>> Stopping services..."
    kill -TERM "$ORIGIN_PID" 2>/dev/null || true
    nginx -s quit 2>/dev/null || true
    wait "$ORIGIN_PID" 2>/dev/null || true
    exit 0
}

trap cleanup SIGINT SIGTERM

echo ">>> Validating NGINX Plus configuration..."
nginx -t

echo ">>> Starting NGINX Plus..."
nginx -g "daemon off;" &
NGINX_PID=$!

wait "$NGINX_PID"
