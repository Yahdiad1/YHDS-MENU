#!/bin/bash
BACKUP_DIR="/root/yhds-backup"
mkdir -p "$BACKUP_DIR"
DATE=$(date +%F)
BACKUP_FILE="$BACKUP_DIR/yhds-backup-$DATE.tar.gz"

# Backup semua config & user
tar -czf "$BACKUP_FILE" /etc/xray /root/udp /etc/passwd /etc/shadow /etc/group

# Hanya simpan 7 hari terakhir
find $BACKUP_DIR -type f -name "yhds-backup-*.tar.gz" -mtime +7 -delete
