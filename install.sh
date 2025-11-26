#!/bin/bash
# ============================================================
#  YHDS VPN FULL INSTALLER 2025
#  SSH WS 80/443 • VLESS • VMESS • TROJAN WS 443 • UDP Custom
# ============================================================

set -euo pipefail

# -------------------------
# COLORS
# -------------------------
RED='\033[31m'; GREEN='\033[32m'; YELLOW='\033[33m'; BLUE='\033[34m'; NC='\033[0m'

# -------------------------
# ROOT CHECK
# -------------------------
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}Harus dijalankan sebagai ROOT!${NC}"
  exit 1
fi

# -------------------------
# UPDATE SYSTEM & DEPENDENCIES
# -------------------------
echo -e "${GREEN}→ Update system & install dependencies...${NC}"
apt update -y && apt upgrade -y
apt install -y curl wget unzip socat netcat jq cron nginx certbot

# -------------------------
# DISABLE IPV6
# -------------------------
echo -e "${YELLOW}→ Disable IPv6...${NC}"
sysctl -w net.ipv6.conf.all.disable_ipv6=1
sysctl -w net.ipv6.conf.default.disable_ipv6=1
sysctl -p >/dev/null 2>&1

# -------------------------
# INSTALL XRAY
# -------------------------
echo -e "${GREEN}→ Installing Xray...${NC}"
bash -c "$(curl -L https://raw.githubusercontent.com/XTLS/Xray-install/main/install-release.sh)" >/dev/null 2>&1
UUID=$(cat /proc/sys/kernel/random/uuid)

mkdir -p /etc/xray

cat <<EOF >/etc/xray/config.json
{
  "log": { "access": "/var/log/xray/access.log", "error": "/var/log/xray/error.log", "loglevel": "warning" },
  "inbounds": [
    {
      "port": 10000,
      "listen": "127.0.0.1",
      "protocol": "vless",
      "settings": { "clients": [ { "id": "$UUID" } ], "decryption": "none" },
      "streamSettings": { "network": "ws", "wsSettings": { "path": "/vless" } }
    },
    {
      "port": 10001,
      "listen": "127.0.0.1",
      "protocol": "vmess",
      "settings": { "clients": [ { "id": "$UUID" } ] },
      "streamSettings": { "network": "ws", "wsSettings": { "path": "/vmess" } }
    }
  ],
  "outbounds": [ { "protocol": "freedom" } ]
}
EOF

systemctl enable xray
systemctl restart xray

# -------------------------
# INPUT DOMAIN (TROJAN WS)
# -------------------------
read -rp "Masukkan domain (kosongkan jika belum ada): " DOMAIN
if [ -n "$DOMAIN" ]; then
  echo "$DOMAIN" >/etc/xray/domain
  echo -e "${GREEN}→ Request TLS certificate...${NC}"
  certbot certonly --standalone -d $DOMAIN --non-interactive --agree-tos -m admin@$DOMAIN
  SSL_CERT="/etc/letsencrypt/live/$DOMAIN/fullchain.pem"
  SSL_KEY="/etc/letsencrypt/live/$DOMAIN/privkey.pem"
  SECURITY="tls"
else
  SSL_CERT=""
  SSL_KEY=""
  SECURITY="none"
fi

# -------------------------
# TROJAN WS 443 CONFIG
# -------------------------
cat <<EOF >/etc/xray/trojan-443.json
{
  "inbounds": [
    {
      "port": 443,
      "protocol": "trojan",
      "settings": { "clients": [ { "password": "$UUID" } ] },
      "streamSettings": {
        "network": "ws",
        "wsSettings": { "path": "/trojan" },
        "security": "$SECURITY",
        "tlsSettings": {
          "certificates": [
            { "certificateFile": "$SSL_CERT", "keyFile": "$SSL_KEY" }
          ]
        }
      }
    }
  ],
  "outbounds": [ { "protocol": "freedom" } ]
}
EOF

XRAY_BIN=$(command -v xray || echo "/usr/local/bin/xray")

cat <<EOF >/etc/systemd/system/trojanws.service
[Unit]
Description=Trojan WS 443
After=network.target

[Service]
ExecStart=$XRAY_BIN run -config /etc/xray/trojan-443.json
Restart=always
User=root
WorkingDirectory=/etc/xray

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable trojanws
systemctl restart trojanws

# -------------------------
# NGINX CONFIG (WS REVERSE PROXY)
# -------------------------
rm -f /etc/nginx/conf.d/*
cat <<'EOF' >/etc/nginx/conf.d/ws.conf
server {
  listen 80 default_server;
  listen [::]:80 default_server;
  server_name _;

  location /sshws {
      proxy_pass http://127.0.0.1:8880;
      proxy_http_version 1.1;
      proxy_set_header Upgrade $http_upgrade;
      proxy_set_header Connection "upgrade";
      proxy_set_header Host $host;
  }

  location /vless {
      proxy_pass http://127.0.0.1:10000;
      proxy_http_version 1.1;
      proxy_set_header Upgrade $http_upgrade;
      proxy_set_header Connection "upgrade";
      proxy_set_header Host $host;
  }

  location /vmess {
      proxy_pass http://127.0.0.1:10001;
      proxy_http_version 1.1;
      proxy_set_header Upgrade $http_upgrade;
      proxy_set_header Connection "upgrade";
      proxy_set_header Host $host;
  }
}
EOF

systemctl enable nginx
systemctl restart nginx

# -------------------------
# SSH WEBSOCKET SERVICE
# -------------------------
cat <<'EOF' >/usr/local/bin/sshws
#!/bin/bash
while true; do
  nc -lvp 8880 -c "sed -e 's/Connection: close/Connection: Upgrade/' | nc 127.0.0.1 22"
done
EOF
chmod +x /usr/local/bin/sshws

cat <<EOF >/etc/systemd/system/sshws.service
[Unit]
Description=SSH WebSocket
After=network.target

[Service]
ExecStart=/usr/local/bin/sshws
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable sshws
systemctl restart sshws

# -------------------------
# UDP CUSTOM 1–65535
# -------------------------
mkdir -p /root/udp
wget -q https://raw.githubusercontent.com/Yahdiad1/Udp-custom/main/udp-custom-linux-amd64 -O /root/udp/udp-custom
chmod +x /root/udp/udp-custom

cat <<EOF >/etc/systemd/system/udp-custom.service
[Unit]
Description=YHDS VPN UDP Custom
After=network.target

[Service]
Type=simple
ExecStart=/root/udp/udp-custom server -p 1-65535
Restart=always
User=root
WorkingDirectory=/root/udp

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
grep -qxF "menu" /root/.bashrc || echo "menu" >> /root/.bashrc

# -------------------------
# BACKUP CONFIG CRON
# -------------------------
mkdir -p /root/YHDS-BACKUP
(crontab -l 2>/dev/null; echo "0 3 * * * tar -czf /root/YHDS-BACKUP/daily-\$(date +\%F).tar.gz /etc/xray /root/udp") | crontab -

# -------------------------
# FINISH
# -------------------------
clear
echo -e "${GREEN}==============================================${NC}"
echo -e "${GREEN}      YHDS VPN 2025 - INSTALLATION COMPLETE      ${NC}"
echo -e "${GREEN}==============================================${NC}"
echo -e "UUID       : $UUID"
echo -e "SSH WS     : 80 / 443"
echo -e "VMESS WS   : 443 (via Nginx)"
echo -e "VLESS WS   : 443 (via Nginx)"
echo -e "TROJAN WS  : 443 (TLS jika domain ada)"
echo -e "UDP Custom : 1–65535 (auto-restart)"
echo -e "${GREEN}==============================================${NC}"
