#!/bin/bash
set -euo pipefail

echo "===== LXC Setup Script – IPv6 & Auto-Update ====="

# 1. container check
if [ ! -f /proc/1/environ ] || ! grep -qa 'container=' /proc/1/environ; then
  echo "WARNUNG: Dieses Skript scheint nicht in einem Container zu laufen."
  read -p "Trotzdem fortfahren? (y/n): " confirm
  [[ $confirm != "y" ]] && exit 1
fi

# 2. deactivate ipv6
read -p "Möchtest du IPv6 deaktivieren? (y/n): " disable_ipv6
if [[ "$disable_ipv6" == "y" ]]; then
  echo "IPv6 wird deaktiviert …"
  cp /etc/sysctl.conf /etc/sysctl.conf.bak_$(date +%F_%T)
  {
    echo ""
    echo "# IPv6 deaktivieren"
    echo "net.ipv6.conf.all.disable_ipv6 = 1"
    echo "net.ipv6.conf.default.disable_ipv6 = 1"
  } | tee -a /etc/sysctl.conf
  sysctl -p
  echo "IPv6 wurde deaktiviert."
else
  echo "IPv6 bleibt aktiv."
fi

# 3. cronjob for daily updates 4 am
read -p "Cronjob für tägliches apt update & upgrade um 4 Uhr morgens setzen? (y/n): " set_cron
if [[ "$set_cron" == "y" ]]; then
  CRONCMD="/usr/bin/apt update && /usr/bin/apt upgrade -y > /dev/null 2>&1"
  CRONJOB="0 4 * * * $CRONCMD"
  if ! ( crontab -l 2>/dev/null | grep -Fq "$CRONCMD" ); then
    ( crontab -l 2>/dev/null; echo "$CRONJOB" ) | crontab -
    echo "Cronjob dauerhaft hinzugefügt."
  else
    echo "Cronjob ist bereits vorhanden, kein Eintrag notwendig."
  fi
else
  echo "Kein Cronjob eingerichtet."
fi

# 4. immediate update
read -p "Jetzt sofort 'apt update && upgrade -y' ausführen? (y/n): " do_update
if [[ "$do_update" == "y" ]]; then
  echo "Führe Update & Upgrade aus …"
  apt update && apt upgrade -y
  echo "System aktualisiert."
fi

# 5. cleaning - remove folder
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
if [[ "$(basename "$REPO_ROOT")" == "proxmox-scripts" ]]; then
  read -p "Repository-Verzeichnis '$REPO_ROOT' löschen? (y/n): " remove_repo
  if [[ "$remove_repo" == "y" ]]; then
    rm -rf "$REPO_ROOT"
    echo "Verzeichnis entfernt."
  fi
fi
