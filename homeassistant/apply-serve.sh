#!/usr/bin/env bash
# homeassistant/apply-serve.sh — tailscale serve for Home Assistant
set -euo pipefail
tailscale serve --https 8123 http://127.0.0.1:8123
echo "✓ Home Assistant  https://voyager:8123 → http://127.0.0.1:8123"
