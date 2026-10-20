#!/bin/sh
# Refresh the knowledge base index daily. Silent on success.
set -u
cd /opt/data/workstation/kb || exit 1
if ! python3 index.py >/dev/null 2>&1; then
    echo "kb index refresh FAILED - check /opt/data/workstation/kb/index.py"
    exit 1
fi
exit 0
