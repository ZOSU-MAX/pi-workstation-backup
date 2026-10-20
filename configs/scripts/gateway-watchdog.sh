#!/bin/sh
# Cron watchdog for the local OpenAI gateway (:8080).
# Silent when healthy; speaks up when it had to restart it.
# (no_agent cron job: empty stdout sends nothing.)
set -u
DIR=/opt/data/workstation/gateway
cd "$DIR" || exit 1

# The cron environment may not carry the key; fall back to the shell profile.
if [ -z "${OPENAI_API_KEY:-}" ] && [ -f "$HOME/.profile" ]; then
    KEY=$(sed -n 's/^.*OPENAI_API_KEY="\([^"]*\)".*/\1/p' "$HOME/.profile" | tail -1)
    [ -n "$KEY" ] && export OPENAI_API_KEY="$KEY"
fi

PID=$(cat data/gateway.pid 2>/dev/null || true)
if [ -n "${PID:-}" ] && kill -0 "$PID" 2>/dev/null; then
    exit 0
fi

KEY="${OPENAI_API_KEY:-}"
if [ -z "$KEY" ]; then
    echo "gateway is down and OPENAI_API_KEY is unset - cannot restart"
    exit 1
fi

python3 gateway.py >/dev/null 2>&1 &
sleep 2

NEW=$(cat data/gateway.pid 2>/dev/null || true)
if [ -n "${NEW:-}" ] && kill -0 "$NEW" 2>/dev/null; then
    echo "gateway was down - restarted (pid=$NEW)"
else
    echo "gateway FAILED to restart - investigate"
fi
