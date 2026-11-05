#!/usr/bin/env bash
# Mount the QNAP "upperlab" NFS share at /mnt/nas on this box.
#
# Usage:
#   sudo bash mount-nas.sh <nas-ip> [export-path]     (export-path defaults to /upperlab)
#
# Safe to re-run. Uses automount + nofail, so a box still boots (and its bots
# still start) if the NAS is off; /mnt/nas just reconnects when it's back.
set -euo pipefail

NAS_IP="${1:-}"
EXPORT="${2:-/upperlab}"
MOUNT_POINT="/mnt/nas"

if [[ $EUID -ne 0 ]]; then
  echo "Run with sudo: sudo bash $0 <nas-ip> [export-path]" >&2
  exit 1
fi
if [[ -z "$NAS_IP" ]]; then
  echo "Usage: sudo bash $0 <nas-ip> [export-path]" >&2
  exit 1
fi

echo "==> NFS client"
command -v mount.nfs >/dev/null || DEBIAN_FRONTEND=noninteractive apt-get install -yq nfs-common </dev/null

echo "==> /etc/fstab"
mkdir -p "$MOUNT_POINT"
sed -i '/# UpperLab NAS/d' /etc/fstab
echo "${NAS_IP}:${EXPORT} ${MOUNT_POINT} nfs rw,_netdev,nofail,x-systemd.automount,x-systemd.mount-timeout=15,timeo=150,retrans=3 0 0  # UpperLab NAS" >> /etc/fstab
systemctl daemon-reload
systemctl restart remote-fs.target

echo "==> Test"
if ! ls "$MOUNT_POINT" >/dev/null 2>&1; then
  echo "Could not open ${NAS_IP}:${EXPORT}. Check the NFS permissions on the QNAP include this box's IP ($(hostname -I | awk '{print $1}'))." >&2
  exit 1
fi
mkdir -p "$MOUNT_POINT"/{market-data,backtests,backups}
TEST_FILE="$MOUNT_POINT/backups/.write-test-$(hostname)"
if touch "$TEST_FILE" 2>/dev/null; then
  rm -f "$TEST_FILE"
  echo "Done. ${NAS_IP}:${EXPORT} is mounted read/write at ${MOUNT_POINT}"
  ls -la "$MOUNT_POINT"
else
  echo "Mounted, but can't write. On the QNAP, set the NFS rule for this IP to read/write and 'no squash'." >&2
  exit 1
fi
