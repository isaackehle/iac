# n8n — Portainer Stack Deployment

> Recommended: `scripts/deploy.sh all n8n <ssh-host>` from the repo root
> handles directory setup, `.env` generation, file placement, and bringing
> the stack up in one step — see root `README.md`/`QUICKSTART.md`. The
> manual steps below are the equivalent broken out, useful if you want to
> deploy via the Portainer UI instead of `docker compose up -d` directly.

## Directory Setup (on Synology NAS)

```shell
STACK_PATH="/volume1/docker/stacks/n8n"

mkdir -p $STACK_PATH/{config,files,ts-state,ts-config}
chown -R 1000:1000 $STACK_PATH/config   # n8n container runs as uid 1000
```

Copy `serve.json` into `$STACK_PATH/ts-config/` — the sidecar mounts the
whole `ts-config` directory at `/config`, so the file lands at
`/config/serve.json`.

## Deploy via Portainer

1. Go to **Stacks → Add stack**
2. Choose **Repository** as the build method
3. Set:
   - **Repository URL:** `github.com/isaackehle/iac.git`
   - **Repository reference:** `refs/heads/main`
   - **Compose path:** `n8n/docker-compose.yml`
4. Under **Environment variables**, paste the contents of `.env.example` with
   real values filled in (or create a `.env` file alongside the compose file and
   Portainer will pick it up).
5. Click **Deploy the stack**

## What the Stack Contains

| Container | Image | Role |
|-----------|-------|------|
| `n8n` | `n8nio/n8n:latest` | Workflow automation engine |
| `n8n-browserless` | `browserless/chrome:latest` | Headless Chromium (HTTP Request / Browserless nodes) |
| `n8n-ts` | `tailscale/tailscale:latest` | Tailscale sidecar — n8n is only reachable via your tailnet |

All three containers share the `n8n-net` bridge network. The `n8n` container
uses `network_mode: service:n8n-ts` — it borrows the sidecar's network namespace
entirely, so it has no `ports:` of its own. That means n8n is reachable _only_
via the Tailnet hostname `n8n` (or whatever `serve.json` exposes).

## First-Run n8n Setup

1. From a device on your tailnet, visit `https://n8n.${TS_TAILNET_DOMAIN}`
   (or `http://n8n:5678` directly on the tailnet) and create your owner account.
2. Go to **Settings → Environment** to verify the encryption key and basic auth
   are set.
3. Add credentials (Telegram, HTTP Request, etc.) as needed.

## Persistent Data

| Host Path | Container Path | Contents |
|-----------|---------------|----------|
| `$STACK_PATH/config` | `/home/node/.n8n` | Workflows, credentials, execution history, settings |
| `$STACK_PATH/files` | `/files` | Shared folder for file-based nodes |
| `$STACK_PATH/ts-state` | `/var/lib/tailscale` | Tailscale identity (survives container recreation) |
| `$STACK_PATH/ts-config` | `/config` | Tailscale serve config at runtime |
| `$STACK_PATH/ts-config/serve.json` | `/config/serve.json` | Tailscale serve rules |

## Backups

Include `$STACK_PATH` (config, files, and ts-state) in your Synology backup task
(Hyper Backup, Syncthing, etc.). The `config` directory holds your workflows and
credentials; `ts-state` preserves the sidecar's tailnet identity so it doesn't
need re-authentication after a restore.