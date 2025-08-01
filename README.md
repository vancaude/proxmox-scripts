# Kleine Proxmox Helferscripte

```bash
git clone https://github.com/vancaude/proxmox-scripts.git
```
```bash
cd proxmox-scripts/scripts
```

### IPv6 deaktivieren und automatische Updates aktivieren - disableIpV6_cronjob_update.sh

```bash
chmod +x disableIpV6_cronjob_update.sh
```
```bash
./disableIpV6_cronjob_update.sh
```

### Docker + Docker-Compose installieren - docker_install.sh

```bash
chmod +x docker_install.sh
```
```bash
./docker_install.sh
```

### Proxmox - No valid subscription popup removal
Tested with Proxmox VE 8.4.5

```bash
chmod +x no_subscription_popup.sh
```
```bash
./no_subscription_popup.sh
```
The script adds additionally a cronjob which executes the script every day at 05:00AM.