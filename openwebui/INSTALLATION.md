# OpenWebUI — Portainer Stack Deployment

> **Recommended:** `scripts/deploy.sh all openwebui <ssh-host>` from the repo root handles directory setup, `.env` generation, file placement, and bringing the
> stack up in one step — see root `README.md`/`QUICKSTART.md`. The manual steps below are the equivalent broken out.

## Directory Setup (on Synology NAS)

```shell
STACK_PATH="/volume1/docker/stacks/openwebui"

mkdir -p $STACK_PATH/{data,ts-state,ts-config}
```

Copy `serve.json` into `$STACK_PATH/ts-config/` — the sidecar mounts the whole `ts-config` directory at `/config`, so the file lands at `/config/serve.json`.

## Deploy via Portainer

1. Go to **Stacks → Add stack**
2. Choose **Repository** as the build method
3. Set:
   - **Repository URL:** `https://github.com/isaackehle/iac.git`
   - **Repository reference:** `refs/heads/main`
   - **Compose path:** `openwebui/docker-compose.yml`
4. Under **Environment variables**, fill in:
   - `TZ` — timezone (e.g., `America/New_York`)
   - `OPENWEBUI_API_KEY` — admin API key (choose a strong random string)
   - `TS_AUTHKEY` — Tailscale auth key (generate at <https://login.tailscale.com/admin/settings/keys>, reusable, pre-authorized)
   - `TS_CERT_DOMAIN` — Tailscale MagicDNS domain (auto-derived as `openwebui.${TS_TAILNET_DOMAIN}`)
5. Click **Deploy the stack**

---

## Deploy via SSH (Recommended for GitOps)

> **Recommended:** `scripts/deploy.sh all openwebui <ssh-host>` from the repo root handles everything in one step.

### Prerequisites

- SSH access to the NAS (e.g., `nas` alias in `~/.ssh/config`)
- The `scripts/deploy.sh` and `scripts/gen-env.sh` tools available on your laptop
- The central secrets file `iac-secrets.env` with `OPENWEBUI_API_KEY` and `TS_AUTHKEY` set

### One-Line Deployment

```shell
cd ~/code/isaackehle/iac
scripts/deploy.sh all openwebui nas
```

This single command does:
1. Generates `openwebui/env.txt` from `iac-secrets.env`
2. Creates `/volume1/docker/stacks/openwebui/{data,ts-state,ts-config}` on the NAS
3. Copies `docker-compose.yml`, `env.txt`, and `serve.json` via SCP
4. Runs `docker compose up -d` on the NAS

### Step-by-Step (if you need more control)

```shell
# 1. Generate env.txt locally
scripts/gen-env.sh openwebui

# 2. Create directories on the NAS
ssh nas "mkdir -p /volume1/docker/stacks/openwebui/{data,ts-state,ts-config}"

# 3. Push files to the NAS
scp -O openwebui/docker-compose.yml nas:/volume1/docker/stacks/openwebui/
scp -O openwebui/env.txt nas:/volume1/docker/stacks/openwebui/
scp -O openwebui/serve.json nas:/volume1/docker/stacks/openwebui/ts-config/

# 4. Start the stack
ssh nas "cd /volume1/docker/stacks/openwebui && docker compose up -d"
```

### Verify Deployment

```shell
# Check containers are running
ssh nas "docker ps | grep openwebui"

# Check logs
ssh nas "docker logs --tail 50 openwebui"

# Verify OpenWebUI is accessible
curl -v https://openwebui.tail303fda.ts.net
```

---

## What the Stack Contains

| Container          | Image                                  | Role                                                             |
| ------------------ | -------------------------------------- | ---------------------------------------------------------------- |
| `openwebui`        | `ghcr.io/open-webui/open-webui:latest` | Web UI for LLM interaction with Ollama integration               |
| `openwebui-config` | `alpine:3.20`                          | One-time config runner — sets up Ollama engines on first start   |
| `ts-openwebui`     | `tailscale/tailscale:latest`           | Tailscale sidecar — OpenWebUI is only reachable via your tailnet |

The `openwebui` container uses `network_mode: service:ts-openwebui` — it borrows the sidecar's network namespace entirely. The `openwebui-config` container is a
one-time runner that configures Ollama engines after OpenWebUI starts.

## First-Run OpenWebUI Setup

1. From a device on your tailnet, visit `https://openwebui.${TS_TAILNET_DOMAIN}`
2. Create your admin account (or log in if you pre-configured it)
3. Configure Ollama engines:
   - Go to **Settings → Models**
   - Add Ollama engines (e.g., `http://localhost:11434` if running Ollama locally, or a remote Ollama instance)
4. Start using the UI to chat with your configured models

## Persistent Data

| Host Path                          | Container Path       | Contents                                           |
| ---------------------------------- | -------------------- | -------------------------------------------------- |
| `$STACK_PATH/data`                 | `/app/backend/data`  | OpenWebUI app data, user settings, model cache     |
| `$STACK_PATH/ts-state`             | `/var/lib/tailscale` | Tailscale identity (survives container recreation) |
| `$STACK_PATH/ts-config/serve.json` | `/config/serve.json` | Tailscale serve rules                              |

## Access

| URL                                      | Description                     |
| ---------------------------------------- | ------------------------------- |
| `https://openwebui.${TS_TAILNET_DOMAIN}` | OpenWebUI Web UI (tailnet-only) |

## Backups

Include `$STACK_PATH/data` and `$STACK_PATH/ts-state` in your Synology backup task (Hyper Backup, Syncthing, etc.). The `data` directory holds:

- User settings and preferences
- Model cache
- Chat history
- Custom configurations

## Troubleshooting

### Container Won't Start

1. Check logs:

   ```shell
   docker logs openwebui
   docker logs openwebui-config
   ```

2. Verify `OPENWEBUI_API_KEY` is set (required by `openwebui-config`)
3. Check Tailscale auth key is valid and reusable

### Ollama Not Connecting

1. Verify Ollama is running and accessible
2. Check the Ollama URL in OpenWebUI settings
3. If Ollama is on the NAS, use `http://localhost:11434` (the config container runs in the same namespace)

### Sidecar Not Accessible

1. Check all containers are running with matching uptimes:

   ```shell
   docker ps --format '{{.Names}}\t{{.RunningSince}}'
   ```

2. If `ts-openwebui` has been running much longer than others, restart the entire stack:

   ```shell
   cd /volume1/docker/stacks/openwebui
   docker compose down
   docker compose up -d
   ```

## References

- [OpenWebUI Documentation](https://docs.openwebui.com/)
- [OpenWebUI Docker Image](https://hub.docker.com/r/openwebui/open-webui)
- [Ollama Documentation](https://github.com/ollama/ollama)
