#!/bin/bash
### ========================
### ⚙️ Auto Deploy n8n - Latest Version (Optimized)
### Author: AI Assistant 
### Version: v2.0 - 2025-06-29
### ========================

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}### N8N Self-Hosted Deployment Script ###${NC}"

## === Bước 1: Kiểm tra quyền root ===
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}❌ Script này cần quyền root. Chạy với sudo${NC}"
    exit 1
fi

## === Bước 2: Nhập DOMAIN ===
echo -e "\n${YELLOW}== Nhập domain của bạn (VD: n8n.yourdomain.com) ==${NC}"
read -p "DOMAIN: " DOMAIN
if [ -z "$DOMAIN" ]; then
    echo -e "\n${RED}❌ Thiếu domain. Hãy chạy lại script và nhập tên domain.${NC}"
    exit 1
fi

## === Bước 3: Kiểm tra DNS ===
echo -e "\n${BLUE}== Kiểm tra DNS resolution cho $DOMAIN ==${NC}"
if ! nslookup $DOMAIN > /dev/null 2>&1; then
    echo -e "${YELLOW}⚠️ Warning: DNS chưa trỏ về server này. Hãy đảm bảo A record đã được cấu hình.${NC}"
    read -p "Tiếp tục? (y/N): " continue_deploy
    if [[ ! $continue_deploy =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

## === Bước 4: Update system ===
echo -e "\n${BLUE}== Cập nhật hệ thống ==${NC}"
apt update && apt upgrade -y

## === Bước 5: Cài đặt dependencies ===
echo -e "\n${BLUE}== Cài đặt Docker, Docker Compose, Caddy ==${NC}"
apt install -y curl wget unzip ufw gnupg lsb-release

# Install Docker
if ! command -v docker &> /dev/null; then
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
    usermod -aG docker $USER
    systemctl enable docker
    systemctl start docker
    rm get-docker.sh
else
    echo -e "${GREEN}✅ Docker đã được cài đặt${NC}"
fi

# Install Docker Compose
if ! command -v docker-compose &> /dev/null; then
    curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
else
    echo -e "${GREEN}✅ Docker Compose đã được cài đặt${NC}"
fi

# Install Caddy
if ! command -v caddy &> /dev/null; then
    apt install -y debian-keyring debian-archive-keyring apt-transport-https
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
    echo "deb [signed-by=/usr/share/keyrings/caddy-stable-archive-keyring.gpg] https://dl.cloudsmith.io/public/caddy/stable/deb/debian all main" > /etc/apt/sources.list.d/caddy-stable.list
    apt update && apt install caddy -y
    systemctl enable caddy
else
    echo -e "${GREEN}✅ Caddy đã được cài đặt${NC}"
fi

## === Bước 6: Cấu hình Firewall ===
echo -e "\n${BLUE}== Cấu hình UFW Firewall ==${NC}"
ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw allow 80/tcp
ufw allow 443/tcp
ufw --force enable

## === Bước 7: Tạo thư mục cho n8n ===
echo -e "\n${BLUE}== Tạo thư mục n8n ==${NC}"
mkdir -p /opt/n8n
cd /opt/n8n

## === Bước 8: Tạo docker-compose.yml ===
echo -e "\n${BLUE}== Tạo docker-compose.yml ==${NC}"
cat > docker-compose.yml << EOF
version: '3.8'

services:
  n8n:
    image: n8n/n8n:latest
    container_name: n8n
    restart: unless-stopped
    ports:
      - "5678:5678"
    environment:
      - N8N_EDITOR_BASE_URL=https://$DOMAIN
      - N8N_HOST=0.0.0.0
      - N8N_PORT=5678
      - N8N_PROTOCOL=https
      - NODE_ENV=production
      - WEBHOOK_URL=https://$DOMAIN
      - GENERIC_TIMEZONE=Asia/Ho_Chi_Minh
      - N8N_LOG_LEVEL=info
      - N8N_METRICS=true
    volumes:
      - n8n_data:/home/node/.n8n
      - /var/run/docker.sock:/var/run/docker.sock:ro
    networks:
      - n8n_network

volumes:
  n8n_data:
    driver: local

networks:
  n8n_network:
    driver: bridge
EOF

## === Bước 9: Tạo Caddyfile ===
echo -e "\n${BLUE}== Tạo Caddyfile ==${NC}"
cat > /etc/caddy/Caddyfile << EOF
$DOMAIN {
    reverse_proxy localhost:5678 {
        header_up Host {upstream_hostport}
        header_up X-Real-IP {remote_host}
        header_up X-Forwarded-For {remote_host}
        header_up X-Forwarded-Proto {scheme}
    }
    
    # Security headers
    header {
        # Enable HSTS
        Strict-Transport-Security max-age=31536000;
        # Prevent MIME sniffing
        X-Content-Type-Options nosniff
        # Prevent clickjacking
        X-Frame-Options DENY
        # XSS Protection
        X-XSS-Protection "1; mode=block"
        # Referrer Policy
        Referrer-Policy strict-origin-when-cross-origin
    }
    
    # Enable compression
    encode gzip
    
    # Logging
    log {
        output file /var/log/caddy/n8n.log
        format single_field common_log
    }
}
EOF

## === Bước 10: Tạo thư mục log ===
mkdir -p /var/log/caddy
chown caddy:caddy /var/log/caddy

## === Bước 11: Khởi động services ===
echo -e "\n${BLUE}== Khởi động n8n ==${NC}"
docker-compose up -d

# Wait for n8n to start
echo -e "${YELLOW}⏳ Đợi n8n khởi động (30 giây)...${NC}"
sleep 30

## === Bước 12: Restart Caddy ===
echo -e "\n${BLUE}== Khởi động lại Caddy để cấp SSL ==${NC}"
systemctl restart caddy
sleep 10

## === Bước 13: Kiểm tra status ===
echo -e "\n${BLUE}== Kiểm tra trạng thái services ==${NC}"

# Check Docker containers
if docker ps | grep -q n8n; then
    echo -e "${GREEN}✅ N8N container đang chạy${NC}"
else
    echo -e "${RED}❌ N8N container không chạy${NC}"
    docker-compose logs n8n
fi

# Check Caddy
if systemctl is-active --quiet caddy; then
    echo -e "${GREEN}✅ Caddy đang chạy${NC}"
else
    echo -e "${RED}❌ Caddy không chạy${NC}"
    systemctl status caddy
fi

# Check ports
if netstat -tlnp | grep -q ":5678"; then
    echo -e "${GREEN}✅ N8N đang lắng nghe port 5678${NC}"
else
    echo -e "${RED}❌ N8N không lắng nghe port 5678${NC}"
fi

if netstat -tlnp | grep -q ":443"; then
    echo -e "${GREEN}✅ Caddy đang lắng nghe port 443${NC}"
else
    echo -e "${RED}❌ Caddy không lắng nghe port 443${NC}"
fi

## === Bước 14: Tạo script quản lý ===
echo -e "\n${BLUE}== Tạo script quản lý n8n ==${NC}"
cat > /usr/local/bin/n8n-manage << 'EOF'
#!/bin/bash

case "$1" in
    start)
        echo "Starting n8n..."
        cd /opt/n8n && docker-compose up -d
        systemctl start caddy
        ;;
    stop)
        echo "Stopping n8n..."
        cd /opt/n8n && docker-compose down
        systemctl stop caddy
        ;;
    restart)
        echo "Restarting n8n..."
        cd /opt/n8n && docker-compose restart
        systemctl restart caddy
        ;;
    status)
        echo "=== N8N Status ==="
        cd /opt/n8n && docker-compose ps
        echo -e "\n=== Caddy Status ==="
        systemctl status caddy --no-pager
        ;;
    logs)
        echo "=== N8N Logs ==="
        cd /opt/n8n && docker-compose logs -f n8n
        ;;
    update)
        echo "Updating n8n..."
        cd /opt/n8n
        docker-compose pull
        docker-compose up -d
        echo "Update completed!"
        ;;
    backup)
        echo "Creating backup..."
        docker run --rm -v n8n_n8n_data:/data -v $(pwd):/backup alpine tar czf /backup/n8n-backup-$(date +%Y%m%d_%H%M%S).tar.gz -C /data .
        echo "Backup created in current directory"
        ;;
    *)
        echo "Usage: n8n-manage {start|stop|restart|status|logs|update|backup}"
        exit 1
        ;;
esac
EOF

chmod +x /usr/local/bin/n8n-manage

## === Bước 15: Hoàn tất ===
echo -e "\n${GREEN}================================================================${NC}"
echo -e "${GREEN}🎉 N8N đã được cài đặt thành công!${NC}"
echo -e "${GREEN}================================================================${NC}"
echo -e "\n${BLUE}📋 Thông tin truy cập:${NC}"
echo -e "   🌐 URL: ${GREEN}https://$DOMAIN${NC}"
echo -e "   📁 Thư mục: ${GREEN}/opt/n8n${NC}"
echo -e "   🐳 Container: ${GREEN}n8n${NC}"
echo -e "\n${BLUE}📋 Các lệnh quản lý:${NC}"
echo -e "   ${YELLOW}n8n-manage start${NC}    - Khởi động n8n"
echo -e "   ${YELLOW}n8n-manage stop${NC}     - Dừng n8n"
echo -e "   ${YELLOW}n8n-manage restart${NC}  - Khởi động lại n8n"
echo -e "   ${YELLOW}n8n-manage status${NC}   - Kiểm tra trạng thái"
echo -e "   ${YELLOW}n8n-manage logs${NC}     - Xem logs"
echo -e "   ${YELLOW}n8n-manage update${NC}   - Cập nhật n8n"
echo -e "   ${YELLOW}n8n-manage backup${NC}   - Sao lưu dữ liệu"
echo -e "\n${BLUE}📋 Thư mục quan trọng:${NC}"
echo -e "   Config: ${GREEN}/etc/caddy/Caddyfile${NC}"
echo -e "   Logs: ${GREEN}/var/log/caddy/n8n.log${NC}"
echo -e "   Data: ${GREEN}Docker volume n8n_data${NC}"
echo -e "\n${YELLOW}⚠️ Lưu ý:${NC}"
echo -e "   - Hãy đợi 2-3 phút để SSL được cấp hoàn toàn"
echo -e "   - Nếu không truy cập được, kiểm tra DNS và firewall"
echo -e "   - Backup định kỳ bằng lệnh: n8n-manage backup"
echo -e "\n${GREEN}✅ Hoàn tất cài đặt! Truy cập: https://$DOMAIN${NC}"
