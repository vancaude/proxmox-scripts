#!/bin/bash

echo "===== LXC Setup Script – IPv6 & Auto-Update ====="

# Optional: prüfen, ob das Skript in einem Container läuft
if [ ! -f /proc/1/environ ] || ! grep -qa 'container=' /proc/1/environ; then
  echo " WARNUNG: Dieses Skript scheint nicht in einem Container zu laufen."
  read -p "Trotzdem fortfahren? (y/n): " confirm
  [[ $confirm != "y" ]] && exit 1
fi

# IPv6 deaktivieren
read -p "Möchtest du IPv6 deaktivieren? (y/n): " disable_ipv6
if [[ "$disable_ipv6" == "y" ]]; then
  echo "IPv6 wird deaktiviert..."
  cp /etc/sysctl.conf /etc/sysctl.conf.bak_$(date +%F_%T)
  echo -e "\n# IPv6 deaktivieren" | tee -a /etc/sysctl.conf
  echo "net.ipv6.conf.all.disable_ipv6 = 1" | tee -a /etc/sysctl.conf
  echo "net.ipv6.conf.default.disable_ipv6 = 1" | tee -a /etc/sysctl.conf
  sysctl -p
  echo "IPv6 wurde deaktiviert."
else
  echo "IPv6 bleibt aktiv."
fi

# Cronjob für apt update/upgrade
read -p "Cronjob für tägliches apt update & upgrade um 4 Uhr morgens setzen? (y/n): " set_cron
if [[ "$set_cron" == "y" ]]; then
  CRONCMD="/usr/bin/apt update && /usr/bin/apt upgrade -y > /dev/null 2>&1"
  CRONJOB="0 4 * * * $CRONCMD"

  ( crontab -l 2>/dev/null | grep -F "$CRONCMD" ) >/dev/null
  if [ $? -ne 0 ]; then
    ( crontab -l 2>/dev/null; echo "$CRONJOB" ) | crontab -
    echo "Cronjob dauerhaft hinzugefügt."
  else
    echo "ℹ Cronjob ist bereits vorhanden, kein Eintrag notwendig."
  fi
else
  echo "Kein Cronjob eingerichtet."
fi

# Optional sofortiges Update
read -p "Jetzt sofort 'apt update && upgrade -y' ausführen? (y/n): " do_update
if [[ "$do_update" == "y" ]]; then
  echo "Führe Update & Upgrade aus..."
  apt update && apt upgrade -y
  echo "🟢 System aktualisiert."
fi
