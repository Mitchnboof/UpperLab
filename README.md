# UpperLab

Single source of truth for the trading homelab. Every machine pulls from here; secrets live in `.env` files on the boxes, never in git.

## Layout

| Layer | Where | What |
|---|---|---|
| Brain | this repo | compose files, scripts, strategies, docs |
| Hands | control node (nuc-02) | always-on Claude remote-control, SSH keys to all boxes (Portainer server stays on BPC-2000 for now) |
| Workers | BPC-2000, NUC, HP mini, HP laptop | Docker + Portainer Agent, run bot stacks |
| Storage | QNAP NAS | shared market data, backtest results, nightly DB backups |

## Machines

Core (rack):

| Host | IP | CPU | RAM | Disk | Role | Status |
|---|---|---|---|---|---|---|
| nuc-02 (NUC i5) | 192.168.1.25 | i5 | 8 GB | 120 GB | Trade machine + control node | New fan fitted, bootstrapped, 46°C under load |
| Phonenix-BPC-2000 | 192.168.1.161 | ? | 7.6 GB | 136 GB | Trade machine (live swarm), Portainer server, bitcoind | Running, RAM maxed |
| QNAP NAS | ? | | | ? | Storage: market data, backtest results, backups | Running |
| nuc-01 | ? | ? | ? | ? | Home Assistant — house brain | **Not managed here**: no scripts, no bots |

Worker nodes (extra capacity: backtests, parallel dry-runs):

| Host | IP | CPU | RAM | Disk | Role | Status |
|---|---|---|---|---|---|---|
| hp-mini (HP i5 mini desktop) | TBD | i5 | ? | ? | Worker node | Needs repair |
| hplappy1 (HP laptop) | 192.168.1.29 (Wi-Fi) | ? | ? | ? | Worker node + **temporary control node** while nuc-02 is in repair | Bootstrapped, Portainer agent up, claude-remote service running |

Notes:
- 120 GB disk on the NUC: no bitcoind there (a full node is 700 GB+; pruned is possible but not worth it). Keep market data on the NAS.
- BPC-2000 display: driver/MATE pick 1080i@100 (unsupported → black screen). Forced to 1080p60 in two places: login screen via `/etc/lightdm/lightdm.conf.d/90-hdmi-1080p.conf`, desktop session via `~/.config/autostart/force-1080p.desktop`. Quick fix over SSH: `DISPLAY=:0 XAUTHORITY=~/.Xauthority xrandr --output HDMI-1 --mode 1920x1080 --rate 60`

## Adding a worker

1. Install Ubuntu Server 26.04 LTS (skip the featured snaps; enable OpenSSH during install). Reserve its IP in the router.
2. SSH in, then pull this repo onto the box (no copy-pasting files):
   ```bash
   sudo apt-get install -y gh
   gh auth login --hostname github.com --git-protocol https --web   # enter the code at github.com/login/device
   gh repo clone Mitchnboof/UpperLab
   sudo bash UpperLab/scripts/bootstrap-node.sh <hostname> 2>&1 | tee bootstrap.log
   ```
   Laptop: add `--laptop` so it keeps running with the lid shut.
3. Portainer → Environments → Add → Docker Standalone → Agent → `<ip>:9001`.
4. Add the box to `inventory/hosts` and the machines table above.

## Control node (nuc-02)

After `bootstrap-node.sh nuc-02`, run as your normal user (not sudo):

```bash
bash UpperLab/scripts/setup-control-node.sh
```

It reuses the GitHub login and `~/UpperLab` clone from step 2, makes an SSH key and copies it to every box in `inventory/hosts`, then runs `claude remote-control` as a systemd user service so the box is always in the Claude app.
