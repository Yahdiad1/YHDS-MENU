#!/bin/bash
# ============================================================
# YHDS VPN FULL MENU 1–20 PREMIUM 2025
# SSH • WS/XRAY • TROJAN WS • UDP CUSTOM • Nginx
# ============================================================

RED='\e[31m'; GREEN='\e[32m'; YELLOW='\e[33m'
BLUE='\e[34m'; CYAN='\e[36m'; NC='\e[0m'

DOMAIN_FILE="/etc/xray/domain"

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
  printf " %-23s %-23s\n" "1) Create SSH" "11) Manual Payload"
  printf " %-23s %-23s\n" "2) Delete SSH" "12) Set Domain"
  printf " %-23s %-23s\n" "3) List User" "13) Exit"
  printf " %-23s %-23s\n" "4) Create Trojan" "14) Renew Akun"
  printf " %-23s %-23s\n" "5) Trial SSH" "15) ON/OFF Service"
  printf " %-23s %-23s\n" "6) Lock/Unlock" "16) Info VPS"
  printf " %-23s %-23s\n" "7) Dashboard" "17) Backup"
  printf " %-23s %-23s\n" "8) Bot Telegram" "18) Restore"
  printf " %-23s %-23s\n" "9) Restart All" "19) View UDP Logs"
  printf " %-23s %-23s\n" "10) Remove Script" "20) Clean Expired"
  echo -e "${NC}"
}

# ================= FUNCTIONS =================
create_user() {
  read -p "Username: " u
  read -p "Password: " p
  read -p "Expired (hari): " e
  useradd -e $(date -d "$e days" +"%Y-%m-%d") -M -s /bin/false $u
  echo "$u:$p" | chpasswd

  EXP=$(chage -l $u | grep "Account expires" | awk -F": " '{print $2}')
  domain=$(cat $DOMAIN_FILE)

  clear
  echo -e "${GREEN}Akun SSH Berhasil Dibuat!${NC}"
  echo "-----------------------------------"
  echo "User : $u"
  echo "Pass : $p"
  echo "Exp  : $EXP"
  echo "Domain: $domain"
  echo "-----------------------------------"
  echo ""
  echo -e "${CYAN}Payload Websocket:${NC}"
  echo "GET / HTTP/1.1[crlf]Host: $domain[crlf]Connection: Upgrade[crlf]Upgrade: websocket[crlf][crlf]"
  read -n1 -r -p "Press any key..."
}

delete_user() {
  read -p "Username: " user
  userdel -f $user && echo "User removed"
  read -n1
}

list_user() {
  echo "Daftar User SSH:"
  awk -F: '$3>=1000 {print $1}' /etc/passwd
  read -n1
}

trial_user() {
  u="trial$(openssl rand -hex 2)"
  p="1"
  exp=$(date -d "+1 days" +"%Y-%m-%d")
  domain=$(cat $DOMAIN_FILE)
  useradd -e "$exp" -s /bin/false "$u"
  echo -e "$p\n$p" | passwd "$u" >/dev/null 2>&1
  echo "Trial $u | Pass: $p | Exp: $exp"
  read -n1
}

lock_unlock() {
  read -p "Username: " user
  passwd -l $user && echo "$user dikunci!"
  read -p "Aktifkan user? y/n: " yn
  [[ $yn == "y" ]] && passwd -u $user && echo "$user aktif!"
  read -n1
}

create_trojan() {
  read -p "Nama User Trojan: " user
  read -p "Password Trojan: " pass
  read -p "Masa aktif (hari): " days
  domain=$(cat $DOMAIN_FILE)
  exp=$(date -d "+$days days" +"%Y-%m-%d")

  sed -i "/\"clients\": \[/a\        {\"password\": \"$pass\", \"email\": \"$user\"}," /etc/xray/config.json
  systemctl restart xray

  clear
  echo -e "${GREEN}TROJAN WS Berhasil Dibuat!${NC}"
  echo "User : $user"
  echo "Pass : $pass"
  echo "Exp  : $exp"
  echo "Domain: $domain"
  echo -e "${CYAN}Link Trojan:${NC}"
  echo "trojan://$pass@$domain:443?security=tls&type=ws&path=/trojan-ws&host=$domain#$user"
  echo -e "${CYAN}Payload Trojan WS:${NC}"
  echo "GET /trojan-ws HTTP/1.1[crlf]Host: $domain[crlf]Connection: Upgrade[crlf]Upgrade: websocket[crlf][crlf]"
  read -n1
}

bot_telegram() { echo "Bot Telegram aktif."; read -n1; }
restart_service() { systemctl restart ssh xray nginx trojan-go udp-custom; echo "Semua service direstart!"; read -n1; }
manual_payload() { clear; echo "GET wss://$(cat /etc/xray/domain)/ HTTP/1.1"; echo "Upgrade: websocket"; read -n1; }
set_domain() { read -p "Domain baru: " dm; echo "$dm" > $DOMAIN_FILE; systemctl restart xray nginx; echo "Domain diganti ke $dm"; read -n1; }
renew_user() { read -p "User: " u; read -p "Tambah hari: " add; old=$(chage -l $u | grep "Account expires" | awk -F": " '{print $2}'); new=$(date -d "$old + $add days" +"%Y-%m-%d"); chage -E "$new" $u; echo "Akun diperpanjang sampai $new"; read -n1; }
toggle_service() { read -p "Service: " s; systemctl is-active --quiet $s && systemctl stop $s || systemctl start $s; read -n1; }
info_vps() { echo "Hostname: $(hostname)"; echo "IP Publik: $(curl -s ipv4.icanhazip.com)"; echo "Uptime: $(uptime -p)"; free -h; read -n1; }
backup_users() { tar -czf /root/yhds-backup-$(date +%F).tar.gz /etc/xray /root/udp /etc/passwd /etc/shadow /etc/group; echo "Backup tersimpan"; read -n1; }
restore_users() { echo "Restore backup (pilih file):"; ls /root; read -p "File: " file; tar -xzf "/root/$file" -C /; systemctl restart xray udp-custom; echo "Restore selesai!"; read -n1; }
view_logs() { less /var/log/udp-custom.log; }
clean_expired() { today=$(date +%s); for u in $(awk -F: '$3>=1000 {print $1}' /etc/passwd); do exp=$(chage -l $u | grep "Account expires" | awk -F": " '{print $2}'); [[ "$exp" != "never" ]] && [[ $(date -d "$exp" +%s) -lt $today ]] && userdel -f $u && echo "User $u expired dihapus"; done; read -n1; }

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
