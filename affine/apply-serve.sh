#!/usr/bin/env bash
# affine/apply-serve.sh — tailscale serve for AFFiNE
set -euo pipefail
tailscale serve --bg --https=3010 http://127.0.0.1:3010
echo "✓ AFFiNE  https://[host-nas]:3010 → http://127.0.0.1:3010"
