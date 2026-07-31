# OpenWebUI

Tailscale sidecar deployment for OpenWebUI (AI chat interface) with multi-backend Ollama support.

## Quick Start

### 1. Create admin account and API key

Deploy the stack first:

```bash
cd /volume1/docker/stacks/openwebui
docker compose up -d
```

Open Web UI at `https://openwebui.${TS_TAILNET_DOMAIN}`, create your admin account (first user = admin), then get an API key from **Settings → Account → API Keys**.

### 2. Configure multiple Ollama backends

Set environment variables and deploy:

```bash
export OPENWEBUI_API_URL="https://openwebui.${TS_TAILNET_DOMAIN}"
export OPENWEBUI_API_KEY="sk-your-api-key-here"
export OLLAMA_ENGINES='[
  {"name":"local","url":"http://host.docker.internal:11434"},
  {"name":"ds9","url":"https://ds9.${TS_TAILNET_DOMAIN}:8080"},
  {"name":"enterprise","url":"https://enterprise.${TS_TAILNET_DOMAIN}:8080"}
]'

docker compose up -d openwebui-config
```

The `openwebui-config` container will automatically call OpenWebUI's admin API to register all three backends as **named connections**.

### 3. Verify configuration

After deployment, you should see models from all three machines in the UI:

- Each backend appears with its machine name (local/ds9/enterprise)
- Models are clearly labeled by source machine
- No name collisions — each connection is distinct

See **Configuring Multiple Ollama Backends** below for more details.

## Configuring Multiple Ollama Backends

This deployment uses the **named connections approach**: each backend is registered separately via OpenWebUI's admin API, preserving machine identity in the UI.

### Why named connections vs. flat `OLLAMA_BASE_URLS`?

| Approach                              | Pros                                                         | Cons                                        |
| ------------------------------------- | ------------------------------------------------------------ | ------------------------------------------- |
| **Named connections** (this template) | Clear machine labels; model ownership visible; no collisions | Requires post-deploy API call               |
| Flat env var (`OLLAMA_BASE_URLS`)     | Purely declarative; one container create                     | Single flat list; name collisions ambiguous |

See "Why named connections vs. flat `OLLAMA_BASE_URLS`?" above for more.

### Environment variables

Required:

- `OPENWEBUI_API_KEY` — Admin API key from OpenWebUI Settings → Account → API Keys
- `OLLAMA_ENGINES` — JSON array of backend definitions (see format below)

Optional:

- `OPENWEBUI_API_URL` — Default: `http://localhost:8080`; use Tailscale URL when deploying to NAS: `https://openwebui.${TS_TAILNET_DOMAIN}`

### OLLAMA_ENGINES format

```json
[
  {
    "name": "local",
    "url": "http://host.docker.internal:11434",
    "description": "Optional description"
  },
  {
    "name": "ds9",
    "url": "https://ds9.${TS_TAILNET_DOMAIN}:8080",
    "description": "DS9 NAS via Tailscale"
  }
]
```

Field requirements:

- `name` — Required. Machine identifier shown in OpenWebUI UI (alphanumeric + dash/underscore)
- `url` — Required. Full URL to Ollama API endpoint (must include port if non-standard); will have `/v1` stripped internally
- `description` — Optional. Human-readable note

### Example configurations

See [`example-engines.json`](./example-engines.json) for a complete example with three machines.

### Running configure-ollama.sh manually

If you need to reconfigure after initial deploy:

```bash
export OPENWEBUI_API_URL="https://openwebui.${TS_TAILNET_DOMAIN}"
export OPENWEBUI_API_KEY="sk-new-api-key-here"
export OLLAMA_ENGINES='[{"name":"local","url":"http://host.docker.internal:11434"}]'

docker run --rm \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -e OPENWEBUI_API_URL="$OPENWEBUI_API_URL" \
  -e OPENWEBUI_API_KEY="$OPENWEBUI_API_KEY" \
  -e OLLAMA_ENGINES="$OLLAMA_ENGINES" \
  -v $(pwd)/configure-ollama.sh:/scripts/configure-ollama.sh:ro \
  alpine:3.20 sh /scripts/configure-ollama.sh
```

## Deployment steps

1. **Create required directories:**

   ```bash
   mkdir -p /volume1/docker/stacks/openwebui/{config,ts-state,ts-config,data}
   sudo chown -R $UID:${GROUPS[0]} /volume1/docker/stacks/openwebui
   ```

2. **Copy files to the stack directory:**

   ```bash
   cp docker-compose.yml init.sh serve.json .env.example configure-ollama.sh example-engines.json /volume1/docker/stacks/openwebui/
   cd /volume1/docker/stacks/openwebui
   ```

3. **Set up Tailscale auth key:**

   ```bash
   export TS_AUTHKEY="key-xxxxxxxxxxxx"  # From https://login.tailscale.com/admin/key/new
   cp .env.example .env
   nano .env  # Add your auth key
   ```

4. **Deploy the stack:**

   ```bash
   docker compose up -d
   ```

5. **Create admin account and get API key:**
   Open `https://openwebui.${TS_TAILNET_DOMAIN}` → create first user (admin) → Settings → Account → API Keys → Create new key

6. **Configure Ollama backends:**
   See "Configuring Multiple Ollama Backends" above

## Known issues

- DNS collision: The `openwebui` hostname is set via env var (`TS_HOSTNAME=openwebui`), not the compose `hostname:` field, to avoid collisions with other Tailscale sidecars. This is intentional and documented in [`_template/README.md`](../_template/README.md#known-dns-collision) and the root `README.md`.

## Contributing

When adding new features:

1. Update this README with usage examples
2. Add/update `example-engines.json` if backend configuration changes
3. Test the full flow: deploy → configure → verify in UI
