#!/usr/bin/env bash
set -euo pipefail

# Configure each fleet host's LiteLLM gateway as a named OpenAI-compatible
# connection in OpenWebUI. Replaces configure-ollama.sh (2026-09-25):
# Ollama is not part of the fleet (see homelab repo DEC-180/185) -- every
# host's models are reached through its own LiteLLM (:4000), never Ollama
# directly.
#
# Usage: configure-litellm.sh
#
# Environment variables (required):
#   OPENWEBUI_API_URL    - e.g., http://localhost:8080 or https://openwebui.ts.net
#   LITELLM_ENGINES       - JSON array of {"name": "<host>", "url": "<litellm /v1 base>"}
#                        Optional "prefix" overrides the model-id prefix (default: name;
#                        "" for none). Normal value since 2026-11-10 is the single
#                        in-stack gateway:
#                        '[{"name":"fleet","url":"http://127.0.0.1:4000/v1","prefix":""}]'
#                        Example: '[{"name":"discovery","url":"http://discovery.tailnet.ts.net:4000/v1"},{"name":"ds9","url":"http://ds9.tailnet.ts.net:4000/v1"}]'
#   OPENWEBUI_API_KEY    - Admin API key from OpenWebUI settings (Settings ->
#                          Account -> API keys). Does not exist until an admin
#                          account has been created once via the OpenWebUI web
#                          UI -- this is a one-time manual step, not something
#                          this script or any deploy automation can bootstrap.
#   LITELLM_SHARED_KEY   - The key every host's LiteLLM accepts from tools
#                          (sk-homelab-local; see homelab AGENTS.md rule 6).
#                          Same key for every engine -- LiteLLM's tool key is
#                          not per-host.

API_URL="${OPENWEBUI_API_URL:-http://localhost:8080}"
LITELLM_ENGINES="${LITELLM_ENGINES:-"[]"}"
SHARED_KEY="${LITELLM_SHARED_KEY:-sk-homelab-local}"

if [ -z "${OPENWEBUI_API_KEY:-}" ]; then
    echo "configure-litellm: OPENWEBUI_API_KEY is not set yet."
    echo "  This is expected on a fresh deploy: OpenWebUI has no admin API key"
    echo "  until an admin account has been created once via the web UI."
    echo "  1. Open https://openwebui.\${TS_TAILNET_DOMAIN} and sign up (first"
    echo "     account created becomes admin)."
    echo "  2. Settings -> Account -> API keys -> create one."
    echo "  3. Put it in openwebui/.env as OPENWEBUI_API_KEY=..."
    echo "  4. Re-run: scripts/deploy.sh up openwebui nas   (or: docker compose run --rm config)"
    echo "Skipping connection registration for now; OpenWebUI itself is still up."
    exit 0
fi
API_KEY="$OPENWEBUI_API_KEY"

# Wait for OpenWebUI to be ready (max 60s)
echo "Waiting for OpenWebUI..."
END_TIME=$(($(date +%s) + 60))
while [ "$(date +%s)" -lt "$END_TIME" ]; do
    if curl -sf "${API_URL}/health" >/dev/null 2>&1; then
        echo "OpenWebUI is ready at ${API_URL}"
        break
    fi
    sleep 2
done

echo "Configuring LiteLLM connections..."

# Validate and process LITELLM_ENGINES in a single Python invocation.
# Tries json.load first (double-quoted JSON); falls back to ast.literal_eval
# so the script also accepts single-quoted .env values written by hand.
readarray -t _result < <(python3 -c "
import sys, json, ast

raw = sys.argv[1]
engines = None
try:
    engines = json.loads(raw)
except json.JSONDecodeError:
    try:
        engines = ast.literal_eval(raw)
    except (ValueError, SyntaxError) as exc:
        print(f'ERROR: LITELLM_ENGINES is not valid JSON or Python literal: {exc}', file=sys.stderr)
        print(f'  Value: {raw!r}', file=sys.stderr)
        sys.exit(1)

if not isinstance(engines, list):
    print('ERROR: LITELLM_ENGINES must be a JSON array', file=sys.stderr)
    sys.exit(1)

base_urls = []
api_keys  = []
configs   = {}

for i, eng in enumerate(engines):
    name  = eng.get('name', f'host-{i}')
    url   = eng.get('url', '').rstrip('/')
    base_urls.append(url)
    api_keys.append(sys.argv[2])
    # Optional "prefix": the fleet gateway already namespaces models as
    # <host>/<model>, so its entry sets "prefix": "" to avoid a second prefix.
    configs[str(i)] = {'enable': True, 'tags': [], 'prefix_id': eng.get('prefix', name)}
    print(f'  Adding: {name} -> {url}')

print(json.dumps(base_urls))
print(json.dumps(api_keys))
print(json.dumps(configs))
" "$LITELLM_ENGINES" "$SHARED_KEY")
BASE_URLS="${_result[0]}"
API_KEYS="${_result[1]}"
CONFIG_MAP="${_result[2]}"

echo "Sending configuration to OpenWebUI..."
curl -s -X POST "${API_URL}/openai/config/update" \
    -H "Authorization: Bearer ${API_KEY}" \
    -H "Content-Type: application/json" \
    -d "{
        \"ENABLE_OPENAI_API\": true,
        \"OPENAI_API_BASE_URLS\": ${BASE_URLS},
        \"OPENAI_API_KEYS\": ${API_KEYS},
        \"OPENAI_API_CONFIGS\": ${CONFIG_MAP}
    }" | python3 -c "import sys; d=sys.stdin.read(); print('Response:', d[:200]) if len(d) > 200 else print('Response:', d)"

# Explicitly disable Ollama connections -- this stack never registers any
# (homelab DEC-180/185).
curl -s -X POST "${API_URL}/ollama/config/update" \
    -H "Authorization: Bearer ${API_KEY}" \
    -H "Content-Type: application/json" \
    -d '{"ENABLE_OLLAMA_API": false, "OLLAMA_BASE_URLS": [], "OLLAMA_API_CONFIGS": {}}' >/dev/null

echo "Configuration complete!"
echo ""
echo "OpenWebUI will now see each fleet host's LiteLLM as a separate named connection."
echo "Model list per connection matches that host's fleet/registry/hosts.yaml roles"
echo "plus cloud picks (see homelab repo skills/fleet-ops)."
