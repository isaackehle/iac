#!/usr/bin/env bash
# postgresql/apply-serve.sh — tailscale serve for pgAdmin
# host:2660 → container:5050
# PostgreSQL itself (5432) is raw TCP — not proxied here
set -euo pipefail
tailscale serve --bg --https=2660 http://127.0.0.1:2660
echo "✓ pgAdmin  https://[host-nas]:2660 → http://127.0.0.1:2660"
