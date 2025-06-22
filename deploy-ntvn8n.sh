#!/bin/bash

set -e

# ========== CẤU HÌNH ==========
N8N_VERSION="1.66.0"
DIR="/opt/n8n"
COMPOSE_FILE="$DIR/docker-compose.yml"

# ========== MÀU ==========
GREEN='\033[1;32m'
RED='\033[1;31m'
NC='\033[0m'

echo -e "${GREEN}🛠️ BẮT ĐẦU CÀI ĐẶT N8N TỰ ĐỘNG...${NC}"

# ========== BƯỚC 1: CẬP NHẬT VPS ==========
echo -e "${GREEN}➤ Cập nhật hệ thống...${NC}"
sudo apt update -y && sudo apt upgrade -y

# ========== BƯỚC 2: CÀI DOCKER ==========
echo -e "${GREEN}➤ Cài đặt Docker...${NC}"
curl -fsSL https://get.docker.com | bash
sudo usermod -aG docker $USER

# ========== BƯỚC 3: CÀI DOCKER COMPOSE v2 ==========
echo -e "${GREEN}➤ Cài Docker Compose v2...${NC}"
mkdir -p ~/.docker/cli-plugins
curl -SL https://github.com/docker/compose/releases/download/v2.27.0/docker-compose-linux-x86_64 -o ~/.docker/cli-plugins/docker-compose
chmod +x ~/.docker/cli-plugins/docker-compose

# ========== BƯỚC 4: TẠO THƯ MỤC TRIỂN KHAI ==========
echo -e "${GREEN}➤ Tạo thư mục: $DIR${NC}"
sudo mkdir -p "$DIR"
sudo chown -R $USER:$USER "$DIR"
cd "$DIR"

# ========== BƯỚC 5: TẠO FILE docker-compose.yml ==========
echo -e "${GREEN}➤ Viết file docker-compose.yml...${NC}"

cat > "$COMPOSE_FILE" <<EOF
version: "3.8"

services:
  n8n:
    image: n8nio/n8n:${N8N_VERSION}
    container_name: n8n
    restart: always
    ports:
      - "5678:5678"
    volumes:
      - n8n_data:/home/node/.n8n
    environment:
      - GENERIC_TIMEZONE=Asia/Ho_Chi_Minh
      - TZ=Asia/Ho_Chi_Minh
      - N8N_BASIC_AUTH_ACTIVE=true
      - N8N_BASIC_AUTH_USER=admin
      - N8N_BASIC_AUTH_PASSWORD=admin123
      - WEBHOOK_TUNNEL_URL=http://localhost:5678

volumes:
  n8n_data:
EOF

# ========== BƯỚC 6: KHỞI CHẠY ==========
echo -e "${GREEN}➤ Khởi động N8N...${NC}"
docker compose -f "$COMPOSE_FILE" up -d

echo -e "${GREEN}✅ ĐÃ HOÀN TẤT! TRUY CẬP: http://<IP-VPS>:5678${NC}"
echo -e "${GREEN}➤ Tài khoản: admin | Mật khẩu: admin123${NC}"
