FROM ubuntu:22.04

LABEL maintainer="NGINX Plus Workshop"

ENV DEBIAN_FRONTEND=noninteractive

# Install prerequisites
RUN apt-get update && apt-get install -y \
    ca-certificates \
    apt-transport-https \
    lsb-release \
    gnupg \
    curl \
    python3 \
    procps \
    && rm -rf /var/lib/apt/lists/*

# Set up NGINX Plus repository credentials
RUN mkdir -p /etc/ssl/nginx /etc/apt/apt.conf.d /etc/nginx

COPY license.crt /etc/ssl/nginx/nginx-repo.crt
COPY license.key /etc/ssl/nginx/nginx-repo.key
COPY license.jwt /etc/nginx/license.jwt

# Add NGINX signing key and official Plus repository
RUN curl -fsSL https://cs.nginx.com/static/keys/nginx_signing.key | gpg --dearmor -o /etc/apt/trusted.gpg.d/nginx.gpg \
    && printf "deb [signed-by=/etc/apt/trusted.gpg.d/nginx.gpg] https://pkgs.nginx.com/plus/ubuntu `lsb_release -cs` nginx-plus\n" > /etc/apt/sources.list.d/nginx-plus.list \
    && printf "Acquire::https::pkgs.nginx.com::User-Agent \"nginx-install\";\nAcquire::https::pkgs.nginx.com::SslCert \"/etc/ssl/nginx/nginx-repo.crt\";\nAcquire::https::pkgs.nginx.com::SslKey \"/etc/ssl/nginx/nginx-repo.key\";\n" > /etc/apt/apt.conf.d/90nginx-plus

# Install NGINX Plus
RUN apt-get update && apt-get install -y nginx-plus \
    && rm -rf /var/lib/apt/lists/* \
    && rm -f /etc/ssl/nginx/nginx-repo.key /etc/ssl/nginx/nginx-repo.crt /etc/apt/apt.conf.d/90nginx-plus

# Create necessary directories
RUN mkdir -p /var/cache/nginx/artifacts /opt/nginx-plus-demo \
    && chown -R nginx:nginx /var/cache/nginx

# Copy demo components
COPY nginx.conf /etc/nginx/nginx.conf
COPY origin.py /opt/nginx-plus-demo/origin.py
COPY entrypoint.sh /entrypoint.sh

RUN chmod +x /entrypoint.sh

EXPOSE 8080

ENTRYPOINT ["/entrypoint.sh"]
