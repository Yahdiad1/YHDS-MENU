#!/bin/bash
# ============================================================
# YHDS VPN FULL INSTALLER 2025 — UDP ON + MENU 1–20
# SSH • WS/XRAY • TROJAN WS • UDP CUSTOM 1-65535 • Nginx
# ============================================================

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
MENU_FILE="/usr/local/bin/menu"
DOMAIN_FILE="/etc/xray/domain"

mkdir -p "$INSTALL_DIR"

# -------------------------------
# Update system & install dependencies
# -------------------------------
echo -e "${GREEN}Updating system & installing tools...${NC}"
apt update -y && apt upgrade -y
apt install -y curl wget unzip screen bzip2 gzip figlet lolcat nginx ufw socat cron python3-certbot-nginx

# -------------------------------
# Disable IPv6 for UDP stability
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
# Install Nginx
# -------------------------------
echo -e "${GREEN}Installing Nginx...${NC}"
systemctl enable nginx
systemctl start nginx

# -------------------------------
# Download UDP-Custom
# -------------------------------
echo -e "${GREEN}Downloading UDP-Custom...${NC}"
wget -q "$GITHUB_RAW/udp-custom-linux-amd64" -O "$INSTALL_DIR/udp-custom"
chmod +x "$INSTALL_DIR/udp-custom"
wget -q "$GITHUB_RAW/config.json" -O "$INSTALL_DIR/config.json"
chmod 644 "$INSTALL_DIR/config.json"

# -------------------------------
# Create systemd service
# -------------------------------
cat << EOF > "$SYSTEMD_FILE"
[Unit]
Description=YHDS VPN UDP-Custom
After=network.target

[Service]
Type=simple
ExecStart=$INSTALL_DIR/udp-custom server
Restart=on-failure
User=root
WorkingDirectory=$INSTALL_DIR

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable udp-custom
systemctl start udp-custom

# -------------------------------
# Firewall configuration
# -------------------------------
echo -e "${YELLOW}Configuring Firewall...${NC}"
ufw allow 1:65535/udp
ufw allow 22,80,443/tcp
ufw --force enable

# -------------------------------
# Install menu 1–20 terbaru
# -------------------------------
echo -e "${GREEN}Downloading menu.sh 1–20 from GitHub...${NC}"
if [ -f "$MENU_FILE" ]; then rm -f "$MENU_FILE"; fi
wget -q -O "$MENU_FILE" "$GITHUB_RAW/menu.sh"
chmod +x "$MENU_FILE"

# Auto-run menu saat login
if ! grep -q "$MENU_FILE" /root/.bashrc; then
    echo "$MENU_FILE" >> /root/.bashrc
fi

# -------------------------------
# Auto-backup harian
# -------------------------------
cat << EOF > /etc/cron.daily/yhds-backup
#!/bin/bash
tar -czf /root/yhds-backup-\$(date +%F).tar.gz /etc/xray /root/udp /etc/passwd /etc/shadow /etc/group
EOF
chmod +x /etc/cron.daily/yhds-backup

# -------------------------------
# Finish
# -------------------------------
clear
echo -e "${GREEN}========================================================${NC}"
echo -e "${GREEN}       INSTALLATION COMPLETED SUCCESSFULLY!             ${NC}"
echo -e "${GREEN}========================================================${NC}"
echo -e "${BLUE}Use command ${YELLOW}menu${BLUE} to open the VPN management menu.${NC}"
echo -e "${BLUE}UDP + Xray + Nginx siap digunakan${NC}"
echo -e "${BLUE}Auto-run menu terbaru setelah login atau close terminal${NC}"
echo -e "${BLUE}Github: https://github.com/Yahdiad1/Udp-custom${NC}"
