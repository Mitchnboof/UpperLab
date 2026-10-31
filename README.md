# homelab

Single source of truth for the trading homelab. Every machine pulls from here; secrets live in `.env` files on the boxes, never in git.

## Layout

| Layer | Where | What |
|---|---|---|
| Brain | this repo | compose files, scripts, strategies, docs |
| Hands | control node (HP mini i5) | always-on Claude remote-control, SSH keys to all boxes, Portainer hub |
| Workers | BPC-2000, NUC, HP laptop | Docker + Portainer Agent, run bot stacks |
| Storage | QNAP NAS | shared market data, backtest results, nightly DB backups |

## Machines

| Host | IP | CPU | RAM | Disk | Role | Status |
|---|---|---|---|---|---|---|
| Phonenix-BPC-2000 | 192.168.1.161 | ? | 7.6 GB | 136 GB | Live freqtrade swarm, Portainer server, bitcoind | Running, RAM maxed |
| NUC i5 | TBD | i5 | 8 GB | 120 GB | Bot worker / parallel dry-runs | To deploy |
| HP mini i5 | TBD | i5 | ? | ? | Control node + bots | To deploy |
| HP laptop | TBD | ? | ? | ? | Backtest grinder | To deploy |

Notes:
- 120 GB disk on the NUC: no bitcoind there (a full node is 700 GB+; pruned is possible but not worth it). Keep market data on the NAS.
- BPC-2000 display: forced to 1080p60 via `/etc/lightdm/lightdm.conf.d/90-hdmi-1080p.conf` (the driver picked 1080i@100 after a crash → black screen).

## Adding a worker

1. Install Ubuntu Server 24.04 (enable OpenSSH during install). Reserve its IP in the router.
2. On the box:
   ```bash
   curl -fsSL <raw url>/scripts/bootstrap-node.sh -o bootstrap-node.sh
   sudo bash bootstrap-node.sh nuc-01
   ```
   Laptop: add `--laptop` so it keeps running with the lid shut.
3. Portainer → Environments → Add → Docker Standalone → Agent → `<ip>:9001`.
4. Update the machines table above.
