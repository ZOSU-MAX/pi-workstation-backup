#!/bin/sh
# Daily offsite backup to GitHub. Silent on success.
set -u
cd /opt/data/workstation/backup || exit 1

if ! python3 run.py >/dev/null 2>&1; then
    echo "offsite backup FAILED - check /opt/data/workstation/backup/run.py"
    exit 1
fi
exit 0
