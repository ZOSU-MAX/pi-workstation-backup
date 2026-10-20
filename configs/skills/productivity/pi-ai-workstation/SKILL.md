---
name: pi-ai-workstation
description: "Use when working on the Pi AI workstation or its gateway."
version: 1.0.0
author: Hermes Agent
license: MIT
platforms: [linux]
metadata:
  hermes:
    tags: [RaspberryPi, Workstation, Gateway, Monitoring, Ops]
    related_skills: [codex, opencode]
---

# Pi AI Workstation

Runbook for the Raspberry Pi 4B (2GB, arm64) that hosts this Hermes profile.
Everything lives under `/opt/data/workstation/`.

## When to Use

- The user asks about the Pi workstation, its services, or "is X still running?"
- Working on the OpenAI gateway (:8080), the metrics monitor, or their watchdogs
- Something on the Pi needs restarting, debugging, or a config change
- LAN access to a container-hosted service stops working

## What is deployed

| Component | Location | How to check |
|---|---|---|
| Hermes agent | container `hermes` | `docker ps | grep hermes` |
| Relay gateway | container `relay-gateway` (:8000) | `curl localhost:8000/health` |
| Knowledge base (wiki) | `/opt/data/home/wiki/` | Obsidian vault, LLM Wiki format |
| Backup | `/opt/data/backups/workstation/` | `bash /opt/data/scripts/backup.sh` |
| Fonts | `/opt/data/fonts/` | Chinese fonts for FFmpeg |
| Skills | `/opt/data/skills/` | Synced to GitHub backup |

## Monitor

```
cd /opt/data/workstation/monitor
python3 status.py          # current snapshot (mem/temp/disk/load)
python3 status.py --history # last 12 samples
python3 status.py --top     # top memory consumers
python3 render.py           # regenerate index.html
./ensure.sh --status         # is the daemon alive?
./ensure.sh                 # start it if not
```

Daemon collects every 5 min into `data/history.jsonl` (rotated to ~288 lines).
`index.html` is the browser view.

## Gateway (:8080)

OpenAI-compatible proxy to the configured upstream relays. Stdlib only.

```
cd /opt/data/workstation/gateway
./ensure.sh --status
python3 gateway.py          # foreground
```

Endpoints: `/health`, `/stats`, `/v1/models`, `/v1/chat/completions`,
`/v1/responses`, `/v1/embeddings`. Non-streaming responses are cached on disk
(`data/cache/`); every call is appended to `data/requests.jsonl`.

Config: `config.json` — `upstreams[]` with `name`, `base_url`, `api_key`
(`env:VAR` or literal) and `models`. Adding an upstream is the way to remove the
single-point-of-failure on the relay.

## Backup (daily, GitHub private repo)

Shell-based backup that runs daily at 03:00 via Hermes cron (`daily-backup`).

```
bash /opt/data/scripts/backup.sh    # full backup + push
```

Repo: `ZOSU-MAX/pi-workstation-backup` (GitHub private). Backup includes:
- System config (.profile, .codex, .hermes, config.yaml)
- Docker projects, user projects (rsync excluding node_modules/.git/cache)
- Skills, fonts, scripts, crontab, network config
- Installed software inventory

Restore on a new SD card:
```bash
git clone https://github.com/ZOSU-MAX/pi-workstation-backup.git /tmp/restore
sudo bash /tmp/restore/scripts/restore.sh
sudo reboot
```

### Critical: GitHub requires proxy

The Pi cannot reach GitHub directly (TLS timeout). All git operations MUST use
the proxy:
```bash
git -c http.proxy=http://192.168.0.102:7897 push origin master
```
The backup script has this baked in. Restore's clone also uses it.

### Fresh git init each run

The backup script does `rm -rf .git && git init` before each push to avoid
history conflicts from previous partial pushes. This means the remote history
is always a single commit — intentional for a backup repo.

### Path conventions

- `.profile` lives at `/opt/data/home/.profile` (not `/opt/data/.profile`)
- Restore puts it back to `home/.profile`
- Hermes config is at `/opt/data/config.yaml` (not `/opt/data/.hermes/config.yaml`)
- rsync excludes: node_modules, .git, __pycache__, *.pyc, .venv, dist, build, .cache

## Keepalive (cron watchdogs)

Both daemons are watched by `no_agent` cron jobs that run a script and stay
silent unless they had to restart something:

- `monitor-daemon-watchdog` — hourly, script `monitor-watchdog.sh`
- `gateway-watchdog` — every 30 min, script `gateway-watchdog.sh`

Scripts live in `/opt/data/scripts/` (cron requires that path). The gateway
watchdog falls back to reading `OPENAI_API_KEY` from `~/.profile` because the
cron environment does not carry it.

- `kb-index-refresh` — daily 03:00, script `kb-index-refresh.sh`
- `offsite-backup` — daily 04:00, script `backup-run.sh`

## Backup

`backup/run.py` mirrors selected host paths into `backup/repo/` and pushes to the
GitHub remote. Full runbook, restore procedure and pitfalls:
**`references/offsite-backup.md`**.

Quick check:

```
cd /opt/data/workstation/backup
python3 run.py --status
```

## Host-side networking

The container is on Docker's bridge (`172.17.0.2`), which LAN devices cannot
route to. The gateway is exposed to the LAN by a socat forwarder **on the Pi
host** (systemd unit `pi-gateway-forward`: `host:8080 -> 172.17.0.2:8080`).

### Know which side you are on

The user sometimes runs commands over SSH **on the Pi host**, not inside the
container. On the host, `/opt/data` does not exist — the same tree is at
`/home/jian/.hermes`. A `cd /opt/data/projects` that "worked before" failing
with "No such file or directory" usually means the command ran on the host.

The tell: a `python3 -m http.server` whose `/` listing shows `.X11-unix`,
`systemd-private-*` and `ssh-*` directories is serving the **host's** `/tmp`,
not the container's (the container's `/tmp` is a bare overlay dir). A server on
the host at `0.0.0.0:<port>` is already LAN-reachable at the Pi's LAN IP — no
forwarder needed. Verify by curling `172.17.0.1:<port>` from inside the
container: that reaches the host.

So for "hand a file to my phone": if the user's server is on the host, put the
file under the host's tree (`/home/jian/.hermes/...`, i.e. `/opt/data/...`
inside the container — same filesystem) and serve it from there. Do NOT
recommend adding a socat forwarder for a server that is already on the host.

If the container IP changes (container recreated), update that unit and
`systemctl restart pi-gateway-forward`. The durable fix is publishing the port
at container creation (`docker run -p 8080:8080`), which needs a container
restart and interrupts the running gateway.

There is no general way to hand a LAN device a file from inside the container.
`/opt/data` is a bind mount of the host's `/home/jian/.hermes` (`/dev/mmcblk0p2`),
so anything written there is already host-visible — the copy under
`/opt/data/pastes/` is the one to hand over. A `python3 -m http.server` started
in the container does NOT help: it serves the container's own filesystem and is
only reachable at `172.17.0.2:<port>`, which the LAN cannot route to (verified:
`172.17.0.1:9000` refused). If the LAN needs a file over HTTP, add a second
socat/systemd forwarder on the host; do not claim an in-container HTTP server
"serves it to the LAN".

## Hermes dashboard (port 9119) — how to actually turn it off

The dashboard costs ~190MB of RAM on a 2GB box, so it is worth disabling.
**Deleting its s6-rc bundle entry does NOT work** — do not tell the user it does.

The dashboard is an *always declared* supervised slot: its run script exits
immediately unless the environment variable `HERMES_DASHBOARD` is truthy. The
bundle file `/opt/hermes/docker/s6-rc.d/user/contents.d/dashboard` is not the
switch; removing it changes nothing, and the service comes back on the next
container start.

Control it in order of durability:

1. **Permanent** — pass the env var when starting the container:
   `docker run -e HERMES_DASHBOARD=0 ...`, or in compose
   `environment: ["HERMES_DASHBOARD=0"]`. Needs a container restart.
2. **Until next container start** — stop the supervised service:
   `/package/admin/s6-2.15.0.0/command/s6-svc -d /run/service/dashboard`
3. **Re-enable** — `s6-svc -u /run/service/dashboard`

Verify with `ps aux | grep "[d]ashboard --host"` and `free -h` (available memory
should jump ~200MB).

The live value sits at `/run/s6/container_environment/HERMES_DASHBOARD`, which
is regenerated at container start — editing that file is not durable.

## Gotchas

- No system cron inside the container — use the Hermes cron watchdogs above.
- `pkill -f <pattern>` will match and kill the shell running the command if the
  pattern appears in it. Match the PID instead: `ps aux | grep "[p]attern"`.
- The gateway and monitor bind `0.0.0.0`; only the host-side forwarder decides
  what the LAN can reach.
- `zip` is NOT installed in this container (no `zip`, no `unzip`, no `pip`, no
  `sudo`). Build archives with the stdlib: `python3 -c "import shutil;
  shutil.make_archive('/tmp/out','zip','.','srcdir')"`. `python3 -m zipfile -e`
  extracts. `/tmp` inside the container is on the overlay, not the bind mount —
  a server started there is invisible to the LAN and lost on restart.
- A backup repo placed inside an include root backs itself up and grows without
  bound — see `references/offsite-backup.md`.
- Deleting an s6-rc bundle entry does not disable an *always declared* service.
  Find the env var it actually gates on before calling a change permanent, and
  judge permanence by what the next container start will do — not by the absence
  of an immediate error. A change that silently reverts on reboot is worse than
  no change, because the user stops trusting the fix.

## Rules

1. Check `./ensure.sh --status` before assuming a daemon is down.
2. Prefer `python3 <script>.py` for one-off runs; daemons are for continuous work.
3. Verify a fix by reading the service's own stats/log, not by intent.
4. When adding an upstream, test it with a real completion before trusting it.
5. Report progress proactively — do NOT wait for the user to ask "怎么样了".
   Long-running work gets a progress line before it starts. When a step runs
   silently for more than a minute, send a status update. When an error
   occurs, report it immediately with the fix being attempted. The user
   explicitly corrected this: "有情况要即使向我汇报 不要问我".
6. Before making a change that has a cost (stopping a service, editing a config,
   changing a remote), state the benefit and the cost in plain terms first. The
   user decides after seeing both and will ask "what are the consequences?" —
   do not execute first and explain after.
7. When handing over a command, say explicitly whether it runs inside the
   container or on the Pi host. The two differ in permissions (no sudo inside)
   and in network reach, and an ambiguous instruction draws a "which one?"
   follow-up before any work happens.
