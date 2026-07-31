#!/usr/bin/env bash
set -euo pipefail

# Configure multiple Ollama backends as named connections in OpenWebUI
# Usage: configure-ollama.sh [API_KEY]
# 
# Environment variables (required):
#   OPENWEBUI_API_URL    - e.g., http://localhost:8080 or https://openwebui.ts.net
#   OLLAMA_ENGINES       - JSON array of objects with machine name and URL
#                        Example: '[{"name":"local","url":"http://host.docker.internal:11434"},{"name":"ds9","url":"https://ds9.${TS_TAILNET_DOMAIN}"}]'
#   OPENWEBUI_API_KEY    - Admin API key from OpenWebUI settings

API_URL="${OPENWEBUI_API_URL:-http://localhost:8080}"
OLLAMA_ENGINES="${OLLAMA_ENGINES:-"[]"}"
API_KEY="${OPENWEBUI_API_KEY:?OpenWebUI API key required (set OPENWEBUI_API_KEY env var)}"

# Wait for OpenWebUI to be ready (max 60s)
echo "Waiting for OpenWebUI..."
END_TIME=$(($(date +%s) + 60))
while [ $(date +%s) -lt $END_TIME ]; do
    if curl -sf "${API_URL}/api/models" >/dev/null 2>&1; then
        echo "OpenWebUI is ready at ${API_URL}"
        break
    fi
    sleep 2
done

# Parse OLLAMA_ENGINES JSON and configure each as a named connection
echo "Configuring Ollama connections..."

# Build array of URLs for enablement
ENABLED_URLS="[]"
CONFIG_MAP="{}"

# Process each engine entry
while IFS= read -r engine; do
    [ -z "$engine" ] && continue
    
    NAME=$(echo "$engine" | python3 -c "import sys, json; print(json.load(sys.stdin)['name'])")
    URL=$(echo "$engine" | python3 -c "import sys, json; print(json.load(sys.stdin)['url'].rstrip('/'))")
    
    echo "  Adding: ${NAME} -> ${URL}"
    
    # Extract base URL (without /v1) for OpenWebUI's Ollama config
    BASE_URL=$(echo "$URL" | sed 's|/v1$||')
    
    # Add to enabled URLs array
    ENABLED_URLS=$(echo "$ENABLED_URLS" | python3 -c "import sys, json; urls=json.load(sys.stdin); urls.append('${BASE_URL}'); print(json.dumps(urls))")
    
    # Add to config map (empty for now, can add model mappings later)
    CONFIG_MAP=$(echo "$CONFIG_MAP" | python3 -c "import sys, json; m=json.load(sys.stdin); m['${BASE_URL}']={}; print(json.dumps(m))")
    
done < <(python3 -c "import sys, json; engines=json.load(sys.stdin); [print(json.dumps(e)) for e in engines]" <<< "$OLLAMA_ENGINES")

# Make the API call to configure Ollama connections
echo "Sending configuration to OpenWebUI..."
curl -s -X POST "${API_URL}/ollama/config/update" \
    -H "Authorization: Bearer ${API_KEY}" \
    -H "Content-Type: application/json" \
    -d "{
        \"ENABLE_OLLAMA_API\": true,
        \"OLLAMA_BASE_URLS\": ${ENABLED_URLS},
        \"OLLAMA_API_CONFIGS\": ${CONFIG_MAP}
    }" | python3 -c "import sys; d=sys.stdin.read(); print('Response:', d[:200]) if len(d) > 200 else print('Response:', d)"

echo "Configuration complete!"
echo ""
echo "OpenWebUI will now see all configured Ollama backends as separate named connections."
