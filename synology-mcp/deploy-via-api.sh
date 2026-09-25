#!/usr/bin/env bash
# synology-mcp/deploy-via-api.sh — Deploy Synology MCP server via Portainer API
#
# This script deploys the synology-mcp stack using Portainer REST API instead of
# docker compose CLI. It follows GitOps pattern by pulling docker-compose.yml from GitHub.
#
# Prerequisites:
#   - Portainer must be running on NAS
#   - PORTAINER_URL and PORTAINER_API_KEY environment variables set
#
# Usage:
#   ./deploy-via-api.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
STACK_NAME="synology-mcp"

# Load secrets if available
if [[ -f "$ROOT_DIR/iac-secrets.env" ]]; then
    # Extract only non-secret vars
    export PORTAINER_URL=$(grep "^PORTAINER_URL=" "$ROOT_DIR/iac-secrets.env" | cut -d'=' -f2-)
fi

# Validate required variables
: "${PORTAINER_URL:?ERROR: PORTAINER_URL not set. Add to iac-secrets.env}"

# Get Portainer API key from 1Password
export PORTAINER_API_KEY=$(env -u OP_SERVICE_ACCOUNT op item get "t4ja5pul4aemvinocjvpvxjksu" --vault "om7ypuou3jgnbeckakyh55pl3a" --reveal 2>&1 | awk '/^  PORTAINER_API_KEY:/{print $2}')
: "${PORTAINER_API_KEY:?ERROR: Could not retrieve PORTAINER_API_KEY from 1Password}"

GITHUB_REPO="${GITHUB_REPO:-isaackehle/iac}"
GITHUB_BRANCH="${GITHUB_BRANCH:-main}"

echo "=== Deploying $STACK_NAME via Portainer API ==="
echo "  Portainer URL: $PORTAINER_URL"
echo "  GitHub Repo: $GITHUB_REPO/$GITHUB_BRANCH"
echo ""

# Step 1: Verify Portainer is accessible
echo "1. Checking Portainer API availability..."
if ! curl -s --connect-timeout 10 "$PORTAINER_URL/api/status" > /dev/null; then
    echo "❌ ERROR: Portainer API is not accessible at $PORTAINER_URL"
    echo ""
    echo "Portainer may not be running. To start it:"
    echo "  Option A (Container Manager UI):"
    echo "    1. Open DSM → Container Manager → Project"
    echo "    2. Find 'portainer' project → Start"
    echo ""
    echo "  Option B (SSH + docker compose):"
    echo "    ssh nas 'cd /volume1/docker/stacks/portainer && docker compose up -d'"
    echo ""
    exit 1
fi
echo "   ✓ Portainer API is accessible"

# Step 2: Get endpoint ID (NAS Docker endpoint)
echo ""
echo "2. Getting Docker endpoint ID..."
ENDPOINT_RESPONSE=$(curl -s -H "X-Api-Key: $PORTAINER_API_KEY" "$PORTAINER_URL/api/endpoints")
ENDPOINT_ID=$(echo "$ENDPOINT_RESPONSE" | jq -r '[.[] | select(.Type==1)] | .[0].Id // empty')

if [[ -z "$ENDPOINT_ID" || "$ENDPOINT_ID" == "null" ]]; then
    echo "❌ ERROR: Could not find Docker endpoint in Portainer"
    echo "Response: $ENDPOINT_RESPONSE"
    exit 1
fi
echo "   ✓ Endpoint ID: $ENDPOINT_ID"

# Step 3: Generate .env from secrets
echo ""
echo "3. Generating .env from secrets..."
"$ROOT_DIR/scripts/gen-env.sh" "$STACK_NAME"

# Check for placeholder values
if grep -qE '(^|[[:space:]])\*\*\*|^$' "$SCRIPT_DIR/.env" 2>/dev/null; then
    echo "   ⚠ Warning: Some secrets are placeholders or empty"
    echo "   Make sure SYNOLOGY_PASSWORD and SYNOLOGY_OTP_CODE are in iac-secrets.env"
fi

# Step 4: Build environment variables JSON array
echo ""
echo "4. Building environment variables..."
ENV_JSON="["
FIRST=true
while IFS='=' read -r key value || [[ -n "$key" ]]; do
    # Skip comments and empty lines
    [[ "$key" =~ ^[[:space:]]*# ]] && continue
    [[ -z "$key" ]] && continue
    
    # Trim whitespace
    key=$(echo "$key" | xargs)
    value=$(echo "$value" | xargs)
    [[ -z "$key" ]] && continue
    
    # Escape special characters for JSON
    value=$(printf '%s' "$value" | sed 's/\\/\\\\/g; s/"/\\"/g; s/\t/\\t/g')
    
    if [[ "$FIRST" == true ]]; then
        FIRST=false
    else
        ENV_JSON+=","
    fi
    ENV_JSON+="{\"name\":\"$key\",\"value\":\"$value\"}"
done < "$SCRIPT_DIR/.env"
ENV_JSON+="]"

ENV_COUNT=$(echo "$ENV_JSON" | jq 'length')
echo "   ✓ Environment variables: $ENV_COUNT"

# Step 5: Check if stack already exists
echo ""
echo "5. Checking for existing stack..."
EXISTING_STACK=$(curl -s -H "X-Api-Key: $PORTAINER_API_KEY" \
    "$PORTAINER_URL/api/stacks?name=$STACK_NAME" | jq -r ".[] | select(.Name==\"$STACK_NAME\") | .Id // empty")

if [[ -n "$EXISTING_STACK" && "$EXISTING_STACK" != "null" ]]; then
    echo "   ⚠ Stack '$STACK_NAME' already exists (ID: $EXISTING_STACK)"
    echo "   Updating existing stack..."
    
    # For existing stacks, we need to trigger a Git pull or recreate
    echo ""
    echo "6. Recreating existing stack..."
    RECREATE_RESPONSE=$(curl -s -X POST \
        -H "Content-Type: application/json" \
        -H "X-Api-Key: $PORTAINER_API_KEY" \
        "$PORTAINER_URL/api/stacks/$EXISTING_STACK/recreate" \
        -d '{"RecreateMode": "force"}')
    
    echo "   Response: $RECREATE_RESPONSE"
    STACK_ID="$EXISTING_STACK"
else
    echo "   No existing stack found. Creating new stack..."
    
    # Step 6: Create GitOps stack
    echo ""
    echo "6. Creating GitOps stack in Portainer..."
    
    STACK_JSON=$(cat <<EOF
{
  "name": "$STACK_NAME",
  "composeFile": "$STACK_NAME/docker-compose.yml",
  "repositoryURL": "https://github.com/$GITHUB_REPO.git",
  "repositoryReferenceName": "refs/heads/$GITHUB_BRANCH",
  "repositoryAuthentication": false,
  "env": $ENV_JSON
}
EOF
)
    
    echo "   Stack configuration:"
    echo "$STACK_JSON" | jq '.'
    
    STACK_RESPONSE=$(curl -s -X POST \
        -H "Content-Type: application/json" \
        -H "X-Api-Key: $PORTAINER_API_KEY" \
        "$PORTAINER_URL/api/stacks/create/standalone/repository?endpointId=$ENDPOINT_ID" \
        -d "$STACK_JSON")
    
    echo ""
    echo "   API Response: $STACK_RESPONSE"
    
    # Check for errors
    if echo "$STACK_RESPONSE" | grep -qi '"error"\|"message"'; then
        echo "❌ ERROR: Failed to create stack"
        echo "$STACK_RESPONSE" | jq . 2>/dev/null || echo "$STACK_RESPONSE"
        exit 1
    fi
    
    STACK_ID=$(echo "$STACK_RESPONSE" | jq -r '.Id // empty')
    
    if [[ -z "$STACK_ID" || "$STACK_ID" == "null" ]]; then
        echo "❌ ERROR: Failed to extract stack ID from response"
        exit 1
    fi
    
    echo "   ✓ Stack created with ID: $STACK_ID"
fi

# Step 7: Start the stack
echo ""
echo "7. Starting stack..."
START_RESPONSE=$(curl -s -X POST \
    -H "X-Api-Key: $PORTAINER_API_KEY" \
    "$PORTAINER_URL/api/stacks/$STACK_ID/start" \
    -d '{}')

if echo "$START_RESPONSE" | grep -qi '"error"'; then
    echo "   ⚠ Warning: Start command returned error (may already be running)"
    echo "   Response: $START_RESPONSE"
else
    echo "   ✓ Stack start command sent"
fi

# Step 8: Wait and verify
echo ""
echo "8. Waiting for deployment (30 seconds)..."
sleep 5

for i in {1..5}; do
    echo "   Checking status... (attempt $i/5)"
    STATUS_RESPONSE=$(curl -s -H "X-Api-Key: $PORTAINER_API_KEY" \
        "$PORTAINER_URL/api/stacks?name=$STACK_NAME")
    
    STACK_STATUS=$(echo "$STATUS_RESPONSE" | jq -r ".[] | select(.Name==\"$STACK_NAME\") | .Status // \"unknown\"")
    
    echo "   Current status: $STACK_STATUS"
    
    if [[ "$STACK_STATUS" == *"Running"* || "$STACK_STATUS" == *"running"* ]]; then
        echo ""
        echo "✓ SUCCESS: $STACK_NAME deployed successfully!"
        echo ""
        echo "Stack details:"
        echo "$STATUS_RESPONSE" | jq ".[] | select(.Name==\"$STACK_NAME\") | {Name, Status, Id, LastDeployed}"
        echo ""
        echo "Next steps:"
        echo "  1. Wait ~30 seconds for containers to initialize"
        echo "  2. Verify: ssh nas 'docker ps --filter name=synology-mcp'"
        echo "  3. Configure Hermes MCP server in ~/.hermes/config.yaml"
        exit 0
    fi
    
    sleep 5
done

echo ""
echo "⚠ Stack deployment initiated but status check incomplete"
echo "   Check Portainer UI for full status: $PORTAINER_URL"
echo ""
echo "Stack details:"
echo "$STATUS_RESPONSE" | jq ".[] | select(.Name==\"$STACK_NAME\") | {Name, Status, Id, LastDeployed}"
