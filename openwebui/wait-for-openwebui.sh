#!/usr/bin/env bash
set -euo pipefail

# Wait for OpenWebUI to be ready on a given host/port
# Usage: wait-for-openwebui.sh [host] [port] [timeout]
# Defaults: localhost, 8080, 60s

HOST="${1:-localhost}"
PORT="${2:-8080}"
TIMEOUT="${3:-60}"

echo "Waiting for OpenWebUI at ${HOST}:${PORT}..."

END_TIME=$(($(date +%s) + TIMEOUT))
while [ $(date +%s) -lt $END_TIME ]; do
    if curl -sf http://${HOST}:${PORT}/api/models >/dev/null 2>&1; then
        echo "OpenWebUI is ready"
        exit 0
    fi
    sleep 2
done

echo "ERROR: OpenWebUI did not become available within ${TIMEOUT}s" >&2
exit 1
