#!/bin/bash
set -euo pipefail

echo "===== Docker‑&‑Compose Setup‑Skript ====="

# 1. Root Prüfung
if [[ $EUID -ne 0 ]]; then
  echo "Dieses Skript muss als root ausgeführt werden (sudo …)."
  exit 1
fi

# 2. Docker‑Check
if command -v docker &>/dev/null; then
  echo "Docker ist bereits installiert:"
  docker --version
  read -p "Trotzdem fortfahren und neu installieren? (y/n): " reinstall
  [[ "$reinstall" != "y" ]] && { echo "Abbruch auf Wunsch des Nutzers."; exit 0; }
fi

# 3. Systemaktualisierung
read -p "System jetzt zuerst 'apt update && upgrade -y' ausführen? (y/n): " do_full_up
[[ "$do_full_up" == "y" ]] && apt update && apt upgrade -y

# 4. Alte Docker‑Pakete entfernen
echo "Entferne ggf. alte Docker‑Pakete …"
for pkg in docker.io docker-doc docker-compose podman-docker containerd runc; do
  apt-get -qq remove --purge -y "$pkg" 2>/dev/null || true
done

# 5. Voraussetzungen & Docker‑Repo
apt-get update
apt-get install -y ca-certificates curl gnupg lsb-release

install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg \
  | gpg --dearmor -o /etc/apt/keyrings/docker.asc

chmod a+r /etc/apt/keyrings/docker.asc

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \
https://download.docker.com/linux/debian $(lsb_release -cs) stable" \
  > /etc/apt/sources.list.d/docker.list

apt-get update

# 6. Docker & Compose Installation
apt-get install -y docker-ce docker-ce-cli containerd.io \
                   docker-buildx-plugin docker-compose-plugin
systemctl enable --now docker

# 7. Benutzer zur Gruppe 'docker' hinzufügen
read -p "Soll '$SUDO_USER' zur Gruppe 'docker' hinzugefügt werden? (y/n): " add_grp
[[ "$add_grp" == "y" ]] && { usermod -aG docker "$SUDO_USER"; echo "Bitte neu einloggen."; }

# 8. Aufräumen (Repo‑Ordner entfernen)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
if [[ "$(basename "$REPO_ROOT")" == "proxmox-scripts" ]]; then
  read -p "Repository‑Verzeichnis '$REPO_ROOT' löschen? (y/n): " remove_repo
  [[ "$remove_repo" == "y" ]] && { rm -rf "$REPO_ROOT"; echo "Verzeichnis entfernt."; }
fi

echo "Installation abgeschlossen."
