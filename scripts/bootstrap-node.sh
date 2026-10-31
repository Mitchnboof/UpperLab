#!/usr/bin/env bash
# Bootstrap a fresh Ubuntu Server 24.04 box as a homelab Docker worker.
#
# Usage (on the new machine, as your normal user):
#   curl -fsSL <raw url of this file> -o bootstrap-node.sh
#   sudo bash bootstrap-node.sh <hostname> [--laptop]
#
# What it does:
#   - sets hostname + timezone, installs base tools
#   - installs Docker with log rotation (small disks fill up fast otherwise)
#   - starts a Portainer Agent so the box shows up in the main Portainer
#   - firewall: SSH + agent + freqtrade UI ports, LAN only
#   - --laptop: keeps running with the lid closed
#
# Give the box a fixed IP with a DHCP reservation in the router, not here.
set -euo pipefail

HOSTNAME_NEW="${1:-}"
LAPTOP=false
[[ "${2:-}" == "--laptop" ]] && LAPTOP=true

LAN_CIDR="${LAN_CIDR:-192.168.1.0/24}"
TIMEZONE="${TIMEZONE:-Australia/Perth}"
# Must match the Portainer server version (server runs portainer-ce:lts)
PORTAINER_AGENT_TAG="${PORTAINER_AGENT_TAG:-lts}"
FREQTRADE_PORTS="${FREQTRADE_PORTS:-8080:8099}"

if [[ $EUID -ne 0 ]]; then
  echo "Run with sudo: sudo bash $0 <hostname> [--laptop]" >&2
  exit 1
fi
if [[ -z "$HOSTNAME_NEW" ]]; then
  echo "Usage: sudo bash $0 <hostname> [--laptop]" >&2
  exit 1
fi
REAL_USER="${SUDO_USER:-$USER}"

echo "==> Hostname / timezone"
hostnamectl set-hostname "$HOSTNAME_NEW"
timedatectl set-timezone "$TIMEZONE"

echo "==> Base packages"
apt-get update -q
DEBIAN_FRONTEND=noninteractive apt-get upgrade -yq
DEBIAN_FRONTEND=noninteractive apt-get install -yq \
  curl git tmux htop ufw nfs-common unattended-upgrades ca-certificates

echo "==> Docker"
if ! command -v docker >/dev/null; then
  curl -fsSL https://get.docker.com | sh
fi
usermod -aG docker "$REAL_USER"
mkdir -p /etc/docker
cat > /etc/docker/daemon.json <<'EOF'
{
  "log-driver": "json-file",
  "log-opts": { "max-size": "20m", "max-file": "3" }
}
EOF
systemctl restart docker

echo "==> Portainer Agent"
docker rm -f portainer_agent >/dev/null 2>&1 || true
docker run -d --name portainer_agent --restart=always \
  -p 9001:9001 \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v /var/lib/docker/volumes:/var/lib/docker/volumes \
  -v /:/host \
  "portainer/agent:${PORTAINER_AGENT_TAG}"

echo "==> Firewall (LAN only)"
ufw default deny incoming
ufw default allow outgoing
ufw allow from "$LAN_CIDR" to any port 22 proto tcp
ufw allow from "$LAN_CIDR" to any port 9001 proto tcp
ufw allow from "$LAN_CIDR" to any port "$FREQTRADE_PORTS" proto tcp
ufw --force enable

if $LAPTOP; then
  echo "==> Laptop: ignore lid close, never sleep"
  sed -i -E 's/^#?HandleLidSwitch(ExternalPower|Docked)?=.*/HandleLidSwitch\1=ignore/' /etc/systemd/logind.conf
  grep -q '^HandleLidSwitch=' /etc/systemd/logind.conf || echo 'HandleLidSwitch=ignore' >> /etc/systemd/logind.conf
  systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target
  systemctl restart systemd-logind
fi

IP="$(hostname -I | awk '{print $1}')"
echo
echo "Done. ${HOSTNAME_NEW} is at ${IP}"
echo "Next: Portainer (https://192.168.1.161:9443) -> Environments -> Add -> Docker Standalone -> Agent"
echo "      Environment address: ${IP}:9001"
echo "Log out and back in so '${REAL_USER}' can run docker without sudo."
