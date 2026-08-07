#!/usr/bin/env bash
# scripts/deploy-to-portainer.sh — Deploy stacks to Synology via Portainer API
#
# Usage:
#   scripts/deploy-to-portainer.sh <stack> <ssh-host>
#
# Requires:
#   PORTAINER_URL=https://portainer.<tailnet>.ts.net
#   PORTAINER_API_KEY=pt-your-api-key-here

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/scripts/lib.sh"

: "${PORTAINER_URL:?PORTAINER_URL is required}"
: "${PORTAINER_API_KEY:?PORTAINER_API_KEY is required}"

GITHUB_REPO="${GITHUB_REPO:-isaackehle/iac}"
GITHUB_BRANCH="${GITHUB_BRANCH:-main}"

usage() {
  cat >&2 <<'EOF'
Usage: scripts/deploy-to-portainer.sh <stack> <ssh-host>

Required:
  PORTAINER_URL=https://portainer.<tailnet>.ts.net
  PORTAINER_API_KEY=pt-your-api-key-here

Example:
  export PORTAINER_URL="https://portainer.tail303fda.ts.net"
  export PORTAINER_API_KEY="pt-abc123..."
  scripts/deploy-to-portainer.sh langfuse nas
EOF
  exit 1
}

deploy_stack() {
  local stack="$1"
  local host="$2"
  
  require_stack "$stack"
  
  echo "==> Deploying $stack to $host via Portainer API"
  
  echo "1. Generating .env from secrets..."
  "$ROOT_DIR/scripts/gen-env.sh" "$stack"
  
  if grep -qE '(^|[[:space:]])\*\*\*|^$' "$stack/.env" 2>/dev/null; then
    echo "⚠ Warning: Some secrets are placeholders"
  fi
  
  echo "2. Creating GitOps stack in Portainer..."
  
  local endpoint_id
  endpoint_id=$(curl -s -H "X-Api-Key: $PORTAINER_API_KEY" \
    "$PORTAINER_URL/api/endpoints" | jq -r '.[0].Id // 1')
  echo "   Endpoint ID: $endpoint_id"
  
  # Build env JSON array
  local env_json="["
  local first=true
  while IFS='=' read -r key value || [[ -n "$key" ]]; do
    [[ "$key" =~ ^[[:space:]]*# ]] && continue
    [[ -z "$key" ]] && continue
    key=$(echo "$key" | xargs)
    value=$(echo "$value" | xargs)
    [[ -z "$key" ]] && continue
    value=$(printf '%s' "$value" | sed 's/\\/\\\\/g; s/"/\\"/g')
    
    if [[ "$first" == true ]]; then
      first=false
    else
      env_json+=","
    fi
    env_json+="{\"Name\":\"$key\",\"Value\":\"$value\"}"
  done < "$stack/.env"
  env_json+="]"
  
  echo "   Environment variables: $(echo "$env_json" | jq -r 'length')"
  
  # Create stack JSON
  local stack_json
  stack_json=$(cat <<EOF
{
  "Name": "$stack",
  "EndpointId": $endpoint_id,
  "GitConfig": {
    "URL": "https://github.com/$GITHUB_REPO.git",
    "SubFolder": "$stack",
    "Branch": "$GITHUB_BRANCH",
    "Autoload": true,
    "AuthenticationType": null
  },
  "ComposeFiles": ["docker-compose.yml"],
  "Env": $env_json
}
EOF
)
  
  local stack_response
  stack_response=$(curl -s -X POST \
    -H "Content-Type: application/json" \
    -H "X-Api-Key: $PORTAINER_API_KEY" \
    "$PORTAINER_URL/api/stacks" \
    -d "$stack_json")
  
  if echo "$stack_response" | grep -q '"Error"'; then
    echo "ERROR: Failed to create stack:"
    echo "$stack_response" | jq . 2>/dev/null || echo "$stack_response"
    exit 1
  fi
  
  local stack_id
  stack_id=$(echo "$stack_response" | jq -r '.Id // empty')
  
  if [[ -z "$stack_id" || "$stack_id" == "null" ]]; then
    echo "ERROR: Failed to extract stack ID"
    exit 1
  fi
  
  echo "   Stack created: ID=$stack_id"
  
  echo "3. Starting stack..."
  local start_response
  start_response=$(curl -s -X POST \
    -H "X-Api-Key: $PORTAINER_API_KEY" \
    "$PORTAINER_URL/api/stacks/$stack_id/start" \
    -d '{}')
  
  if echo "$start_response" | grep -q '"Error"'; then
    echo "⚠ Warning: Failed to start immediately"
  else
    echo "   Stack started successfully"
  fi
  
  echo "4. Verifying deployment..."
  sleep 5
  
  local stack_status
  stack_status=$(curl -s -H "X-Api-Key: $PORTAINER_API_KEY" \
    "$PORTAINER_URL/api/stacks?name=$stack" | jq ".[] | select(.Name==\"$stack\") | {Name, Status, GitConfig, LastDeployed}")
  
  echo "$stack_status"
  
  if echo "$stack_status" | grep -q '"Status":"Running"'; then
    echo ""
    echo "✓ $stack deployed successfully!"
  else
    echo ""
    local status
    status=$(echo "$stack_status" | jq -r '.Status // "unknown"')
    echo "⚠ Status: $status"
  fi
}

[[ $# -eq 2 ]] || usage

cd "$ROOT_DIR"
deploy_stack "$1" "$2"
