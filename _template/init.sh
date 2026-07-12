#!/usr/bin/env bash
set -euo pipefail

mkdir -p /volume1/docker/stacks/app/{config,ts-state,ts-config}
sudo chown -R "$UID":"${GROUPS[0]}" /volume1/docker/stacks/app

# deploy the Tailscale sidecar's serve.json
cp "$(dirname "$0")/serve.json" /volume1/docker/stacks/app/serve.json
