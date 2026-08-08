# Plex — Portainer Stack Deployment

> Recommended: `scripts/deploy.sh all plex <ssh-host>` from the repo root
> handles directory setup, `.env` generation, file placement, and bringing
> the stack up in one step — see root `README.md`/`QUICKSTART.md`. The
> manual steps below are the equivalent broken out.

## Directory Setup (on Synology NAS)

```shell
STACK_PATH="/volume1/docker/plex"

mkdir -p $STACK_PATH/{config,ts-state,ts-config}
```

Copy `serve.json` into `$STACK_PATH/ts-config/` — it's mounted read-only into the
Tailscale sidecar and applied via `TS_SERVE_CONFIG` on container start.

## Deploy via Portainer

1. Go to **Stacks → Add stack**
2. Choose **Repository** as the build method
3. Set:
   - **Repository URL:** `https://github.com/isaackehle/iac.git`
   - **Repository reference:** `refs/heads/main`
   - **Compose path:** `plex/docker-compose.yml`
4. Under **Environment variables**, paste the contents of `.env.example` with
   real values filled in:
   - `PLEX_CLAIM` — from <https://www.plex.tv/claim> (only needed on first run)
   - `TS_AUTHKEY` — from <https://login.tailscale.com/admin/settings/keys>
5. Click **Deploy the stack**

## What the Stack Contains

| Container | Image                             | Role                                                        |
| --------- | --------------------------------- | ----------------------------------------------------------- |
| `plex`    | `lscr.io/linuxserver/plex:latest` | Plex Media Server                                           |
| `plex-tailscale` | `tailscale/tailscale:latest`      | Tailscale sidecar — Plex is only reachable via your tailnet |

The `plex` container uses `network_mode: service:plex-tailscale` — it borrows the
sidecar's network namespace entirely, so it has no `ports:` of its own. Plex
is reachable _only_ via the tailnet hostname `plex` (or whatever `serve.json`
exposes).

## First-Run Plex Setup

1. From a device on your tailnet, visit `https://plex.${TS_TAILNET_DOMAIN}`.
2. The `PLEX_CLAIM` token in `.env` binds the server to your Plex account
   automatically on first start. You should land on the Plex setup wizard.
3. Follow the wizard to name your server, add media libraries, and configure
   remote access (already handled by Tailscale — no port forwarding needed).

## Persistent Data

| Host Path                          | Container Path          | Contents                                           |
| ---------------------------------- | ----------------------- | -------------------------------------------------- |
| `$STACK_PATH/config`               | `/config`               | Plex database, metadata, cache, plugins            |
| `/volume1/media`                   | `/media`                | Media libraries (adjust in `docker-compose.yml`)   |
| `$STACK_PATH/ts-state`             | `/var/lib/tailscale`    | Tailscale identity (survives container recreation) |
| `$STACK_PATH/ts-config/serve.json` | `/config/serve.json:ro` | Tailscale serve rules                              |

## Access

| URL                                 | Description                |
| ----------------------------------- | -------------------------- |
| `https://plex.${TS_TAILNET_DOMAIN}` | Plex Web UI (tailnet-only) |

No LAN ports are exposed by default. If you need LAN access (e.g., for smart
TVs on the local network), add `ports: ["32400:32400"]` to the `plex` service
in `docker-compose.yml`.

## Backups

Include `$STACK_PATH/config` and `$STACK_PATH/ts-state` in your Synology backup
task (Hyper Backup, Syncthing, etc.). The `config` directory holds your Plex
database and metadata; `ts-state` preserves the sidecar's tailnet identity so it
doesn't need re-authentication after a restore.
