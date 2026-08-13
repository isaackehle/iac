#!/usr/bin/env bash
# scripts/deploy.sh for synology-mcp stack
# Deploy Synology MCP server via Portainer or CLI

set -euo pipefail

STACK_NAME="synology-mcp"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STACK_DIR="$ROOT_DIR/$STACK_NAME"

usage() {
  cat >&2 <<EOF
Usage: scripts/deploy.sh <command> <ssh-host>

Commands:
  dirs   <ssh-host>    mkdir -p + chown the stack's directories on the NAS
  push   <ssh-host>    scp compose/.env files to NAS
  up     <ssh-host>    docker compose up -d on NAS
  all    <ssh-host>    dirs + push + up

Example:
  scripts/deploy.sh all nas
EOF
}

cmd_dirs() {
  local ssh_host="$1"
  echo "Creating stack directories on $ssh_host..."
  ssh "$ssh_host" "mkdir -p /volume1/docker/stacks/$STACK_NAME/config"
  echo "Done."
}

cmd_push() {
  local ssh_host="$1"
  echo "Pushing stack files to $ssh_host..."
  scp "$STACK_DIR/docker-compose.yml" "$ssh_host:/volume1/docker/stacks/$STACK_NAME/"
  scp "$STACK_DIR/.env" "$ssh_host:/volume1/docker/stacks/$STACK_NAME/" 2>/dev/null || true
  echo "Done."
}

cmd_up() {
  local ssh_host="$1"
  echo "Deploying stack on $ssh_host..."
  ssh "$ssh_host" "cd /volume1/docker/stacks/$STACK_NAME && docker compose up -d"
  echo "Done."
}

cmd_all() {
  local ssh_host="$1"
  cmd_dirs "$ssh_host"
  cmd_push "$ssh_host"
  cmd_up "$ssh_host"
}

case "${1:-}" in
  dirs)   cmd_dirs "$2" ;;
  push)   cmd_push "$2" ;;
  up)     cmd_up "$2" ;;
  all)    cmd_all "$2" ;;
  *)      usage ;;
esac
