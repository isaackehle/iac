#!/usr/bin/env bash
set -euo pipefail

# Deploy Syncthing stack to remote NAS via SSH + Portainer Git integration
# Usage: ./deploy-syncthing.sh [ssh_host]
# Defaults to voyager.local

SSH_HOST="${1:-voyager.local}"
STACK_PATH="/volume1/docker/stacks/syncthing"

echo "=== Deploying Syncthing via Portainer Git ==="

# 1. Create stack directories on NAS
echo "[1/2] Creating stack directories..."
ssh "$SSH_HOST" "mkdir -p $STACK_PATH/{iac,data,config}"
ssh "$SSH_HOST" "cd $STACK_PATH/iac && \
    if [ ! -d .git ]; then git clone https://github.com/isaackehle/iac.git .; else git fetch origin && git reset --hard origin/main; fi"

# 2. Notify user to deploy in Portainer (after you commit/push locally)
echo "[2/2] Ready for Portainer deployment"

echo ""
echo "=== Next steps ==="
echo "1. Commit and push your changes to GitHub:"
echo "   cd ~/code/isaackehle/iac && git add syncthing/* && git commit -m 'deploy: Syncthing' && git push"
echo ""
echo "2. In Portainer:"
echo "   - Go to Stacks → Add stack"
echo "   - Deploy from repository: github.com/isaackehle/iac.git"
echo "   - Repository path: syncthing/docker-compose.yml"
echo "   - Create .env file with your secrets (SYNCTHING_DEVICE_ID=..., SYNCTHING_GUI_PASSWORD=...)"
echo "   - Deploy the stack via Portainer UI"
