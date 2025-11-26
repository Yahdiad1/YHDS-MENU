#!/bin/bash
# ============================================================
#  YHDS VPN — FINAL INSTALLER 2025
#  SSH WS 80/443 • VMESS • VLESS • TROJAN-WS • UDP Custom
# ============================================================

set -euo pipefail

# -------------------------
# WARNA
# -------------------------
BLUE='\033[34m'
YELLOW='\033[33m'
GREEN='\033[32m'
RED='\033[31m'
NC='\033[0m'

clear
echo -e "${BLUE}=============================================="
echo -e "            YHDS VPN INSTALLER 2025"
echo -e "==============================================${NC}"

# -------------------------
# VALIDASI ROOT
# -------------------------
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Harus dijalankan sebagai ROOT!${NC}"
    exit 1
fi

# -------------------------
# DISABLE IPV6
# -------------------------
echo -e "${YELLOW}→ Disable IPv6...${NC}"
cat <<EOF >/etc/sysctl.d/99-disable-ipv6.conf
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
EOF
sysctl --system >/dev/null 2>&1

# -------------------------
# INPUT DOMAIN
# -------------------------
read -rp "Masukkan Domain (ex: yhds.my.id): " DOMAIN
echo "$DOMAIN" >/etc/xray/domain

# -------------------------
# UPDATE SYSTEM & DEPENDENCIES
# -------------------------
echo -e "${YELLOW}→ Update system & install dependencies...${NC}"
apt update -y && apt upgrade -y
apt install -y curl wget unzip nginx socat cron netcat jq certbot

systemctl enable nginx
systemctl restart nginx

# -------------------------
# BACKUP PRA-INSTALL
# -------------------------
mkdir -p /root/YHDS-BACKUP
tar -czf /root/YHDS-BACKUP/preinstall-$(date +%d%m%y).tar.gz /etc 2>/dev/null || true
echo -e "${GREEN}Backup konfigurasi lama selesai.${NC}"

# -------------------------
# SETUP NGINX REVERSE PROXY WS
# -------------------------
echo -e "${YELLOW}→ Setup Nginx reverse proxy...${NC}"
rm -f /etc/nginx/conf.d/default.conf
cat <<EOF >/etc/nginx/conf.d/ws.conf
server {
    listen 80;
    server_name $DOMAIN;
    return 301 https://\$host\$request_uri;
}

server {
    listen 443 ssl http2;
    server_name $DOMAIN;

    ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;

    location /sshws {
        proxy_pass http://127.0.0.1:8880;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
    }

    location /vless {
        proxy_pass http://127.0.0.1:10000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
    }

    location /vmess {
        proxy_pass http://127.0.0.1:10001;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
    }

    location /trojan {
        proxy_pass http://127.0.0.1:10002;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
    }
}
EOF

systemctl restart nginx

# -------------------------
# INSTALL CERTBOT SSL
# -------------------------
echo -e "${YELLOW}→ Mendapatkan SSL/TLS via Certbot...${NC}"
systemctl stop nginx
certbot certonly --standalone -d $DOMAIN --non-interactive --agree-tos -m admin@$DOMAIN
systemctl start nginx

# -------------------------
# INSTALL XRAY CORE
# -------------------------
echo -e "${YELLOW}→ Install Xray Core...${NC}"
bash <(curl -s https://raw.githubusercontent.com/XTLS/Xray-install/main/install-release.sh)

uuid=$(cat /proc/sys/kernel/random/uuid)

# -------------------------
# KONFIG XRAY WS (VLESS / VMESS / TROJAN)
# -------------------------
cat <<EOF >/etc/xray/config.json
{
  "log": { "access": "/var/log/xray/access.log", "error": "/var/log/xray/error.log", "loglevel": "warning" },
  "inbounds": [
    {
      "port": 10000,
      "listen": "127.0.0.1",
      "protocol": "vless",
      "settings": { "clients": [ { "id": "$uuid" } ], "decryption": "none" },
      "streamSettings": { "network": "ws", "wsSettings": { "path": "/vless" } }
    },
    {
      "port": 10001,
      "listen": "127.0.0.1",
      "protocol": "vmess",
      "settings": { "clients": [ { "id": "$uuid" } ] },
      "streamSettings": { "network": "ws", "wsSettings": { "path": "/vmess" } }
    },
    {
      "port": 10002,
      "listen": "127.0.0.1",
      "protocol": "trojan",
      "settings": { "clients": [ { "password": "$uuid" } ] },
      "streamSettings": { "network": "ws", "wsSettings": { "path": "/trojan" } }
    }
  ],
  "outbounds": [ { "protocol": "freedom" } ]
}
EOF

systemctl restart xray

# -------------------------
# SSH WEBSOCKET 80/443
# -------------------------
echo -e "${YELLOW}→ Setup SSH WS...${NC}"
cat <<'EOF' >/usr/local/bin/sshws
#!/bin/bash
while true; do
    nc -lvp 8880 -c "sed -e 's/Connection: close/Connection: Upgrade/' | nc 127.0.0.1 22"
done
EOF
chmod +x /usr/local/bin/sshws

cat <<EOF >/etc/systemd/system/sshws.service
[Unit]
Description=SSH WebSocket Service
After=network.target

[Service]
ExecStart=/usr/local/bin/sshws
Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable sshws
systemctl restart sshws

# -------------------------
# UDP CUSTOM 1–65535
# -------------------------
echo -e "${YELLOW}→ Install UDP Custom...${NC}"
wget -q -O /usr/local/bin/udp-custom https://raw.githubusercontent.com/Yahdiad1/YHDS-MENU/main/bin/udp-custom
chmod +x /usr/local/bin/udp-custom

cat <<EOF >/etc/systemd/system/udp-custom.service
[Unit]
Description=UDP Forwarder YHDS
After=network.target

[Service]
ExecStart=/usr/local/bin/udp-custom -p 1-65535
Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable udp-custom
systemctl restart udp-custom

# -------------------------
# MENU YHDS
# -------------------------
wget -q -O /usr/local/bin/menu https://raw.githubusercontent.com/Yahdiad1/YHDS-MENU/main/menu.sh
chmod +x /usr/local/bin/menu
if ! grep -q "menu" /root/.bashrc; then
    echo "menu" >> /root/.bashrc
fi

# -------------------------
# AUTO BACKUP CRON
# -------------------------
mkdir -p /root/YHDS-BACKUP
(crontab -l 2>/dev/null; echo "0 3 * * * tar -czf /root/YHDS-BACKUP/daily-\$(date +\%F).tar.gz /etc/xray /etc/udp") | crontab -

# -------------------------
# FINISH
# -------------------------
clear
echo -e "${GREEN}==============================================${NC}"
echo -e "${GREEN}      INSTALLER YHDS VPN 2025 SELESAI          ${NC}"
echo -e "${GREEN}==============================================${NC}"
echo -e "Domain     : $DOMAIN"
echo -e "UUID       : $uuid"
echo -e "SSH WS     : 80 / 443"
echo -e "VMESS WS   : 443 (via Nginx)"
echo -e "VLESS WS   : 443 (via Nginx)"
echo -e "TROJAN WS  : 443 (via Nginx)"
echo -e "UDP Custom : 1–65535"
echo -e "${GREEN}==============================================${NC}"
