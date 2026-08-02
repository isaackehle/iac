#!/bin/bash
# Deploy simple Portainer on Synology NAS (without Tailscale sidecar)

set -euo pipefail

SSH_HOST="isaac@voyager.tail303fda.ts.net"

echo "=== Deploying Simple Portainer on Synology ==="

# Create directory
echo "Creating directory..."
ssh "$SSH_HOST" "mkdir -p /volume1/docker/stacks/portainer-simple"

# Copy compose file
echo "Copying docker-compose.yml..."
scp ~/code/isaackehle/iac/portainer/simple/docker-compose.yml "$SSH_HOST:/volume1/docker/stacks/portainer-simple/"

# Deploy
echo "Deploying Portainer..."
ssh "$SSH_HOST" "cd /volume1/docker/stacks/portainer-simple && sudo /var/packages/ContainerManager/target/tool/docker compose up -d"

echo ""
echo "=== Portainer Deployment Complete ==="
echo "Access Portainer at: http://voyager.tail303fda.ts.net:9000"
echo ""
echo "To check status:"
echo "  ssh isaac@voyager.tail303fda.ts.net "sudo /var/packages/ContainerManager/target/tool/docker ps""
