#!/usr/bin/env bash
set -euo pipefail

echo "===== Disable Proxmox Subscription Notice ====="

# 1. Root check
if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root."
  exit 1
fi

# 2. Locate JavaScript file
PKG_DIR="/usr/share/javascript/proxmox-widget-toolkit"
JS_FILE=$(find "$PKG_DIR" -type f -name "*.js" -exec grep -l "No valid subscription" {} + | head -n1)

if [[ -z "$JS_FILE" ]]; then
  echo "JavaScript file not found. Path may have changed."
  exit 1
fi

echo "Found JavaScript file: $JS_FILE"

# 3. Backup original file
TIMESTAMP="$(date +%F_%H-%M-%S)"
BACKUP_FILE="${JS_FILE}.bak.${TIMESTAMP}"
cp "$JS_FILE" "$BACKUP_FILE"
echo "Backup created at: $BACKUP_FILE"

# 4. Patch file
sed -E -i "s/data\.status\.toLowerCase\(\) !== 'active'/false/g" "$JS_FILE"

# 5. Check if patch was necessary
if cmp -s "$BACKUP_FILE" "$JS_FILE"; then
  echo "Already patched. No changes made."
  rm -f "$BACKUP_FILE"
else
  echo "Patch applied successfully."
fi

# 6. Restart service
systemctl restart pveproxy.service
echo "pveproxy restarted."


echo "Done. Please clear your browser cache (Ctrl+F5) if popup still appears."clear