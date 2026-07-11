#!/usr/bin/env bash
# pihole/apply-serve.sh — tailscale serve for Pi-hole
# host:8080 → container:80  (HTTP admin)
# host:8443 → container:443 (HTTPS admin, self-signed internally)
set -euo pipefail
tailscale serve --bg --https=8080 http://127.0.0.1:8080
echo "✓ Pi-hole HTTP   https://[host-nas]:8080 → http://127.0.0.1:8080"
tailscale serve --bg --https=8443 https+insecure://127.0.0.1:8443
echo "✓ Pi-hole HTTPS  https://[host-nas]:8443 → https+insecure://127.0.0.1:8443"
