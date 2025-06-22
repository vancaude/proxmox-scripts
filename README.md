# disableIpV6_cronjob_update.sh

Dieses Bash-Skript deaktiviert auf Wunsch IPv6 in einem LXC-Container, richtet einen täglichen Cronjob für automatische Systemupdates ein und bietet optional die sofortige Ausführung von `apt update && apt upgrade -y`.

## Installation und Ausführung

```bash
git clone https://github.com/vancaude/proxmox-scripts.git
cd proxmox-scripts/scripts
chmod +x disableIpV6_cronjob_update.sh
./disableIpV6_cronjob_update.sh