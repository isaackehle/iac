#!/usr/bin/env bash
# frigate/apply-serve.sh — tailscale serve for Frigate NVR
# Port 8971 is the authenticated reverse-proxy port (v0.14+)
# RTSP (8554) and WebRTC (8555) are non-HTTP — not proxied here
set -euo pipefail
tailscale serve --bg --https=8971 http://127.0.0.1:8971
echo "✓ Frigate  https://[host-nas]:8971 → http://127.0.0.1:8971"
