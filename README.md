# disableIpV6_cronjob_update.sh

Dieses Bash-Skript deaktiviert IPv6 in einem LXC-Container und richtet einen täglichen Cronjob für automatische Systemupdates ein.

## Installation und Ausführung

```bash
git clone https://github.com/vancaude/proxmox-scripts.git

cd proxmox-scripts/scripts

chmod +x disableIpV6_cronjob_update.sh

./disableIpV6_cronjob_update.sh

