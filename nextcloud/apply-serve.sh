#!/usr/bin/env bash
# nextcloud/apply-serve.sh — tailscale serve for Nextcloud
# TODO: verify host port from docker-compose.yml and update below
set -euo pipefail
tailscale serve --bg --https=8180 http://127.0.0.1:8180
echo "✓ Nextcloud  https://[host-nas]:8180 → http://127.0.0.1:8180  (verify port)"
