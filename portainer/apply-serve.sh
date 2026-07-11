#!/usr/bin/env bash
# portainer/apply-serve.sh
# Tailscale serve: https://[host-nas]:9443 → Portainer
#
# Portainer HTTPS (self-signed) is on host:19443 → container:9443
# Uses https+insecure:// to bypass self-signed cert verification.

set -euo pipefail

tailscale serve --bg --https 9443 https+insecure://127.0.0.1:19443

echo "Portainer serve mapping applied:"
echo "✓ https://[host-nas]:9443 → https+insecure://127.0.0.1:19443"