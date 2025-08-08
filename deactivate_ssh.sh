#!/usr/bin/env bash
set -euo pipefail

echo "===== LXC Hardening Script – SSH Disable & Key-Only Auth ====="

# 1. container check
if [ ! -f /proc/1/environ ] || ! grep -qa 'container=' /proc/1/environ; then
  echo "WARNING: This script does not appear to be running inside a container."
  read -p "Continue anyway? (y/n): " confirm
  [[ $confirm != "y" ]] && exit 1
fi

# 2. disable password authentication
read -p "Disable password-based SSH authentication (public-key only)? (y/n): " disable_pass
if [[ "$disable_pass" == "y" ]]; then
  echo "Disabling password authentication …"
  cfg="/etc/ssh/sshd_config"
  cp "$cfg" "${cfg}.bak_$(date +%F_%T)"

  sed -i \
    -e 's/^[#[:space:]]*PasswordAuthentication.*/PasswordAuthentication no/' \
    -e 's/^[#[:space:]]*ChallengeResponseAuthentication.*/ChallengeResponseAuthentication no/' \
    "$cfg"

  # Root login: permit keys but no passwords
  if grep -qE '^[#[:space:]]*PermitRootLogin' "$cfg"; then
    sed -i 's/^[#[:space:]]*PermitRootLogin.*/PermitRootLogin prohibit-password/' "$cfg"
  else
    echo 'PermitRootLogin prohibit-password' >> "$cfg"
  fi

  echo "Password authentication disabled."
else
  echo "Password authentication left unchanged."
fi

# 3. stop / disable sshd
read -p "Stop and disable the SSH service entirely? (y/n): " disable_service
if [[ "$disable_service" == "y" ]]; then
  echo "Stopping and disabling SSH …"
  systemctl stop ssh || systemctl stop sshd
  systemctl disable ssh || systemctl disable sshd
  echo "SSH service disabled."
else
  echo "Reloading SSH to apply any configuration changes …"
  systemctl reload ssh || systemctl reload sshd \
    || systemctl restart ssh || systemctl restart sshd
fi

# 4. clean up – offer to remove repo folder
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
if [[ "$(basename "$REPO_ROOT")" == "proxmox-scripts" ]]; then
  read -p "Delete repository directory '$REPO_ROOT'? (y/n): " remove_repo
  if [[ "$remove_repo" == "y" ]]; then
    rm -rf "$REPO_ROOT"
    echo "Directory removed."
  fi
fi
