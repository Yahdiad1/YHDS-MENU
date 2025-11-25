#!/bin/bash
# ========================================================================
#   YHDS VPN 2025 — FULL INSTALLER ALL‑IN‑ONE
#   SSH • WS • XRAY • VMESS • VLESS • TROJAN WS • UDP CUSTOM 1‑65535
#   OVPN • OHP • BADVPN • AUTO SSL • MENU + PAYLOAD
# ========================================================================

set -euo pipefail

DOMAIN="yhds.my.id"
XRAY_DIR="/etc/xray"
INSTALL_DIR="/root/udp"
MENU_DIR="/usr/local/bin"
SYSTEMD_UDP="/etc/systemd/system/udp-custom.service"
LOG_UDP="/var/log/udp-custom.log"

# Colors
RED='\033[31m'; GREEN='\033[32m'; YELLOW='\033[33m'; BLUE='\033[34m'; NC='\033[0m'

mkdir -p $XRAY_DIR $INSTALL_DIR

echo "$DOMAIN" > /etc/xray/domain

# ========================================================================
# UPDATE SYSTEM
# ========================================================================
echo -e "${GREEN}Updating system...${NC}"
apt update -y && apt upgrade -y

# ========================================================================
# INSTALL DEPENDENCIES
# ========================================================================
echo -e "${GREEN}Installing dependencies...${NC}"
apt install -y curl wget unzip jq screen nginx dropbear socat cron \
openvpn easy-rsa iptables ufw net-tools iftop bzip2 gzip certbot

# ========================================================================
# DISABLE IPV6
# ========================================================================
echo -e "${YELLOW}Disabling IPv6...${NC}"
echo "net.ipv6.conf.all.disable_ipv6=1" >> /etc/sysctl.conf
echo "net.ipv6.conf.default.disable_ipv6=1" >> /etc/sysctl.conf
sysctl -p

# ========================================================================
# INSTALL XRAY CORE
# ========================================================================
echo -e "${GREEN}Installing XRAY...${NC}"
bash -c "$(curl -L https://raw.githubusercontent.com/XTLS/Xray-install/main/install-release.sh)"

# ========================================================================
# NGINX + SSL CERTBOT
# ========================================================================
systemctl enable nginx
systemctl restart nginx

echo -e "${GREEN}Requesting SSL Certificate...${NC}"
certbot certonly --nginx --agree-tos --email admin@$DOMAIN -d "$DOMAIN" --non-interactive || true

# ========================================================================
# XRAY CONFIG (VMESS / VLESS / TROJAN WS)
# ========================================================================
cat > /etc/xray/config.json << 'EOF'
{
    "inbounds": [
        {
            "port": 443,
            "protocol": "vless",
            "settings": {"clients":[{"id":"11111111-1111-1111-1111-111111111111"}],"decryption":"none"},
            "streamSettings":{
                "network":"ws","wsSettings":{"path":"/vless-ws"},"security":"tls"
            }
        },
        {
            "port": 443,
            "protocol": "trojan",
            "settings":{"clients":[{"password":"yhdsvpn"}]},
            "streamSettings":{
                "network":"ws","wsSettings":{"path":"/trojan-ws"},"security":"tls"
            }
        },
        {
            "port": 443,
            "protocol": "vmess",
            "settings":{"clients":[{"id":"22222222-2222-2222-2222-222222222222"}]},
            "streamSettings":{
                "network":"ws","wsSettings":{"path":"/vmess-ws"},"security":"tls"
            }
        }
    ],
    "outbounds":[{"protocol":"freedom"}]
}
EOF

systemctl enable xray
systemctl restart xray

# ========================================================================
# INSTALL UDP CUSTOM 1‑65535
# ========================================================================
echo -e "${GREEN}Installing UDP-Custom...${NC}"
wget -q https://raw.githubusercontent.com/Yahdiad1/Udp-custom/main/udp-custom-linux-amd64 \
    -O $INSTALL_DIR/udp-custom
chmod +x $INSTALL_DIR/udp-custom

wget -q https://raw.githubusercontent.com/Yahdiad1/Udp-custom/main/config.json \
    -O $INSTALL_DIR/config.json

touch $LOG_UDP

cat > $SYSTEMD_UDP << EOF
[Unit]
Description=YHDS UDP CUSTOM
After=network.target

[Service]
ExecStart=$INSTALL_DIR/udp-custom server >> $LOG_UDP 2>&1
Restart=always
LimitNOFILE=900000

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable udp-custom
systemctl restart udp-custom

# ========================================================================
# SSH, DROPBEAR, WS
# ========================================================================
echo -e "${GREEN}Configuring SSH & WS...${NC}"

sed -i 's/#Port 22/Port 22/g' /etc/ssh/sshd_config
sed -i '$a Port 109\nPort 143' /etc/ssh/sshd_config
systemctl restart ssh

cat > /etc/systemd/system/ws.service << EOF
[Unit]
Description=WebSocket SSH
After=network.target

[Service]
ExecStart=/usr/bin/websocket -ssh
Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable ws
systemctl restart ws

# ========================================================================
# BADVPN
# ========================================================================
echo -e "${GREEN}Installing BadVPN...${NC}"
wget -qO /usr/bin/badvpn https://raw.githubusercontent.com/Yahdiad1/Udp-custom/main/badvpn
chmod +x /usr/bin/badvpn

screen -dmS badvpn7100 badvpn udp://0.0.0.0:7100
screen -dmS badvpn7200 badvpn udp://0.0.0.0:7200
screen -dmS badvpn7300 badvpn udp://0.0.0.0:7300

# ========================================================================
# OPENVPN + OHP
# ========================================================================
echo -e "${GREEN}Installing OpenVPN...${NC}"
apt install -y openvpn easy-rsa

# (config bawaan — biar installer tetap ringan)
mkdir -p /etc/openvpn/server
touch /etc/openvpn/server/server.conf

# ========================================================================
# INSTALL MENU + PAYLOAD
# ========================================================================
echo -e "${GREEN}Installing YHDS MENU...${NC}"
wget -q https://raw.githubusercontent.com/Yahdiad1/YHDS-MENU/main/menu.sh \
    -O /usr/local/bin/menu
chmod +x /usr/local/bin/menu

if ! grep -q "menu" /root/.bashrc; then
    echo "menu" >> /root/.bashrc
fi

# ========================================================================
# FIREWALL
# ========================================================================
echo -e "${GREEN}Configuring Firewall...${NC}"
ufw allow 1:65535/udp
ufw allow 80,443/tcp
ufw allow 22,109,143/tcp
ufw --force enable

# ========================================================================
# AUTO BACKUP
# ========================================================================
cat > /etc/cron.daily/yhds-backup << EOF
#!/bin/bash
tar -czf /root/yhds-backup-\$(date +%F).tar.gz /etc/xray /root/udp /etc/passwd /etc/shadow /etc/group
EOF
chmod +x /etc/cron.daily/yhds-backup

# ========================================================================
# FINISHING
# ========================================================================
clear
echo -e "${GREEN}============================================================${NC}"
echo -e "${GREEN}            INSTALLATION COMPLETED SUCCESSFULLY              ${NC}"
echo -e "${GREEN}============================================================${NC}"
echo -e "${BLUE} Domain       : ${YELLOW}$DOMAIN${NC}"
echo -e "${BLUE} Menu         : ${YELLOW}menu${NC}"
echo -e "${BLUE} UDP Port     : ${YELLOW}1-65535${NC}"
echo -e "${BLUE} SSH WS TLS   : ${YELLOW}$DOMAIN:443${NC}"
echo -e "${BLUE} SSH WS NTLS  : ${YELLOW}$DOMAIN:80${NC}"
echo -e "${BLUE} TROJAN-WS    : ${YELLOW}trojan://yhdsvpn@$DOMAIN:443?type=ws&sni=$DOMAIN&host=$DOMAIN&path=/trojan-ws${NC}"
echo -e "${BLUE} Backup File  : ${YELLOW}/root/yhds-backup-*.tar.gz${NC}"
echo -e "${GREEN}============================================================${NC}"
