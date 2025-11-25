#!/bin/bash

# ========================================================
# YHDS VPN 2025 FINAL — ALL-IN-ONE INSTALLER + MENU
# SSH • Xray WS/VLESS/VMess • Trojan WS • UDP CUSTOM • Nginx TLS
# ========================================================

set -euo pipefail

# -------------------------------
# Colors
# -------------------------------
RED='\033[31m'; GREEN='\033[32m'; YELLOW='\033[33m'; BLUE='\033[34m'; NC='\033[0m'

# -------------------------------
# Variables
# -------------------------------
GITHUB_RAW="https://raw.githubusercontent.com/Yahdiad1/Udp-custom/main"
INSTALL_DIR="/root/udp"
SYSTEMD_FILE="/etc/systemd/system/udp-custom.service"
LOG_FILE="/var/log/udp-custom.log"
DOMAIN_FILE="/etc/xray/domain"
XRAY_CONFIG="/etc/xray/config.json"

# -------------------------------
# Ask domain if empty
# -------------------------------
if [ ! -f "$DOMAIN_FILE" ] || [ -z "$(cat $DOMAIN_FILE)" ]; then
    read -p "Masukkan domain VPS Anda (contoh: yhds.my.id): " DOMAIN
    echo "$DOMAIN" > $DOMAIN_FILE
else
    DOMAIN=$(cat $DOMAIN_FILE)
fi

mkdir -p "$INSTALL_DIR"

# -------------------------------
# Update system & install dependencies
# -------------------------------
echo -e "${GREEN}Updating system & installing dependencies...${NC}"
apt update -y && apt upgrade -y
apt install -y curl wget unzip screen bzip2 gzip figlet lolcat nginx ufw socat cron software-properties-common certbot

# -------------------------------
# Disable IPv6
# -------------------------------
echo -e "${YELLOW}Disabling IPv6...${NC}"
sysctl -w net.ipv6.conf.all.disable_ipv6=1
sysctl -w net.ipv6.conf.default.disable_ipv6=1
sysctl -w net.ipv6.conf.lo.disable_ipv6=1
grep -qxF 'net.ipv6.conf.all.disable_ipv6=1' /etc/sysctl.conf || echo 'net.ipv6.conf.all.disable_ipv6=1' >> /etc/sysctl.conf
grep -qxF 'net.ipv6.conf.default.disable_ipv6=1' /etc/sysctl.conf || echo 'net.ipv6.conf.default.disable_ipv6=1' >> /etc/sysctl.conf
grep -qxF 'net.ipv6.conf.lo.disable_ipv6=1' /etc/sysctl.conf || echo 'net.ipv6.conf.lo.disable_ipv6=1' >> /etc/sysctl.conf
sysctl -p

# -------------------------------
# Install Xray
# -------------------------------
echo -e "${GREEN}Installing Xray...${NC}"
bash -c "$(curl -L https://raw.githubusercontent.com/XTLS/Xray-install/main/install-release.sh)" >/dev/null 2>&1

# -------------------------------
# Setup Nginx + TLS
# -------------------------------
echo -e "${GREEN}Configuring Nginx...${NC}"
systemctl enable nginx
systemctl start nginx

echo -e "${YELLOW}Requesting TLS certificate via Certbot...${NC}"
certbot certonly --nginx --agree-tos --no-eff-email -m admin@$DOMAIN -d "$DOMAIN" --non-interactive || echo "TLS certificate sudah ada atau gagal request"

# -------------------------------
# Download UDP-Custom
# -------------------------------
echo -e "${GREEN}Downloading UDP-Custom...${NC}"
wget -q "$GITHUB_RAW/udp-custom-linux-amd64" -O "$INSTALL_DIR/udp-custom"
chmod +x "$INSTALL_DIR/udp-custom"
wget -q "$GITHUB_RAW/config.json" -O "$INSTALL_DIR/config.json"
chmod 644 "$INSTALL_DIR/config.json"

# -------------------------------
# Create log file
# -------------------------------
touch "$LOG_FILE"
chmod 644 "$LOG_FILE"

# -------------------------------
# Create systemd service for UDP-Custom
# -------------------------------
cat << EOF > "$SYSTEMD_FILE"
[Unit]
Description=YHDS VPN UDP-Custom
After=network.target

[Service]
Type=simple
ExecStart=$INSTALL_DIR/udp-custom server >> $LOG_FILE 2>&1
Restart=on-failure
User=root
WorkingDirectory=$INSTALL_DIR
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable udp-custom
systemctl start udp-custom

# -------------------------------
# Setup firewall
# -------------------------------
echo -e "${YELLOW}Configuring firewall...${NC}"
ufw allow 1:65535/udp
ufw allow 80,443/tcp
ufw --force enable

# -------------------------------
# Download menu.sh
# -------------------------------
echo -e "${GREEN}Downloading menu.sh...${NC}"
wget -O /usr/local/bin/menu "$GITHUB_RAW/menu.sh"
chmod +x /usr/local/bin/menu

# Auto-run menu saat login
if ! grep -q "/usr/local/bin/menu" /root/.bashrc; then
    echo "/usr/local/bin/menu" >> /root/.bashrc
fi

# -------------------------------
# Setup auto-update cron
# -------------------------------
echo -e "${YELLOW}Setting up auto-update cron...${NC}"
CRON_FILE="/etc/cron.daily/udp-update"
cat << EOF > "$CRON_FILE"
#!/bin/bash
wget -q "$GITHUB_RAW/udp-custom-linux-amd64" -O "$INSTALL_DIR/udp-custom"
chmod +x "$INSTALL_DIR/udp-custom"
wget -q "$GITHUB_RAW/menu.sh" -O /usr/local/bin/menu
chmod +x /usr/local/bin/menu
systemctl restart udp-custom
EOF
chmod +x "$CRON_FILE"

# -------------------------------
# Final message
# -------------------------------
clear
echo -e "${GREEN}Installation COMPLETE!${NC}"
echo -e "${BLUE}Use command ${YELLOW}menu${BLUE} to open the VPN management menu.${NC}"
echo -e "${BLUE}UDP + Xray + Nginx siap digunakan.${NC}"
echo -e "${BLUE}Logs UDP-Custom: ${YELLOW}$LOG_FILE${NC}"
echo -e "${BLUE}Menu akan otomatis muncul setelah login atau close terminal.${NC}"
echo -e "${BLUE}Github: https://github.com/Yahdiad1/Udp-custom${NC}"
