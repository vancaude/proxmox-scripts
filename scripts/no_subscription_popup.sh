#!/usr/bin/env bash

set -euo pipefail

echo "===== Disable Proxmox Subscription Notice ====="

# 1. check root privilege
if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root."
  exit 1
fi

# 2. check javascript file
PKG_DIR="/usr/share/javascript/proxmox-widget-toolkit"
JS_FILE=$(find "$PKG_DIR" -type f -name "*.js" -exec grep -l "No valid subscription" {} + | head -n1)

if [[ -z "$JS_FILE" ]]; then
  echo "Could not find the JavaScript file. The path may have changed."
  exit 1
fi
echo "Found file: $JS_FILE"

# 3. patch - if needed
PATTERN="data.status.toLowerCase() !== 'active'"
if grep -q "$PATTERN" "$JS_FILE"; then
  TIMESTAMP="$(date +%F_%H-%M-%S)"
  BACKUP_FILE="${JS_FILE}.bak.${TIMESTAMP}"
  cp "$JS_FILE" "$BACKUP_FILE"
  echo "Backup created: $BACKUP_FILE"

  sed -i -E "s/${PATTERN}/false/g" "$JS_FILE"
  echo "Patch applied."

  # keep only the five newest backups
  ls -1t "${JS_FILE}".bak.* 2>/dev/null | tail -n +6 | xargs -r rm -f
  CHANGED=1
else
  echo "File already patched – nothing to do."
  CHANGED=0
fi

# 4. restart if needed 
if [[ $CHANGED -eq 1 ]]; then
  systemctl restart pveproxy.service
  echo "pveproxy restarted."
fi

# 5. optional Cronjob for daily script
if [[ "${1-}" != "--silent" ]]; then
  read -r -p "Create a daily cron job at 05:00? [y/N] " answer
  if [[ "$answer" =~ ^[Yy]$ ]]; then
    CRON_FILE="/etc/cron.d/no_subscription_popup"
    SCRIPT_PATH="$(realpath "$0")"

    cat >"$CRON_FILE" <<EOF
0 5 * * * root $SCRIPT_PATH --silent >> /var/log/no_subscription_popup.log 2>&1
EOF
    chmod 644 "$CRON_FILE"

    if [[ -f "$CRON_FILE" ]]; then
      echo "Cron job installed at $CRON_FILE."
    else
      echo "Error: Failed to create cron job."
    fi
  fi
fi

echo "Done. If the banner is still visible, clear your browser cache (Ctrl+F5)."
