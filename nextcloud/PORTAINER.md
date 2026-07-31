# Nextcloud — Portainer Stack Deployment

> Recommended: `scripts/deploy.sh all nextcloud <ssh-host>` from the repo
> root handles directory setup, `.env` generation, file placement, and
> bringing the stack up in one step — see root `README.md`/`QUICKSTART.md`.
> The manual steps below are the equivalent broken out.

## Directory Setup (on Synology NAS)

```shell
STACK_PATH="/volume1/docker/stacks/nextcloud"

mkdir -p $STACK_PATH/{app,data,postgres,ts-state,ts-config}
chown -R 33:33 $STACK_PATH/app     # Apache www-data uid
chown -R 33:33 $STACK_PATH/data    # Nextcloud data directory
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
   - **Compose path:** `nextcloud/docker-compose.yml`
4. Under **Environment variables**, fill in the values from `.env.example`:
   - `NC_DB_PASSWORD` — PostgreSQL password for the `nextcloud` user
   - `NC_ADMIN_USER` / `NC_ADMIN_PASSWORD` — Nextcloud admin account
   - `TS_AUTHKEY` — Tailscale auth key (reusable, pre-authorized)
   - `TS_CERT_DOMAIN` — Tailscale MagicDNS domain (e.g. `nextcloud.${TS_TAILNET_DOMAIN}`)
5. Click **Deploy the stack**

## What the Stack Contains

| Container         | Image                        | Role                                                                          |
| ----------------- | ---------------------------- | ----------------------------------------------------------------------------- |
| `nextcloud-db`    | `postgres:16`                | PostgreSQL database — persistent at `$STACK_PATH/postgres`                    |
| `nextcloud-redis` | `redis:7-alpine`             | Redis cache — improves performance for file locking and caching               |
| `nextcloud`       | `nextcloud:apache`           | Nextcloud application — listens on port `30080` (mapped to container port 80) |
| `nextcloud-ts`    | `tailscale/tailscale:latest` | Tailscale sidecar — proxies HTTPS via `serve.json` to `127.0.0.1:30080`       |

All four containers share the `nextcloud-net` bridge network. The Nextcloud
container exposes port `30080` on the Docker host, which the Tailscale sidecar
proxies to via its `serve.json` configuration (port 443 → `http://127.0.0.1:30080`).

## First-Run Nextcloud Setup

1. From a device on your tailnet, visit `https://nextcloud.${TS_TAILNET_DOMAIN}`
2. Log in with the `NC_ADMIN_USER` / `NC_ADMIN_PASSWORD` credentials.
3. Go to **Administration settings → Overview** and verify:
   - Database is PostgreSQL (connected to `nextcloud-db`)
   - Redis is configured for caching
   - Cron is enabled for background jobs (next step)

## Background Jobs (Cron)

Nextcloud requires a cron job for background processing. In Portainer, set up a
scheduled job:

```shell
docker exec nextcloud php -f /var/www/html/cron.php
```

Run this every 5 minutes (`*/5 * * * *`). Alternatively, containerize the cron runner.

## Persistent Data

| Host Path                          | Container Path             | Contents                                             |
| ---------------------------------- | -------------------------- | ---------------------------------------------------- |
| `$STACK_PATH/app`                  | `/var/www/html`            | Nextcloud application code and config (`config.php`) |
| `$STACK_PATH/data`                 | `/var/www/html/data`       | User files, shares, versions                         |
| `$STACK_PATH/postgres`             | `/var/lib/postgresql/data` | PostgreSQL database files                            |
| `$STACK_PATH/ts-state`             | `/var/lib/tailscale`       | Tailscale identity (survives container recreation)   |
| `$STACK_PATH/ts-config`            | `/config`                  | Tailscale serve config at runtime                    |
| `$STACK_PATH/ts-config/serve.json` | `/config/serve.json`       | Tailscale serve rules                                |

## Storage Limits

Default PHP limits allow up to 10 GB uploads (`PHP_UPLOAD_LIMIT=10G`). Adjust
in `docker-compose.yml` if you need larger uploads.

## Upgrade Nextcloud

1. Stop the stack in Portainer.
2. Pull the latest image: Portainer can do this by re-deploying the stack with
   "Re-pull image and redeploy" enabled.
3. Check the [Nextcloud changelog](https://nextcloud.com/changelog/) for any
   manual upgrade steps between major versions.

## Backups

Include `$STACK_PATH` (app, data, postgres, and ts-state) in your Synology
backup task (Hyper Backup, Syncthing, etc.). The `data` directory holds your
files; `postgres` holds the database; `ts-state` preserves the sidecar's
tailnet identity so it doesn't need re-authentication after a restore.
