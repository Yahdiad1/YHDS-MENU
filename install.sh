#!/bin/bash
# ================================================================
#  YHDS VPN FULL INSTALLER 2025
#  SSH / WS / XRAY / TROJAN / UDP 1-65535 + AUTO BACKUP
#  Domain: yhds.my.id
#  Repo Menu: https://github.com/Yahdiad1/YHDS-MENU
# ================================================================

set -euo pipefail

# ------------------------------#
#   WARNA
# ------------------------------#
RED='\e[31m'; GREEN='\e[32m'; YELLOW='\e[33m'; BLUE='\e[34m'; NC='\e[0m'

clear
echo -e "${GREEN}=== YHDS VPN INSTALLER 2025 ===${NC}"

# ------------------------------#
#   VALIDASI ROOT
# ------------------------------#
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}Harus dijalankan sebagai ROOT!${NC}"
  exit 1
fi

# ------------------------------#
#   DOMAIN
# ------------------------------#
DOMAIN="yhds.my.id"
echo "$DOMAIN" > /etc/xray/domain

# ------------------------------#
#   UPDATE VPS
# ------------------------------#
apt update -y && apt upgrade -y
apt install -y curl wget unzip socat cron bash-completion jq figlet lolcat nginx

systemctl enable nginx
systemctl restart nginx

# ------------------------------#
#   AUTO BACKUP (Sebelum Install)
# ------------------------------#
mkdir -p /root/YHDS-BACKUP
tar -czf /root/YHDS-BACKUP/preinstall-$(date +%d%m%y).tar.gz /etc 2>/dev/null || true
echo -e "${GREEN}Backup konfigurasi lama selesai.${NC}"

# ------------------------------#
#   INSTALL UDP CUSTOM
# ------------------------------#
echo -e "${YELLOW}Install UDP Custom 1–65535...${NC}"

mkdir -p /etc/udp
cat > /etc/systemd/system/udp-custom.service <<EOF
[Unit]
Description=UDP Forwarder YHDS
After=network.target

[Service]
ExecStart=/usr/local/bin/udp-custom --port 1-65535
Restart=always

[Install]
WantedBy=multi-user.target
EOF

wget -q -O /usr/local/bin/udp-custom https://raw.githubusercontent.com/Yahdiad1/YHDS-MENU/main/bin/udp-custom
chmod +x /usr/local/bin/udp-custom

systemctl enable udp-custom
systemctl restart udp-custom

# ------------------------------#
#   INSTALL XRAY (VMESS / VLESS)
# ------------------------------#
echo -e "${YELLOW}Install Xray...${NC}"

wget -O /usr/local/bin/xray https://github.com/XTLS/Xray-core/releases/latest/download/xray_linux_amd64
chmod +x /usr/local/bin/xray

mkdir -p /etc/xray

cat > /etc/xray/config.json <<EOF
{
  "inbounds": [
    {
      "port": 443,
      "protocol": "vless",
      "settings": { "clients": [] },
      "streamSettings": { "network": "ws", "wsSettings": { "path": "/vless" } }
    },
    {
      "port": 80,
      "protocol": "vmess",
      "settings": { "clients": [] },
      "streamSettings": { "network": "ws", "wsSettings": { "path": "/vmess" } }
    }
  ],
  "outbounds": [{ "protocol": "freedom" }]
}
EOF

cat > /etc/systemd/system/xray.service <<EOF
[Unit]
Description=Xray Service
After=network.target

[Service]
ExecStart=/usr/local/bin/xray run -config /etc/xray/config.json
Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl enable xray
systemctl restart xray

# ------------------------------#
#   INSTALL TROJAN WS
# ------------------------------#
echo -e "${YELLOW}Install Trojan WS...${NC}"

wget -q -O /usr/local/bin/trojan-go https://github.com/p4gefau1t/trojan-go/releases/latest/download/trojan-go-linux-amd64
chmod +x /usr/local/bin/trojan-go

mkdir -p /etc/trojan-go

cat > /etc/trojan-go/config.json <<EOF
{
  "run_type": "server",
  "local_addr": "0.0.0.0",
  "local_port": 8443,
  "password": ["yhdsvpn"],
  "websocket": {
    "enabled": true,
    "path": "/trojan",
    "host": "$DOMAIN"
  }
}
EOF

cat > /etc/systemd/system/trojan-go.service <<EOF
[Unit]
Description=Trojan-Go Service
After=network.target

[Service]
ExecStart=/usr/local/bin/trojan-go -config /etc/trojan-go/config.json
Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl enable trojan-go
systemctl restart trojan-go

# ------------------------------#
#   INSTALL MENU
# ------------------------------#
echo -e "${GREEN}Install YHDS-MENU...${NC}"

wget -q -O /usr/local/bin/menu https://raw.githubusercontent.com/Yahdiad1/YHDS-MENU/main/menu.sh
chmod +x /usr/local/bin/menu

# ------------------------------#
#   CRON AUTO RESTART
# ------------------------------#
(crontab -l 2>/dev/null; echo "0 3 * * * systemctl restart xray trojan-go udp-custom") | crontab -

# ------------------------------#
#   SELESAI
# ------------------------------#
echo -e "${GREEN}================================================${NC}"
echo -e "${GREEN}      INSTALLER YHDS VPN 2025 SELESAI          ${NC}"
echo -e "${GREEN}================================================${NC}"
echo -e "Domain     : $DOMAIN"
echo -e "Menu       : menu"
echo -e "UDP        : 1–65535"
echo -e "Trojan WS  : /trojan"
echo -e "Vless WS   : /vless"
echo -e "Vmess WS   : /vmess"
echo -e "${GREEN}Script full tanpa error, siap dipakai!${NC}"
