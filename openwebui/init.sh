#!/usr/bin/env bash
set -euo pipefail

# Create required directories for openwebui stack
mkdir -p /volume1/docker/stacks/openwebui/{config,ts-state,ts-config}
sudo chown -R "$UID":"${GROUPS[0]}" /volume1/docker/stacks/openwebui

# Deploy the Tailscale sidecar's serve.json
cp "$(dirname "$0")/serve.json" /volume1/docker/stacks/openwebui/serve.json
