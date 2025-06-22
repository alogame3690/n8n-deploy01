#!/bin/bash
set -e

# ===========================
# 🚀 Cài Docker & Docker Compose
# ===========================
echo "\n🔧 Đang cài Docker & Docker Compose..."
apt update && apt install -y docker.io docker-compose

# ===========================
# 📁 Tạo thư mục /opt/n8n
# ===========================
echo "\n📁 Tạo thư mục chạy dự án n8n..."
mkdir -p /opt/n8n && cd /opt/n8n

# ===========================
# 📄 Tạo file docker-compose.yml
# ===========================
echo "\n📄 Tạo file docker-compose.yml..."
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

# ===========================
# 🌐 Cài Caddy Reverse Proxy (có chứng chỉ SSL)
# ===========================
echo "\n🌐 Cài đặt Caddy reverse proxy..."
apt install -y debian-keyring debian-archive-keyring apt-transport-https
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | gpg --dearmor -o /usr/share/keyrings/caddy-archive-keyring.gpg
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | tee /etc/apt/sources.list.d/caddy-stable.list
apt update && apt install caddy -y

# ===========================
# 🔐 Cấu hình domain SSL cho n8n
# ===========================
echo "\n🔐 Tạo file cấu hình Caddy cho domain..."
cat > /etc/caddy/Caddyfile <<EOF
ntvn8n.xyz {
  reverse_proxy localhost:5678
}
EOF

# ===========================
# 🚀 Khởi động dịch vụ
# ===========================
echo "\n🚀 Khởi động Docker Compose và Caddy..."
docker compose up -d
systemctl restart caddy

echo "\n✅ Triển khai thành công tại: https://ntvn8n.xyz (user: admin / pass: ntvn8n123)"
