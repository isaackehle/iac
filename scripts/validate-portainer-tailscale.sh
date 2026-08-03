#!/usr/bin/env bash
# scripts/validate-portainer-tailscale.sh
# Validate Portainer Tailscale interface after deployment
#
# Usage:
#   NAS_USER=user NAS_HOST=host ./scripts/validate-portainer-tailscale.sh

set -euo pipefail

# Default values (can be overridden by environment variables)
NAS_USER="${NAS_USER:-your-username}"
NAS_HOST="${NAS_HOST:-your-host.tail303fda.ts.net}"
PORTAINER_HTTP="http://${NAS_HOST}:9000"
PORTAINER_HTTPS="https://portainer.${NAS_HOST}"

echo "=== Portainer Tailscale Validation ==="
echo ""

# Check Tailscale connectivity
echo "1. Checking Tailscale connectivity..."
if tailscale status | grep -q "$NAS_HOST"; then
    echo "   ✓ Tailscale connected to $NAS_HOST"
else
    echo "   ✗ Tailscale not connected to $NAS_HOST"
    echo "   Running: tailscale up"
    tailscale up
    sleep 5
    if tailscale status | grep -q "$NAS_HOST"; then
        echo "   ✓ Tailscale now connected"
    else
        echo "   ✗ Still not connected. Exiting."
        exit 1
    fi
fi
echo ""

# Check SSH access
echo "2. Checking SSH access..."
if ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 "$NAS_USER@$NAS_HOST" "echo 'connected'" >/dev/null 2>&1; then
    echo "   ✓ SSH accessible"
else
    echo "   ✗ SSH not accessible. Exiting."
    exit 1
fi
echo ""

# Check container status
echo "3. Checking container status..."
CONTAINER_STATUS=$(ssh -o StrictHostKeyChecking=no "$NAS_USER@$NAS_HOST" \
    "sudo /var/packages/ContainerManager/target/tool/docker ps --filter 'name=portainer' --format '{{.Status}}' 2>/dev/null || echo 'not found'" 2>/dev/null || echo "ssh failed")

if echo "$CONTAINER_STATUS" | grep -q "Up"; then
    echo "   ✓ Portainer containers running"
    echo "   Status: $CONTAINER_STATUS"
else
    echo "   ⚠ Portainer containers not running"
    echo "   Status: $CONTAINER_STATUS"
    echo "   Run: scripts/deploy-portainer.sh all $NAS_HOST"
    exit 1
fi
echo ""

# Check HTTP access
echo "4. Testing HTTP access..."
HTTP_RESPONSE=$(curl -sk --connect-timeout 10 "$PORTAINER_HTTP" 2>&1 || echo "failed")

if echo "$HTTP_RESPONSE" | grep -q "Portainer"; then
    echo "   ✓ HTTP access working"
    echo "   URL: $PORTAINER_HTTP"
else
    echo "   ✗ HTTP access failed"
    echo "   Response: $HTTP_RESPONSE"
    exit 1
fi
echo ""

# Check HTTPS access
echo "5. Testing HTTPS access..."
HTTPS_RESPONSE=$(curl -sk --connect-timeout 10 "$PORTAINER_HTTPS" 2>&1 || echo "failed")

if echo "$HTTPS_RESPONSE" | grep -q "Portainer"; then
    echo "   ✓ HTTPS access working"
    echo "   URL: $PORTAINER_HTTPS"
    echo "   Note: Self-signed certificate is expected"
else
    echo "   ⚠ HTTPS access may not be working"
    echo "   Response: $HTTPS_RESPONSE"
    echo "   This may be expected if Tailscale serve is not configured"
    echo "   Check: sudo docker exec ts-portainer cat /config/serve.json"
fi
echo ""

# Check Tailscale serve config
echo "6. Checking Tailscale serve configuration..."
SERVE_CONFIG=$(ssh -o StrictHostKeyChecking=no "$NAS_USER@$NAS_HOST" \
    "cat /volume1/docker/stacks/portainer/ts-config/serve.json 2>/dev/null || echo 'not found'" 2>/dev/null || echo "ssh failed")

if echo "$SERVE_CONFIG" | grep -q '"https"'; then
    echo "   ✓ Tailscale serve configured"
    echo "   Config: $SERVE_CONFIG"
else
    echo "   ⚠ Tailscale serve may not be configured"
    echo "   Config: $SERVE_CONFIG"
    echo "   Expected: {\"default\": {\"https\": true, \"port\": 9000}}"
fi
echo ""

# Summary
echo "=== Validation Summary ==="
echo ""
echo "Portainer is deployed and accessible:"
echo "  • HTTP:  $PORTAINER_HTTP"
echo "  • HTTPS: $PORTAINER_HTTPS (if configured)"
echo ""
echo "Next steps:"
echo "  1. Open http://$NAS_HOST:9000 in browser"
echo "  2. Complete initial setup"
echo "  3. Deploy Synology MCP server"
echo ""
echo "Validation complete!"
