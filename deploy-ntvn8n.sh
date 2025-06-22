#!/bin/bash
set -e

echo "🚀 Dang cai Docker & Docker Compose..."
apt update && apt install -y docker.io docker-compose

echo "📁 Tao thu muc du an n8n..."
mkdir -p /opt/n8n && cd /opt/n8n

echo "📄 Tao file docker-compose.yml..."
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

volumes:
  n8n_data:
EOF

echo "🌐 Cai dat Caddy reverse proxy..."
apt install -y debian-keyring debian-archive-keyring apt-transport-https curl gpg
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | tee /etc/apt/sources.list.d/caddy-stable.list
apt update && apt install caddy -y

mkdir -p /etc/caddy

echo "🛍 Cau hinh domain SSL cho n8n..."
cat > /etc/caddy/Caddyfile <<EOF
ntvn8n.xyz {
    reverse_proxy localhost:5678
}
EOF

echo "⏳ Khoi dong dich vu..."
docker compose up -d
systemctl restart caddy

echo "✅ Hoan tat! Truy cap: https://ntvn8n.xyz voi user: admin / pass: n8n8n123"
