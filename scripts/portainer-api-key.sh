#!/usr/bin/env bash
# scripts/portainer-api-key.sh — Helper to get Portainer API key
#
# Usage:
#   scripts/portainer-api-key.sh
#
# This script opens Portainer in your browser and guides you to create an API key.
# Once created, it copies the key to your clipboard (macOS) or prompts you to copy it.

set -euo pipefail

# Detect tailnet domain from iac-secrets.env
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TAILNET_DOMAIN=$(grep "^TS_TAILNET_DOMAIN=" "$ROOT_DIR/iac-secrets.env" 2>/dev/null | cut -d= -f2 || echo "tail303fda.ts.net")

PORTAINER_URL="https://portainer.$TAILNET_DOMAIN"

echo "=== Portainer API Key Setup ==="
echo ""
echo "1. Opening Portainer in your browser..."
echo "   URL: $PORTAINER_URL"
echo ""
echo "2. In Portainer, navigate to:"
echo "   Your username (top right) → API keys"
echo ""
echo "3. Create a new API key:"
echo "   - Name: iac-deploy"
echo "   - Expiry: 365 days (or your preference)"
echo "   - Click 'Create'"
echo ""
echo "4. Copy the generated key (starts with 'pt-...')"
echo ""

# Open browser on macOS
if [[ "$(uname)" == "Darwin" ]]; then
  open "$PORTAINER_URL"
  echo "✓ Browser opened. Once you have the API key, set it:"
  echo ""
  echo "   export PORTAINER_API_KEY='pt-your-key-here'"
  echo "   export PORTAINER_URL='$PORTAINER_URL'"
  echo ""
  echo "   Then run: scripts/deploy-to-portainer.sh <stack> <host>"
else
  echo "Please open $PORTAINER_URL in your browser"
  echo "Once you have the API key, set:"
  echo "   export PORTAINER_API_KEY='pt-your-key-here'"
  echo "   export PORTAINER_URL='$PORTAINER_URL'"
fi
