#!/bin/bash
# ============================================================
# YHDS VPN 2025 — FULL INSTALLER + MENU
# SSH • WS/XRAY • VMESS • VLESS • TROJAN WS • UDP CUSTOM
# ============================================================

set -euo pipefail

RED='\033[31m'; GREEN='\033[32m'; YELLOW='\033[33m'; BLUE='\033[34m'; NC='\033[0m'
DOMAIN_FILE="/etc/xray/domain"
INSTALL_DIR="/root/udp"
LOG_FILE="/var/log/udp-custom.log"
SYSTEMD_FILE="/etc/systemd/system/udp-custom.service"

mkdir -p "$INSTALL_DIR"

# ===================== DOMAIN =====================
if [[ ! -f "$DOMAIN_FILE" || -z "$(cat $DOMAIN_FILE)" ]]; then
    read -p "Masukkan Domain VPS: " DOMAIN
    echo "$DOMAIN" > $DOMAIN_FILE
else
    DOMAIN=$(cat $DOMAIN_FILE)
fi

# ===================== UPDATE SYSTEM =====================
echo -e "${GREEN}Updating system...${NC}"
apt update -y && apt upgrade -y

# ===================== INSTALL DEPENDENCIES =====================
apt install -y curl wget unzip screen bzip2 gzip figlet lolcat nginx ufw socat cron python3-certbot-nginx openvpn easy-rsa

# ===================== DISABLE IPV6 =====================
echo -e "${YELLOW}Disabling IPv6...${NC}"
sysctl -w net.ipv6.conf.all.disable_ipv6=1
sysctl -w net.ipv6.conf.default.disable_ipv6=1
sysctl -w net.ipv6.conf.lo.disable_ipv6=1
echo "net.ipv6.conf.all.disable_ipv6=1" >> /etc/sysctl.conf
echo "net.ipv6.conf.default.disable_ipv6=1" >> /etc/sysctl.conf
echo "net.ipv6.conf.lo.disable_ipv6=1" >> /etc/sysctl.conf
sysctl -p

# ===================== INSTALL XRAY =====================
echo -e "${GREEN}Installing XRAY...${NC}"
bash -c "$(curl -L https://raw.githubusercontent.com/XTLS/Xray-install/main/install-release.sh)"

# ===================== NGINX & SSL =====================
systemctl enable nginx
systemctl start nginx
echo -e "${YELLOW}Requesting SSL Certificate...${NC}"
certbot --nginx --agree-tos --email admin@$DOMAIN -d "$DOMAIN" --non-interactive || true

# ===================== INSTALL UDP CUSTOM =====================
echo -e "${GREEN}Installing UDP-Custom...${NC}"
wget -q "https://raw.githubusercontent.com/Yahdiad1/Udp-custom/main/udp-custom-linux-amd64" -O "$INSTALL_DIR/udp-custom"
chmod +x "$INSTALL_DIR/udp-custom"
wget -q "https://raw.githubusercontent.com/Yahdiad1/Udp-custom/main/config.json" -O "$INSTALL_DIR/config.json"
chmod 644 "$INSTALL_DIR/config.json"
touch "$LOG_FILE"

cat << EOF > "$SYSTEMD_FILE"
[Unit]
Description=YHDS UDP-Custom
After=network.target

[Service]
ExecStart=$INSTALL_DIR/udp-custom server >> $LOG_FILE 2>&1
Restart=always
User=root
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable udp-custom
systemctl restart udp-custom

# ===================== MENU FULL =====================
echo -e "${GREEN}Installing YHDS Menu...${NC}"
wget -q "https://raw.githubusercontent.com/Yahdiad1/YHDS-MENU/main/menu.sh" -O /usr/local/bin/menu
chmod +x /usr/local/bin/menu
grep -qxF "menu" /root/.bashrc || echo "menu" >> /root/.bashrc

# ===================== FIREWALL =====================
echo -e "${YELLOW}Configuring Firewall...${NC}"
ufw allow 1:65535/udp
ufw allow 22,80,443/tcp
ufw --force enable

# ===================== AUTO BACKUP DAILY =====================
cat << EOF > /etc/cron.daily/yhds-backup
#!/bin/bash
tar -czf /root/yhds-backup-\$(date +%F).tar.gz /etc/xray /root/udp /etc/passwd /etc/shadow /etc/group
EOF
chmod +x /etc/cron.daily/yhds-backup

# ===================== DONE =====================
clear
echo -e "${GREEN}========================================================${NC}"
echo -e "${GREEN}       INSTALLATION COMPLETED SUCCESSFULLY!             ${NC}"
echo -e "${GREEN}========================================================${NC}"
echo -e "${BLUE}Domain     : ${YELLOW}$DOMAIN${NC}"
echo -e "${BLUE}Menu       : ${YELLOW}menu${NC}"
echo -e "${BLUE}UDP Log    : ${YELLOW}$LOG_FILE${NC}"
echo -e "${BLUE}Auto Backup: ${YELLOW}/root/yhds-backup-*.tar.gz${NC}"
