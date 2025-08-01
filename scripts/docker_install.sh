#!/bin/bash
set -euo pipefail

echo "===== Docker‑&‑Compose setup script ====="

# 1. root check
if [[ $EUID -ne 0 ]]; then
  echo "This script needs to run as root (sudo …)."
  exit 1
fi

# 2. docker check
if command -v docker &>/dev/null; then
  echo "Docker is already installed:"
  docker --version
  read -p "Start anyway? (y/n): " reinstall
  [[ "$reinstall" != "y" ]] && { echo "User stopped the install process."; exit 0; }
fi

# 3. system update
read -p "Do 'apt update && apt upgrade -y' first? (y/n): " do_full_up

# 4. remove old docker packages
echo "Remove old docker packages …"
for pkg in docker.io docker-doc docker-compose podman-docker containerd runc; do
  apt-get -qq remove --purge -y "$pkg" 2>/dev/null || true
done

# 5. requirements and docker repo
rm -f /etc/apt/sources.list.d/docker.list
rm -f /etc/apt/keyrings/docker.{asc,gpg}

apt-get update -qq
apt-get install -y ca-certificates curl gnupg lsb-release

install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg \
  | gpg --batch --yes --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" \
  | tee /etc/apt/sources.list.d/docker.list >/dev/null

apt-get update
[[ "$do_full_up" == "y" ]] && apt-get upgrade -y

# 6. Docker + Compose installation
apt-get install -y docker-ce docker-ce-cli containerd.io \
                   docker-buildx-plugin docker-compose-plugin
systemctl enable --now docker

# 7. add user to 'docker' group
TARGET_USER="${SUDO_USER:-root}"
if [[ "$TARGET_USER" != "root" ]]; then
  read -p "Should '$TARGET_USER' be added to user group 'docker' (without to use sudo)? (y/n): " add_grp
  if [[ "$add_grp" == "y" ]]; then
    usermod -aG docker "$TARGET_USER"
    echo "Please sign in again to activate privileges."
  fi
fi

# 8. Cleaning - removing folder
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(readlink -f "$SCRIPT_DIR/..")"
if [[ "$(basename "$REPO_ROOT")" == "proxmox-scripts" ]]; then
  read -p "Repository folder '$REPO_ROOT' delete? (y/n): " remove_repo
  if [[ "$remove_repo" == "y" ]]; then
    cd /
    rm -rf "$REPO_ROOT"
    echo "Deleted repository. Move to home folder"
    cd "$HOME"
    exec "$SHELL" -l
  fi
fi

echo "Installation done."