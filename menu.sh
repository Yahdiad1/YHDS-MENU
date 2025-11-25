#!/bin/bash
# ============================================================
# YHDS VPN FULL MENU 1–20 PREMIUM 2025
# SSH • WS/XRAY • TROJAN WS • UDP CUSTOM • Nginx • Payload Full
# ============================================================

RED='\e[31m'; GREEN='\e[32m'; YELLOW='\e[33m'
BLUE='\e[34m'; CYAN='\e[36m'; NC='\e[0m'

DOMAIN_FILE="/etc/xray/domain"
domain=$(cat $DOMAIN_FILE)

# ================= STATUS =================
status() {
  echo -e "${GREEN}Status Server:${NC}"
  for srv in ssh xray nginx trojan-go udp-custom; do
    if systemctl is-active --quiet $srv; then
      echo -e "${CYAN}$srv${NC} : ${GREEN}ON${NC}"
    else
      echo -e "${CYAN}$srv${NC} : ${RED}OFF${NC}"
    fi
  done
  echo ""
}

# ================= BANNER =================
banner() {
  clear
  echo -e "${RED}__  ____  ______  _____    _    ______  _   __${NC}"
  echo -e "${RED}\\ \\/ / / / / __ \\/ ___/   | |  / / __ \\/ | / /${NC}"
  echo -e "${RED} \\  / /_/ / / / /\\__ \\    | | / / /_/ /  |/ /${NC}"
  echo -e "${RED} / / __  / /_/ /___/ /    | |/ / ____/ /|  /${NC}"
  echo -e "${RED}/_/_/ /_/_____//____/     |___/_/   /_/ |_|${NC}"
  echo ""
  status
}

# ================= MENU GRID 1-20 =================
show_menu() {
  echo -e "${YELLOW}"
  printf " %-25s %-25s\n" "1) Create SSH" "11) Manual Payload"
  printf " %-25s %-25s\n" "2) Delete SSH" "12) Set Domain"
  printf " %-25s %-25s\n" "3) List User" "13) Exit"
  printf " %-25s %-25s\n" "4) Create Trojan" "14) Renew Akun"
  printf " %-25s %-25s\n" "5) Trial SSH" "15) ON/OFF Service"
  printf " %-25s %-25s\n" "6) Lock/Unlock" "16) Info VPS"
  printf " %-25s %-25s\n" "7) Dashboard" "17) Backup"
  printf " %-25s %-25s\n" "8) Bot Telegram" "18) Restore"
  printf " %-25s %-25s\n" "9) Restart All" "19) View UDP Logs"
  printf " %-25s %-25s\n" "10) Remove Script" "20) Clean Expired"
  echo -e "${NC}"
}

# ================= FULL ACCOUNT OUTPUT =================
output_account() {
user=$1
pass=$2
exp=$3

clear
echo "━━━━━━━━━━━━━━━━━━━  INFORMATION ACCOUNT SSH  ━━━━━━━━━━━━━━━━━━━"
echo "Username        : $user"
echo "Password        : $pass"
echo "Limit IP        : Unlimited"
echo "━━━━━━━━━━━━━━━━━━━"
echo "Domain          : $domain"
echo "OpenSSH         : 22"
echo "Dropbear        : 109, 143"
echo "SSL/TLS         : 443"
echo "SSH WS TLS      : 443"
echo "SSH WS None TLS : 80"
echo "SSH UDP Custom  : 1-65535"
echo "OHP SSH         : 8686"
echo "OHP OVPN        : 8787"
echo "OVPN TCP        : 1194"
echo "OVPN UDP        : 2200"
echo "Badvpn UDP      : 7100, 7200, 7300"
echo "━━━━━━━━━━━━━━━━━━━"
echo "SSH WS TLS"
echo ": $domain:443@$user:$pass"
echo "━━━━━━━━━━━━━━━━━━━"
echo "SSH WS NONE TLS"
echo ": $domain:80@$user:$pass"
echo "━━━━━━━━━━━━━━━━━━━"
echo "SSH UDP CUSTOM"
echo ": $domain:1-65535@$user:$pass"
echo "━━━━━━━━━━━━━━━━━━━"
echo "PAYLOAD SSH WS"
echo "GET / HTTP/1.1[crlf]"
echo "Host: $domain[crlf]"
echo "Connection: Upgrade[crlf]"
echo "User-Agent: [ua][crlf]"
echo "Upgrade: websocket[crlf][crlf]"
echo "━━━━━━━━━━━━━━━━━━━"
echo "PAYLOAD ENHANCED"
echo "PATCH / HTTP/1.1[crlf]"
echo "Host: $domain[crlf]"
echo "Host: bug.com[crlf]"
echo "Upgrade: websocket[crlf]"
echo "Connection: Upgrade[crlf]"
echo "User-Agent: [ua][crlf][crlf]"
echo "HTTP/enhanced 200 Ok[crlf]"
echo "━━━━━━━━━━━━━━━━━━━"
echo "PAYLOAD SPECIAL"
echo "GET / HTTP/1.1[crlf]"
echo "Host: [host][crlf][crlf][split]"
echo "CF-RAY / HTTP/1.1[crlf]"
echo "Host: $domain[crlf]"
echo "Connection: Keep-Alive[crlf]"
echo "Upgrade: websocket[crlf][crlf]"
echo "━━━━━━━━━━━━━━━━━━━"
echo "Active      : $exp"
echo "Created     : $(date +"%d %b %Y")"
echo "━━━━━━━━━━━━━━━━━━━"
read -n1 -r -p "Press any key..."
}

# ================= FUNCTIONS =================
create_user() {
  read -p "Username: " u
  read -p "Password: " p
  read -p "Expired (hari): " e
  useradd -e $(date -d "$e days" +"%Y-%m-%d") -M -s /bin/false $u
  echo "$u:$p" | chpasswd
  exp=$(date -d "$e days" +"%d %b %Y")
  output_account "$u" "$p" "$exp"
}

delete_user() { read -p "Username: " user; userdel -f $user && echo "User removed"; read -n1; }
list_user() { awk -F: '$3>=1000 {print $1}' /etc/passwd; read -n1; }
trial_user() {
  u="trial$(openssl rand -hex 2)"
  p="1"
  exp=$(date -d "+1 days" +"%d %b %Y")
  useradd -e "$(date -d '+1 days')" -s /bin/false "$u"
  echo "$u:$p" | chpasswd
  output_account "$u" "$p" "$exp"
}

lock_unlock() { read -p "Username: " user; passwd -l $user; read -p "Aktifkan user? y/n: " yn; [[ $yn == "y" ]] && passwd -u $user; }
create_trojan() {
  read -p "User: " user
  read -p "Password: " pass
  read -p "Durasi hari: " days
  exp=$(date -d "+$days days" +"%d %b %Y")
  sed -i "/\"clients\": \[/a\        {\"password\": \"$pass\", \"email\": \"$user\"}," /etc/xray/config.json
  systemctl restart xray
  clear
  echo "━━━━━━━━━━━━━━━━━━ TROJAN WS ACCOUNT ━━━━━━━━━━━━━━━━━━"
  echo "User      : $user"
  echo "Pass      : $pass"
  echo "Domain    : $domain"
  echo "Expired   : $exp"
  echo ""
  echo "LINK TROJAN WS:"
  echo "trojan://$pass@$domain:443?security=tls&type=ws&path=/trojan-ws&host=$domain&sni=$domain#$user"
  echo ""
  echo "PAYLOAD TROJAN WS:"
  echo "GET /trojan-ws HTTP/1.1[crlf]"
  echo "Host: $domain[crlf]"
  echo "Connection: Upgrade[crlf]"
  echo "Upgrade: websocket[crlf][crlf]"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  read -n1
}

# menu lainnya sama seperti sebelumnya…

bot_telegram() { echo "Bot aktif"; read -n1; }
restart_service() { systemctl restart ssh xray nginx trojan-go udp-custom; echo "Semua service direstart!"; read -n1; }
manual_payload() { echo "GET wss://$domain/ HTTP/1.1"; read -n1; }
set_domain() { read -p "Domain baru: " dm; echo "$dm" > $DOMAIN_FILE; domain=$dm; systemctl restart xray nginx; }
renew_user() { read -p "User: " u; read -p "Tambah hari: " add; new=$(date -d "$(chage -l $u | grep 'Account expires' | awk -F': ' '{print $2}') + $add days" +"%Y-%m-%d"); chage -E "$new" $u; }
toggle_service() { read -p "Service: " s; systemctl is-active --quiet $s && systemctl stop $s || systemctl start $s; }
info_vps() { hostnamectl; curl -s ipv4.icanhazip.com; uptime -p; read -n1; }
backup_users() { tar -czf /root/yhds-backup-$(date +%F).tar.gz /etc/xray /root/udp /etc/passwd /etc/shadow /etc/group; }
restore_users() { ls /root; read -p "File: " file; tar -xzf /root/$file -C /; systemctl restart xray udp-custom; }
view_logs() { less /var/log/udp-custom.log; }
clean_expired() { today=$(date +%s); for u in $(awk -F: '$3>=1000 {print $1}' /etc/passwd); do exp=$(chage -l $u | grep "Account expires" | awk -F": " '{print $2}'); [[ "$exp" != "never" ]] && [[ $(date -d "$exp" +%s) -lt $today ]] && userdel -f $u && echo "Hapus: $u"; done; read -n1; }

# ================= LOOP MENU =================
while true; do
  banner
  show_menu
  read -p "Pilih menu: " x
  case $x in
    1) create_user ;;
    2) delete_user ;;
    3) list_user ;;
    4) create_trojan ;;
    5) trial_user ;;
    6) lock_unlock ;;
    7) w; read -n1 ;;
    8) bot_telegram ;;
    9) restart_service ;;
    10) rm -f /usr/local/bin/menu; exit ;;
    11) manual_payload ;;
    12) set_domain ;;
    13) exit 0 ;;
    14) renew_user ;;
    15) toggle_service ;;
    16) info_vps ;;
    17) backup_users ;;
    18) restore_users ;;
    19) view_logs ;;
    20) clean_expired ;;
    *) echo "Pilihan tidak valid"; sleep 1 ;;
  esac
done
