#!/bin/bash
# ============================================================
# YHDS VPN ALL-IN-ONE INSTALLER 2025
# SSH • WS/XRAY • TROJAN WS • UDP CUSTOM • Nginx • Menu Premium
# ============================================================

set -euo pipefail
RED='\033[31m'; GREEN='\033[32m'; YELLOW='\033[33m'; BLUE='\033[34m'; NC='\033[0m'

# -------------------------
# Validasi ROOT
# -------------------------
if [[ $EUID -ne 0 ]]; then
  echo -e "${RED}Harus dijalankan sebagai ROOT!${NC}"
  exit 1
fi

# -------------------------
# Disable IPv6
# -------------------------
echo -e "${YELLOW}→ Disable IPv6...${NC}"
cat <<EOF >/etc/sysctl.d/99-disable-ipv6.conf
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
EOF
sysctl --system >/dev/null 2>&1

# -------------------------
# Update system & dependencies
# -------------------------
echo -e "${GREEN}→ Update & install dependencies...${NC}"
apt update -y && apt upgrade -y
apt install -y curl wget unzip socat netcat jq cron nginx certbot screen bzip2 gzip figlet lolcat

systemctl enable nginx
systemctl restart nginx

# -------------------------
# Direktori Xray
# -------------------------
mkdir -p /etc/xray
echo -e "${GREEN}Direktori /etc/xray siap${NC}"

# -------------------------
# Input Domain
# -------------------------
read -rp "Masukkan Domain (kosongkan jika belum ada): " DOMAIN
if [[ -n "$DOMAIN" ]]; then
  echo "$DOMAIN" >/etc/xray/domain
fi

# -------------------------
# Install Xray Core
# -------------------------
echo -e "${GREEN}→ Install Xray Core...${NC}"
bash -c "$(curl -L https://raw.githubusercontent.com/XTLS/Xray-install/main/install-release.sh)" >/dev/null 2>&1
UUID=$(cat /proc/sys/kernel/random/uuid)

# -------------------------
# Konfigurasi Xray WS
# -------------------------
cat <<EOF >/etc/xray/config.json
{
  "log": { "access": "/var/log/xray/access.log", "error": "/var/log/xray/error.log", "loglevel": "warning" },
  "inbounds": [
    { "port": 10000, "listen": "127.0.0.1", "protocol": "vless", "settings": { "clients": [ { "id": "$UUID" } ], "decryption": "none" }, "streamSettings": { "network": "ws", "wsSettings": { "path": "/vless" } } },
    { "port": 10001, "listen": "127.0.0.1", "protocol": "vmess", "settings": { "clients": [ { "id": "$UUID" } ] }, "streamSettings": { "network": "ws", "wsSettings": { "path": "/vmess" } } }
  ],
  "outbounds": [ { "protocol": "freedom" } ]
}
EOF
systemctl restart xray

# -------------------------
# Nginx reverse proxy
# -------------------------
rm -f /etc/nginx/conf.d/default.conf
cat <<EOF >/etc/nginx/conf.d/ws.conf
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name _;
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
}
EOF
systemctl restart nginx

# -------------------------
# Trojan WS 443
# -------------------------
if [[ -n "$DOMAIN" ]]; then
    echo -e "${YELLOW}→ Setup Trojan WS TLS...${NC}"
    certbot certonly --standalone -d $DOMAIN --non-interactive --agree-tos -m admin@$DOMAIN
    SSL_CERT="/etc/letsencrypt/live/$DOMAIN/fullchain.pem"
    SSL_KEY="/etc/letsencrypt/live/$DOMAIN/privkey.pem"
    SECURITY="tls"
else
    SSL_CERT=""; SSL_KEY=""; SECURITY="none"
fi

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
        "tlsSettings": { "certificates": [ { "certificateFile": "$SSL_CERT", "keyFile": "$SSL_KEY" } ] }
      }
    }
  ],
  "outbounds": [ { "protocol": "freedom" } ]
}
EOF

# -------------------------
# Trojan WS service
# -------------------------
XRAY_BIN=$(command -v xray || echo "/usr/local/bin/xray")
cat <<EOF >/etc/systemd/system/trojanws.service
[Unit]
Description=Trojan WS 443 Service
After=network.target

[Service]
ExecStart=$XRAY_BIN run -config /etc/xray/trojan-443.json
Restart=always

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable trojanws
systemctl restart trojanws

# -------------------------
# SSH WebSocket service
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
# UDP Custom service
# -------------------------
mkdir -p /usr/local/bin
wget -q -O /usr/local/bin/udp-custom https://raw.githubusercontent.com/Yahdiad1/Udp-custom/main/udp-custom-linux-amd64
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
# Menu YHDS VPN
# -------------------------
wget -q -O /usr/local/bin/menu https://raw.githubusercontent.com/Yahdiad1/YHDS-MENU/main/menu.sh
chmod +x /usr/local/bin/menu
grep -qxF "menu" /root/.bashrc || echo "menu" >> /root/.bashrc

# -------------------------
# Cron Auto Backup
# -------------------------
mkdir -p /root/YHDS-BACKUP
(crontab -l 2>/dev/null; echo "0 3 * * * tar -czf /root/YHDS-BACKUP/daily-\$(date +\%F).tar.gz /etc/xray /etc/udp") | crontab -

# -------------------------
# Finish
# -------------------------
clear
echo -e "${GREEN}==============================================${NC}"
echo -e "${GREEN}      INSTALLER YHDS VPN 2025 SELESAI          ${NC}"
echo -e "${GREEN}==============================================${NC}"
echo -e "UUID       : $UUID"
echo -e "SSH WS     : 80 / 443"
echo -e "VMESS WS   : 443 (via Nginx)"
echo -e "VLESS WS   : 443 (via Nginx)"
echo -e "TROJAN WS  : 443 (TLS jika domain ada)"
echo -e "UDP Custom : 1–65535"
echo -e "${GREEN}Menu otomatis bisa diakses dengan perintah ${YELLOW}menu${GREEN}${NC}"
