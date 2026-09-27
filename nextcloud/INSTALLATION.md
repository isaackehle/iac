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
   - **Repository URL:** `https://github.com/isaackehle/iac.git`
   - **Repository reference:** `refs/heads/main`
   - **Compose path:** `nextcloud/docker-compose.yml`
4. Under **Environment variables**, fill in the values from `.env.example`:
   - `NC_DB_PASSWORD` — PostgreSQL password for the `nextcloud` user
   - `NC_ADMIN_USER` / `NC_ADMIN_PASSWORD` — Nextcloud admin account
   - `TS_AUTHKEY` — Tailscale auth key (reusable, pre-authorized)
   - `TS_CERT_DOMAIN` — Tailscale MagicDNS domain (e.g. `nextcloud.${TS_TAILNET_DOMAIN}`)
5. Click **Deploy the stack**

## What the Stack Contains

| Container           | Image                        | Role                                                                              |
| ------------------- | ---------------------------- | --------------------------------------------------------------------------------- |
| `nextcloud`         | `nextcloud:apache`           | The app. Owns the network namespace; LAN port `8281` → `80`                        |
| `nextcloud-tailscale` | `tailscale/tailscale:latest` | Sidecar in the app's namespace; serves HTTPS on 443 → `127.0.0.1:80`            |
| `nextcloud-db`      | `postgres:16`                | PostgreSQL, persistent at `$STACK_PATH/postgres`; has a `pg_isready` healthcheck  |
| `nextcloud-db-init` | `postgres:16`                | One-shot: grants `CREATE` on schema `public`, then exits (see below)              |
| `nextcloud-cron`    | `nextcloud:apache`           | Runs background jobs (`cron.php`) every 5 minutes                                 |
| `nextcloud-redis`   | `redis:7-alpine`             | Cache and file locking                                                            |

The app, database, init, cron and Redis containers are on `nextcloud-net`
(`172.20.30.0/24`). Nextcloud starts only after the database is healthy and
`db-init` has finished.

### Why `db-init`

Nextcloud's installer creates its own database user (`oc_<admin>`). Since
PostgreSQL 15, only the owner of schema `public` may create tables in it, so
that user can't, and the install fails with "no schema has been selected to
create in" or "permission denied for table oc_migrations". `db-init` runs
`GRANT USAGE, CREATE ON SCHEMA public TO PUBLIC` on every start; it's
harmless once granted, and the database holds nothing but Nextcloud.

On a database created before this service existed, run it once by hand:

```shell
docker exec nextcloud-db psql -U nextcloud -d nextcloud -c "GRANT USAGE, CREATE ON SCHEMA public TO PUBLIC"
```

## First-Run Nextcloud Setup

1. From a device on your tailnet, visit `https://nextcloud.${TS_TAILNET_DOMAIN}`
2. Log in with the `NC_ADMIN_USER` / `NC_ADMIN_PASSWORD` credentials.
3. Go to **Administration settings → Overview** and verify:
   - Database is PostgreSQL (connected to `nextcloud-db`)
   - Redis is configured for caching
   - Background jobs use Cron (next step)

## Background Jobs (Cron)

`nextcloud-cron` runs `cron.php` every 5 minutes. Nextcloud still defaults to
AJAX mode (jobs run only while someone has it open), so switch it once after
the first install:

```shell
docker exec -u www-data nextcloud php occ background:cron
```

Check: **Administration settings → Basic settings** shows "Cron" with a recent
last run.

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
