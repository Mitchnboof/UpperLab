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
| nuc-02 (NUC i5) | 192.168.1.25 | i5 | 8 GB | 120 GB | Trade machine + control node | On repair bench (fan died, overheated mid-bootstrap) — re-run bootstrap-node.sh when back |
| Phonenix-BPC-2000 | 192.168.1.161 | ? | 7.6 GB | 136 GB | Trade machine (live swarm), Portainer server, bitcoind | Running, RAM maxed |
| QNAP NAS | ? | | | ? | Storage: market data, backtest results, backups | Running |
| nuc-01 | ? | ? | ? | ? | Home Assistant — house brain | **Not managed here**: no scripts, no bots |

Worker nodes (extra capacity: backtests, parallel dry-runs):

| Host | IP | CPU | RAM | Disk | Role | Status |
|---|---|---|---|---|---|---|
| hp-mini (HP i5 mini desktop) | TBD | i5 | ? | ? | Worker node | Needs repair |
| hp-laptop | TBD | ? | ? | ? | Worker node | Ex-work unit, USB boot locked in BIOS |

Notes:
- 120 GB disk on the NUC: no bitcoind there (a full node is 700 GB+; pruned is possible but not worth it). Keep market data on the NAS.
- BPC-2000 display: forced to 1080p60 via `/etc/lightdm/lightdm.conf.d/90-hdmi-1080p.conf` (the driver picked 1080i@100 after a crash → black screen).

## Adding a worker

1. Install Ubuntu Server 24.04 (enable OpenSSH during install). Reserve its IP in the router.
2. Get the script onto the box (repo is private, so no plain curl). SSH in, run `nano bootstrap-node.sh`,
   paste the contents of `scripts/bootstrap-node.sh` from GitHub (open the file → copy raw), save with
   Ctrl+O, Enter, Ctrl+X. Then:
   ```bash
   sudo bash bootstrap-node.sh nuc-03
   ```
   Once the control node exists, it pushes this to new boxes over SSH instead.
   Laptop: add `--laptop` so it keeps running with the lid shut.
3. Portainer → Environments → Add → Docker Standalone → Agent → `<ip>:9001`.
4. Add the box to `inventory/hosts` and the machines table above.

## Control node (nuc-02)

After `bootstrap-node.sh nuc-02`, run as your normal user (not sudo):

```bash
bash ~/UpperLab/scripts/setup-control-node.sh
```

First time there's no clone yet, so paste it in with nano like the bootstrap script. It logs in to GitHub, clones this repo to `~/UpperLab`, makes an SSH key and copies it to every box in `inventory/hosts`, then runs `claude remote-control` as a systemd user service so the box is always in the Claude app.
