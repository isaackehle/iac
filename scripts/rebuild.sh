#!/usr/bin/env bash
# rebuild.sh — quick rebuild of pihole and/or syncthing from the IAC repo
#
# Usage:
#   ./rebuild.sh pihole    # rebuild pihole only
#   ./rebuild.sh syncthing # rebuild syncthing only
#   ./rebuild.sh all       # rebuild both
#
# This script assumes:
# - You are in ~/code/isaackehle/iac/portainer/
# - The NAS is accessible via SSH as 'nas'
# - You have the IAC repo at /volume1/docker/stacks/portainer/iac/

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IAC_REPO="/volume1/docker/stacks/portainer/iac"
DATA_DIR="/volume1/docker/stacks/portainer/data"

usage() {
  cat >&2 <<EOF
Usage: $0 <stack>

Stacks:
  pihole     - Rebuild pihole stack
  syncthing  - Rebuild syncthing stack
  all        - Rebuild both pihole and syncthing

Commands:
  $0 pihole     - Deploy pihole from IAC repo
  $0 syncthing  - Deploy syncthing from IAC repo
  $0 all        - Deploy both stacks
EOF
  exit 1
}

deploy_stack() {
  local stack="$1"
  echo "=========================================="
  echo "Deploying $stack..."
  echo "=========================================="

  # Step 1: Generate .env locally
  echo "Step 1: Generating .env..."
  cd "$SCRIPT_DIR"
  if [[ ! -f "scripts/gen-env.sh" ]]; then
    echo "❌ gen-env.sh not found in $SCRIPT_DIR"
    exit 1
  fi
  bash scripts/gen-env.sh "$stack"
  if [[ ! -f "${stack}/.env" ]]; then
    echo "❌ Failed to generate .env for $stack"
    exit 1
  fi
  echo "✅ Generated ${stack}/.env"

  # Step 2: Create directories on NAS
  echo "Step 2: Creating directories on NAS..."
  ssh nas "sudo mkdir -p ${DATA_DIR}/${stack}"
  ssh nas "sudo chown -R root:root ${DATA_DIR}/${stack}"
  echo "✅ Created directories"

  # Step 3: Push files to NAS
  echo "Step 3: Pushing files to NAS..."
  ssh nas "sudo mkdir -p ${DATA_DIR}/${stack}"
  scp "${stack}/docker-compose.yml" nas:"${DATA_DIR}/${stack}/"
  scp "${stack}/.env" nas:"${DATA_DIR}/${stack}/"
  if [[ -f "${stack}/serve.json.tmpl" ]]; then
    bash scripts/serve-all.sh "${stack}" nas
  fi
  echo "✅ Files pushed"

  # Step 4: Apply via Portainer or docker compose
  echo "Step 4: Applying deployment..."
  echo "   Option A: Use Portainer UI to deploy from ${DATA_DIR}/${stack}/docker-compose.yml"
  echo "   Option B: Run 'sudo docker compose -f ${DATA_DIR}/${stack}/docker-compose.yml up -d' on NAS"
  echo "✅ Deployment ready"

  echo "=========================================="
  echo "✅ $stack deployed successfully!"
  echo "=========================================="
  echo
}

# Main
if [[ $# -ne 1 ]]; then
  usage
fi

case "$1" in
  pihole)
    deploy_stack "pihole"
    ;;
  syncthing)
    deploy_stack "syncthing"
    ;;
  all)
    deploy_stack "pihole"
    deploy_stack "syncthing"
    ;;
  *)
    usage
    ;;
esac
