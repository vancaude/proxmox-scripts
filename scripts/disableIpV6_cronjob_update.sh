#!/bin/bash
set -euo pipefail

echo "===== LXC Setup Script – IPv6 & Auto-Update (systemweit) ====="

# --- Helpers ----------------------------------------------------

require_root() {
  if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
    echo "Dieses Skript muss als root laufen. Bitte mit sudo ausführen."
    exit 1
  fi
}

yesno() {
  # usage: yesno "Frage" "default"
  # default: y|n
  local prompt default reply
  prompt="$1"
  default="${2:-y}"
  if [[ "$default" == "y" ]]; then
    read -r -p "$prompt [Y/n]: " reply || true
    reply="${reply:-y}"
  else
    read -r -p "$prompt [y/N]: " reply || true
    reply="${reply:-n}"
  fi
  [[ "${reply,,}" == "y" || "${reply,,}" == "yes" ]]
}

in_container() {
  # mehrere Checks: systemd-detect-virt, /proc/1/environ, cgroup
  if command -v systemd-detect-virt >/dev/null 2>&1; then
    if systemd-detect-virt -cq; then
      return 0
    fi
  fi
  if [[ -f /proc/1/environ ]] && grep -qa 'container=' /proc/1/environ; then
    return 0
  fi
  if grep -qE ':/lxc/|:/docker/|:/podman/' /proc/1/cgroup 2>/dev/null; then
    return 0
  fi
  return 1
}

ensure_pkg() {
  # installiere Paket nur wenn nötig
  local pkg="$1"
  dpkg -s "$pkg" >/dev/null 2>&1 || apt-get update -y && apt-get install -y "$pkg"
}

write_if_changed() {
  # schreibt Datei nur, wenn Inhalt sich ändert
  local path="$1"
  local tmp
  tmp="$(mktemp)"
  cat >"$tmp"
  if [[ ! -f "$path" ]] || ! cmp -s "$tmp" "$path"; then
    install -m "$(stat -c '%a' "$path" 2>/dev/null || echo 644)" -o root -g root /dev/null "$path" 2>/dev/null || true
    cat "$tmp" >"$path"
    echo "Aktualisiert: $path"
  else
    echo "Unverändert: $path"
  fi
  rm -f "$tmp"
}

# --- 0. Root & Container-Check ---------------------------------

require_root

if ! in_container; then
  if ! yesno "WARNUNG: Es sieht nicht nach einem Container aus. Trotzdem fortfahren?" "n"; then
    exit 1
  fi
fi

export DEBIAN_FRONTEND=noninteractive

# --- 1. IPv6 deaktivieren (optional, sauber via sysctl.d) ------
if yesno "Möchtest du IPv6 deaktivieren?" "n"; then
  CONF="/etc/sysctl.d/99-disable-ipv6.conf"
  mkdir -p /etc/sysctl.d
  cat <<'EOF' | write_if_changed "$CONF"
# Automatisch erstellt von lxc-setup.sh
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
EOF
  sysctl --system >/dev/null
  echo "IPv6 wurde (über sysctl.d) deaktiviert."
else
  echo "IPv6 bleibt aktiv."
fi

# --- 2. Tägliche Auto-Updates via /etc/cron.d ------------------

if yesno "Systemweiten Cronjob für tägliche apt-Updates einrichten?" "y"; then
  # Uhrzeit abfragen (Standard 04:00)
  read -r -p "Uhrzeit im Format HH:MM (Standard 04:00): " RUN_AT || true
  RUN_AT="${RUN_AT:-04:00}"
  if [[ ! "$RUN_AT" =~ ^([01][0-9]|2[0-3]):([0-5][0-9])$ ]]; then
    echo "Ungültige Uhrzeit. Verwende 04:00."
    RUN_AT="04:00"
  fi
  HOUR="${RUN_AT%:*}"
  MIN="${RUN_AT#*:}"

  # sicherstellen, dass cron läuft
  ensure_pkg cron || true
  systemctl enable --now cron >/dev/null 2>&1 || true

  # Hilfsscript
  UPG_SCRIPT="/usr/local/sbin/apt-auto-upgrade.sh"
  install -d -m 755 /usr/local/sbin
  cat <<'EOF' | write_if_changed "$UPG_SCRIPT"
#!/bin/bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

LOCK="/var/run/apt-auto-upgrade.lock"
LOG="/var/log/apt/cron-upgrade.log"

mkdir -p "$(dirname "$LOG")"

# nice/ionice, flock gegen Parallel-Läufe
exec 9> "$LOCK"
if ! flock -n 9; then
  echo "$(date -Is) – läuft bereits, überspringe." >>"$LOG"
  exit 0
fi

{
  echo "===== $(date -Is) ====="
  apt-get update -y
  apt-get upgrade -y
  echo
} >>"$LOG" 2>&1
EOF
  chmod 755 "$UPG_SCRIPT"

  # Cronjob in /etc/cron.d
  CRON_FILE="/etc/cron.d/apt-auto-upgrade"
  cat <<EOF | write_if_changed "$CRON_FILE"
SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin

# Täglich um $RUN_AT als root
$MIN $HOUR * * * root /usr/local/sbin/apt-auto-upgrade.sh
EOF
  chmod 644 "$CRON_FILE"

  echo "Systemweiter Cronjob eingerichtet: täglich um $RUN_AT."
else
  echo "Kein systemweiter Cronjob eingerichtet."
fi

# --- 3. Sofortiges Update (optional) ---------------------------

if yesno "Jetzt sofort 'apt-get update && apt-get -y upgrade' ausführen?" "n"; then
  echo "Führe Update & Upgrade aus …"
  apt-get update -y
  apt-get upgrade -y
  echo "System aktualisiert."
fi

# --- 4. Aufräumen (optional, wie bei dir) ----------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
if [[ "$(basename "$REPO_ROOT")" == "proxmox-scripts" ]]; then
  if yesno "Repository-Verzeichnis '$REPO_ROOT' löschen?" "n"; then
    rm -rf -- "$REPO_ROOT"
    echo "Verzeichnis entfernt."
  fi
fi

echo "===== Fertig. ====="
