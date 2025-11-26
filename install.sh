#!/bin/bash
# ============================================================
# YHDS VPN FULL 2025 (UDP + SSH WS + Trojan WS + Xray + Menu 1-20)
# ============================================================

set -euo pipefail
RED='\033[31m'; GREEN='\033[32m'; YELLOW='\033[33m'; BLUE='\033[34m'; NC='\033[0m'

# ===== ROOT CHECK =====
[[ $EUID -ne 0 ]] && echo -e "${RED}Harus dijalankan sebagai ROOT!${NC}" && exit 1

# ===== UPDATE SYSTEM =====
apt update -y && apt upgrade -y
apt install -y curl wget unzip socat netcat jq cron nginx screen bzip2 gzip figlet lolcat lsof certbot

systemctl enable nginx
systemctl restart nginx

# ===== DISABLE IPV6 =====
cat <<EOF >/etc/sysctl.d/99-disable-ipv6.conf
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
EOF
sysctl --system >/dev/null 2>&1

# ===== DIRECTORIES =====
mkdir -p /etc/xray /root/YHDS-BACKUP /usr/local/bin

# ===== DOMAIN =====
read -rp "Masukkan Domain (kosongkan jika belum ada): " DOMAIN
[[ -n "$DOMAIN" ]] && echo "$DOMAIN" >/etc/xray/domain

# ===== INSTALL XRAY =====
bash -c "$(curl -L https://raw.githubusercontent.com/XTLS/Xray-install/main/install-release.sh)" >/dev/null 2>&1
UUID=$(cat /proc/sys/kernel/random/uuid)

# ===== XRAY CONFIG =====
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

# ===== NGINX CONFIG =====
rm -f /etc/nginx/conf.d/default.conf
cat <<EOF >/etc/nginx/conf.d/ws.conf
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name _;
    location /sshws { proxy_pass http://127.0.0.1:8880; proxy_http_version 1.1; proxy_set_header Upgrade \$http_upgrade; proxy_set_header Connection "upgrade"; proxy_set_header Host \$host; }
    location /vless { proxy_pass http://127.0.0.1:10000; proxy_http_version 1.1; proxy_set_header Upgrade \$http_upgrade; proxy_set_header Connection "upgrade"; proxy_set_header Host \$host; }
    location /vmess { proxy_pass http://127.0.0.1:10001; proxy_http_version 1.1; proxy_set_header Upgrade \$http_upgrade; proxy_set_header Connection "upgrade"; proxy_set_header Host \$host; }
}
EOF
systemctl restart nginx

# ===== TROJAN WS 80 & 443 =====
SSL_CERT=""; SSL_KEY=""; SECURITY="none"
if [[ -n "$DOMAIN" ]]; then
  systemctl stop nginx
  certbot certonly --standalone -d $DOMAIN --non-interactive --agree-tos -m admin@$DOMAIN
  SSL_CERT="/etc/letsencrypt/live/$DOMAIN/fullchain.pem"
  SSL_KEY="/etc/letsencrypt/live/$DOMAIN/privkey.pem"
  SECURITY="tls"
  systemctl restart nginx
fi

cat <<EOF >/etc/xray/trojan-80-443.json
{
  "inbounds": [
    { "port": 80, "protocol": "trojan", "settings": { "clients": [ { "password": "$UUID" } ] }, "streamSettings": { "network": "ws", "wsSettings": { "path": "/trojan" } } },
    { "port": 443, "protocol": "trojan", "settings": { "clients": [ { "password": "$UUID" } ] }, "streamSettings": { "network": "ws", "wsSettings": { "path": "/trojan" }, "security": "$SECURITY", "tlsSettings": { "certificates": [ { "certificateFile": "$SSL_CERT", "keyFile": "$SSL_KEY" } ] } } }
  ],
  "outbounds": [ { "protocol": "freedom" } ]
}
EOF

XRAY_BIN=$(command -v xray || echo "/usr/local/bin/xray")
cat <<EOF >/etc/systemd/system/trojanws.service
[Unit]
Description=Trojan WS 80 & 443
After=network.target
[Service]
ExecStart=$XRAY_BIN run -config /etc/xray/trojan-80-443.json
Restart=always
[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable trojanws
systemctl restart trojanws

# ===== SSH WS 80 & 443 =====
cat <<'EOF' >/usr/local/bin/sshws
#!/bin/bash
while true; do
  nc -lvp 8880 -c "sed -e 's/Connection: close/Connection: Upgrade/' | nc 127.0.0.1 22"
done
EOF
chmod +x /usr/local/bin/sshws
cat <<EOF >/etc/systemd/system/sshws.service
[Unit]
Description=SSH WebSocket 80 & 443
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

# ===== UDP CUSTOM STABIL 1-65535 =====
wget -q -O /usr/local/bin/udp-custom https://raw.githubusercontent.com/Yahdiad1/Udp-custom/main/udp-custom-linux-amd64
chmod +x /usr/local/bin/udp-custom
cat <<EOF >/etc/systemd/system/udp-custom.service
[Unit]
Description=UDP Forwarder YHDS
After=network.target
[Service]
Type=simple
ExecStart=/usr/local/bin/udp-custom -p 1-65535
Restart=always
User=root
[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable udp-custom
systemctl restart udp-custom

# ===== MENU 1-20 =====
wget -q -O /usr/local/bin/menu https://raw.githubusercontent.com/Yahdiad1/YHDS-MENU/main/menu1-20.sh
chmod +x /usr/local/bin/menu
grep -qxF "/usr/local/bin/menu" /root/.bashrc || echo "/usr/local/bin/menu" >> /root/.bashrc

# ===== CRON BACKUP =====
(crontab -l 2>/dev/null; echo "0 3 * * * tar -czf /root/YHDS-BACKUP/daily-\$(date +\%F).tar.gz /etc/xray /usr/local/bin/udp-custom") | crontab -

# ===== FINISH =====
clear
echo -e "${GREEN}YHDS VPN 2025 SIAP DIGUNAKAN${NC}"
echo -e "${BLUE}UUID       : ${YELLOW}$UUID${NC}"
echo -e "${BLUE}SSH WS     : 80 / 443"
echo -e "${BLUE}Trojan WS  : 80 / 443"
echo -e "${BLUE}VMESS/VLESS: 443"
echo -e "${BLUE}UDP Custom : 1–65535 (STABIL)"
echo -e "${GREEN}Menu otomatis muncul dengan perintah ${YELLOW}menu${GREEN}${NC}"
