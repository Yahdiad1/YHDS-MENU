#!/bin/bash
# ============================================================
# YHDS VPN FULL INSTALLER 2025 — UDP ON
# SSH • WS/XRAY • TROJAN WS • UDP CUSTOM 1-65535 • Nginx
# Domain/SSL bisa di-set nanti lewat menu
# ============================================================

set -euo pipefail

RED='\033[31m'; GREEN='\033[32m'; YELLOW='\033[33m'; BLUE='\033[34m'; CYAN='\033[36m'; NC='\033[0m'

GITHUB_RAW="https://raw.githubusercontent.com/Yahdiad1/Udp-custom/main"
INSTALL_DIR="/root/udp"
SYSTEMD_FILE="/etc/systemd/system/udp-custom.service"
LOG_FILE="/var/log/udp-custom.log"
DOMAIN_FILE="/etc/xray/domain"

mkdir -p "$INSTALL_DIR"

# ===================== SKIP DOMAIN =====================
echo -e "${YELLOW}Domain belum di-set, skip konfigurasi SSL...${NC}"
DOMAIN="localhost"
echo "$DOMAIN" > $DOMAIN_FILE

# ===================== UPDATE SYSTEM =====================
echo -e "${GREEN}Updating system & installing dependencies...${NC}"
apt update -y && apt upgrade -y
apt install -y curl wget unzip screen bzip2 gzip figlet lolcat nginx ufw socat cron

# ===================== DISABLE IPV6 =====================
echo -e "${YELLOW}Disabling IPv6 for UDP stability...${NC}"
sysctl -w net.ipv6.conf.all.disable_ipv6=1
sysctl -w net.ipv6.conf.default.disable_ipv6=1
sysctl -w net.ipv6.conf.lo.disable_ipv6=1
grep -qxF 'net.ipv6.conf.all.disable_ipv6=1' /etc/sysctl.conf || echo 'net.ipv6.conf.all.disable_ipv6=1' >> /etc/sysctl.conf
grep -qxF 'net.ipv6.conf.default.disable_ipv6=1' /etc/sysctl.conf || echo 'net.ipv6.conf.default.disable_ipv6=1' >> /etc/sysctl.conf
grep -qxF 'net.ipv6.conf.lo.disable_ipv6=1' /etc/sysctl.conf || echo 'net.ipv6.conf.lo.disable_ipv6=1' >> /etc/sysctl.conf
sysctl -p

# ===================== INSTALL XRAY =====================
echo -e "${GREEN}Installing XRAY...${NC}"
bash -c "$(curl -L https://raw.githubusercontent.com/XTLS/Xray-install/main/install-release.sh)"

# ===================== NGINX =====================
systemctl enable nginx
systemctl start nginx

# ===================== INSTALL UDP CUSTOM =====================
echo -e "${GREEN}Installing UDP-Custom...${NC}"
wget -q "$GITHUB_RAW/udp-custom-linux-amd64" -O "$INSTALL_DIR/udp-custom"
chmod +x "$INSTALL_DIR/udp-custom"
wget -q "$GITHUB_RAW/config.json" -O "$INSTALL_DIR/config.json"
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
WorkingDirectory=$INSTALL_DIR

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable udp-custom
systemctl start udp-custom

# ===================== FIREWALL =====================
echo -e "${YELLOW}Configuring firewall...${NC}"
ufw allow 1:65535/udp
ufw allow 22,80,443/tcp
ufw --force enable

# ===================== INSTALL MENU =====================
echo -e "${GREEN}Installing YHDS Menu...${NC}"
wget -q "$GITHUB_RAW/menu.sh" -O /usr/local/bin/menu
chmod +x /usr/local/bin/menu

if ! grep -q "/usr/local/bin/menu" /root/.bashrc; then
    echo "/usr/local/bin/menu" >> /root/.bashrc
fi

# ===================== AUTO BACKUP =====================
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
echo -e "${BLUE}Github     : ${YELLOW}https://github.com/Yahdiad1/${NC}"
echo -e "${GREEN}UDP CUSTOM 1-65535 AKTIF${NC}"
