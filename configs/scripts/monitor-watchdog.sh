#!/bin/sh
# Cron watchdog for the Pi workstation monitor daemon.
# Silent when healthy; speaks up when it had to restart it.
# (no_agent cron job: empty stdout sends nothing.)
set -u
DIR=/opt/data/workstation/monitor
cd "$DIR" || exit 1

PID=$(cat data/daemon.pid 2>/dev/null || true)
if [ -n "${PID:-}" ] && kill -0 "$PID" 2>/dev/null; then
    exit 0
fi

python3 daemon.py >/dev/null 2>&1 &
sleep 2

NEW=$(cat data/daemon.pid 2>/dev/null || true)
if [ -n "${NEW:-}" ] && kill -0 "$NEW" 2>/dev/null; then
    echo "monitor daemon was down - restarted (pid=$NEW)"
else
    echo "monitor daemon FAILED to restart - investigate"
fi
