#!/usr/bin/env bash
set -euo pipefail

mkdir -p /volume1/docker/nextcloud/{app,data,postgres,ts-state,ts-config}
mkdir -p /volume1/docker/stacks/nextcloud
sudo chown -R "$UID":"${GROUPS[0]}" /volume1/docker/nextcloud
sudo chown -R "$UID":"${GROUPS[0]}" /volume1/docker/stacks/nextcloud

# deploy the Tailscale sidecar's serve.json
cp "$(dirname "$0")/serve.json" /volume1/docker/stacks/nextcloud/serve.json
cp "$(dirname "$0")/.env" /volume1/docker/stacks/nextcloud/.env
