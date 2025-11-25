#!/bin/bash

# ========================================================
#   YHDS VPN 2025 — FULL INSTALLER + MENU + UDP STABIL
# ========================================================

set -euo pipefail
RED='\033[31m'; GREEN='\033[32m'; YELLOW='\033[33m'; BLUE='\033[34m'; NC='\033[0m'

GITHUB_RAW="https://raw.githubusercontent.com/Yahdiad1/Udp-custom/main"
MENU_RAW="https://raw.githubusercontent.com/Yahdiad1/YHDS-MENU/main"
INSTALL_DIR="/root/udp"
SYSTEMD_FILE="/etc/systemd/system/udp-custom.service"
LOG_FILE="/var/log/udp-custom.log"
DOMAIN_FILE="/etc/xray/domain"

mkdir -p "$INSTALL_DIR"

# ===================== DOMAIN =====================
if [[ ! -f "$DOMAIN_FILE" || -z "$(cat $DOMAIN_FILE)" ]]; then
    read -p "Masukkan Domain VPS: " DOMAIN
    echo "$DOMAIN" > $DOMAIN_FILE
else
    DOMAIN=$(cat $DOMAIN_FILE)
fi

# ===================== UPDATE =====================
echo -e "${GREEN}Updating system...${NC}"
apt update -y && apt upgrade -y

# ===================== DISABLE IPV6 =====================
echo -e "${YELLOW}Disable IPv6 for UDP Stability...${NC}"
cat <<EOF >/etc/sysctl.conf
net.ipv6.conf.all.disable_ipv6=1
net.ipv6.conf.default.disable_ipv6=1
net.ipv6.conf.lo.disable_ipv6=1
fs.file-max=1000000
net.core.rmem_max=2500000
net.core.wmem_max=2500000
net.ipv4.udp_rmem_min=16384
net.ipv4.udp_wmem_min=16384
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
EOF
sysctl -p

# ===================== DEPENDENCIES =====================
apt install -y curl wget unzip screen bzip2 gzip figlet lolcat nginx ufw socat cron certbot jq

# ===================== XRAY =====================
echo -e "${GREEN}Installing Xray...${NC}"
bash -c "$(curl -L https://raw.githubusercontent.com/XTLS/Xray-install/main/install-release.sh)"

systemctl enable xray
systemctl restart xray

# ===================== NGINX + SSL =====================
systemctl enable nginx
systemctl restart nginx

echo -e "${YELLOW}Requesting SSL Certificate...${NC}"
certbot certonly --nginx --agree-tos --email admin@$DOMAIN -d "$DOMAIN" --non-interactive || true

# ===================== UDP CUSTOM =====================
echo -e "${GREEN}Installing UDP-Custom Stable...${NC}"
wget -q "$GITHUB_RAW/udp-custom-linux-amd64" -O "$INSTALL_DIR/udp-custom"
chmod +x "$INSTALL_DIR/udp-custom"

wget -q "$GITHUB_RAW/config.json" -O "$INSTALL_DIR/config.json"
chmod 644 "$INSTALL_DIR/config.json"

touch "$LOG_FILE"

cat <<EOF > "$SYSTEMD_FILE"
[Unit]
Description=YHDS UDP-Custom Stable
After=network.target

[Service]
ExecStart=$INSTALL_DIR/udp-custom server >> $LOG_FILE 2>&1
Restart=always
Type=simple
LimitNOFILE=2000000
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable udp-custom
systemctl restart udp-custom

# ===================== MENU INSTALL =====================
echo -e "${GREEN}Installing Menu...${NC}"
wget -q "$MENU_RAW/menu.sh" -O /usr/local/bin/menu
chmod +x /usr/local/bin/menu

if ! grep -q "menu" ~/.bashrc; then
    echo "menu" >> ~/.bashrc
fi

# ===================== FIREWALL =====================
echo -e "${YELLOW}Configuring Firewall...${NC}"
ufw allow 1:65535/udp
ufw allow 80,443/tcp
ufw --force enable

# ===================== AUTO BACKUP =====================
cat <<EOF >/etc/cron.daily/yhds-backup
#!/bin/bash
tar -czf /root/yhds-backup-\$(date +%F).tar.gz /etc/xray /root/udp /etc/passwd /etc/shadow /etc/group
EOF
chmod +x /etc/cron.daily/yhds-backup

# ===================== DONE =====================
clear
echo -e "${GREEN}========================================================${NC}"
echo -e "${GREEN}         INSTALLATION COMPLETED SUCCESSFULLY!           ${NC}"
echo -e "${GREEN}========================================================${NC}"
echo -e "${BLUE}Domain     : ${YELLOW}$DOMAIN${NC}"
echo -e "${BLUE}Menu       : ${YELLOW}menu${NC}"
echo -e "${BLUE}UDP Log    : ${YELLOW}$LOG_FILE${NC}"
echo -e "${BLUE}Backup Dir : ${YELLOW}/root/yhds-backup-*.tar.gz${NC}"
echo -e "${BLUE}GitHub     : https://github.com/Yahdiad1/${NC}"
