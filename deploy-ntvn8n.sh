#!/bin/bash
set -e

echo "📦 Đang cài Docker & Docker Compose..."
apt update && apt install -y docker.io docker-compose

echo "📁 Tạo thư mục dự án n8n..."
mkdir -p /opt/n8n && cd /opt/n8n

echo "📄 Tạo file docker-compose.yml..."
cat > docker-compose.yml <<EOF
version: "3.7"

services:
  n8n:
    image: n8nio/n8n:1.66.0
    restart: always
    ports:
      - "5678:5678"
    environment:
      - N8N_BASIC_AUTH_ACTIVE=true
      - N8N_BASIC_AUTH_USER=admin
      - N8N_BASIC_AUTH_PASSWORD=ntvn8n123
      - WEBHOOK_URL=https://ntvn8n.xyz/
      - GENERIC_TIMEZONE=Asia/Ho_Chi_Minh
    volumes:
      - n8n_data:/home/node/.n8n

  caddy:
    image: caddy:2
    restart: always
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile
      - caddy_data:/data
      - caddy_config:/config

volumes:
  n8n_data:
  caddy_data:
  caddy_config:
EOF

echo "📄 Tạo file Caddyfile..."
cat > Caddyfile <<EOF
ntvn8n.xyz {
  reverse_proxy n8n:5678
}
EOF

echo "🚀 Khởi động Docker Compose..."
docker compose up -d
