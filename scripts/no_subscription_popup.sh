#!/usr/bin/env bash
# Removes the "No valid subscription" popup in Proxmox VE >= 8.4.x
# Tested with Proxmox 8.4.5

set -euo pipefail

PKG_DIR="/usr/share/javascript/proxmox-widget-toolkit"
TIMESTAMP="$(date +%F_%H-%M-%S)"
BACKUP_SUFFIX=".bak.${TIMESTAMP}"

echo "Locating the JavaScript file..."
JS_FILE=$(find "$PKG_DIR" -type f -name "*.js" -exec grep -l "No valid subscription" {} + | head -n1)

if [[ -z "$JS_FILE" ]]; then
  echo "JavaScript file not found. Path may have changed."
  exit 1
fi

echo "Found: $JS_FILE"
echo "Creating backup → ${JS_FILE}${BACKUP_SUFFIX}"
cp "$JS_FILE" "${JS_FILE}${BACKUP_SUFFIX}"

echo "Applying patch..."
sed -E -i \
  "s/data\.status\.toLowerCase\(\) !== 'active'/false/g" \
  "$JS_FILE"

# No change = already patched
if cmp -s "${JS_FILE}${BACKUP_SUFFIX}" "$JS_FILE"; then
  echo "Already patched. No changes made."
  rm -f "${JS_FILE}${BACKUP_SUFFIX}"
  exit 0
fi

echo "Restarting pveproxy..."
systemctl restart pveproxy.service

echo "Done. Please clear your browser cache or reload the page."
echo "Backup created at: ${JS_FILE}${BACKUP_SUFFIX}"
