#!/usr/bin/env bash
# plex/apply-serve.sh
#
# NOTE: When using the Tailscale sidecar pattern (ts-plex container with
# TS_SERVE_CONFIG), this script is NOT needed — serve config is applied
# automatically by the sidecar via ts-config-serve.json on container start.
#
# This script is only useful if Plex is running on the voyager host directly
# (not via the sidecar), in which case it adds Plex to the host-level serve.
#
# For sidecar deployments, access Plex at:
#   https://plex.<tailnet>.ts.net

set -euo pipefail

echo "WARNING: Plex uses the sidecar pattern — this script is for host-only deployments."
echo "If you are using docker-compose.yaml with ts-plex, skip this script."
echo ""

tailscale serve --bg --https=32400 http://127.0.0.1:32400
echo "✓ Plex  https://[host-nas]:32400 → http://127.0.0.1:32400"
