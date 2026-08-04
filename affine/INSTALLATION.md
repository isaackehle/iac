# Affine — Portainer Stack Deployment

> **Recommended:** `scripts/deploy.sh all affine <ssh-host>` from the repo root handles directory setup, `.env` generation, file placement, and bringing the stack up in one step — see root `README.md`/`QUICKSTART.md`. The manual steps below are the equivalent broken out.

## Directory Setup (on Synology NAS)

```shell
STACK_PATH="/volume1/docker/stacks/affine"

mkdir -p $STACK_PATH/{data/storage,data/config,data/postgres}
```

## Deploy via Portainer

1. Go to **Stacks → Add stack**
2. Choose **Repository** as the build method
3. Set:
   - **Repository URL:** `https://github.com/isaackehle/iac.git`
   - **Repository reference:** `refs/heads/main`
   - **Compose path:** `affine/docker-compose.yml`
4. Under **Environment variables**, fill in:
   - `AFFINE_REVISION` — Affine version tag (default: `stable`)
   - `PORT` — Web UI port (default: `3010`)
   - `UPLOAD_LOCATION` — Upload storage path (default: `./data/storage`)
   - `CONFIG_LOCATION` — Config path (default: `./data/config`)
   - `DB_DATA_LOCATION` — PostgreSQL data path (default: `./data/postgres`)
   - `DB_USERNAME` — PostgreSQL username (default: `affine`)
   - `DB_PASSWORD` — PostgreSQL password (choose a strong password)
   - `DB_DATABASE` — Database name (default: `affine`)
   - `TS_AUTHKEY` — Tailscale auth key (optional, for future sidecar integration)
   - `TS_CERT_DOMAIN` — Tailscale MagicDNS domain (auto-derived as `affine.${TS_TAILNET_DOMAIN}`)
5. Click **Deploy the stack**

## What the Stack Contains

| Container | Image | Role |
|-----------|-------|------|
| `affine_server` | `ghcr.io/toeverything/affine:stable` | Affine web application |
| `affine_migration_job` | `ghcr.io/toeverything/affine:stable` | Database migration runner (one-time) |
| `affine_postgres` | `pgvector/pgvector:pg16` | PostgreSQL database with vector support |
| `affine_redis` | `redis` | Redis cache |

The stack includes an embedded PostgreSQL database and Redis cache — it's self-contained and doesn't rely on external services.

## First-Run Affine Setup

1. Wait for the stack to start (check `docker ps` for all containers)
2. The migration job will run first — check logs:
   ```shell
   docker logs affine_migration_job
   ```
3. Once migrations complete, access the web UI:
   - Open `https://nas.tail303fda.ts.net:3010` (or the direct Tailscale IP)
4. Create your admin account
5. Start using Affine for collaborative whiteboarding and note-taking

## Persistent Data

| Host Path | Container Path | Contents |
|-----------|----------------|----------|
| `$STACK_PATH/data/storage` | `/root/.affine/storage` | User uploads, attachments, media files |
| `$STACK_PATH/data/config` | `/root/.affine/config` | Application configuration |
| `$STACK_PATH/data/postgres` | `/var/lib/postgresql/data` | PostgreSQL database files |

## Access

| URL/Endpoint | Description |
|--------------|-------------|
| `https://nas.tail303fda.ts.net:3010` | Affine Web UI (tailnet-only, via host-level serve) |
| `affine.tail303fda.ts.net:3010` | Affine Web UI (tailnet-only, via host-level serve) |
| `<NAS-Tailscale-IP>:3010` | Direct Tailscale IP access |
| `<NAS-LAN-IP>:3010` | LAN access (if NAS is on same network) |

## Common Affine Operations

### View Logs

```shell
# Application logs:
docker logs affine_server

# Migration logs (one-time):
docker logs affine_migration_job

# Database logs:
docker logs affine_postgres

# Redis logs:
docker logs affine_redis
```

### Restart Affine

```shell
docker compose down && docker compose up -d
```

### Check Database Status

```shell
docker exec affine_postgres pg_isready -U affine -d affine
```

### Check Redis Status

```shell
docker exec affine_redis redis-cli ping
```

### Backup Database

```shell
# From the NAS shell:
docker exec affine_postgres pg_dump -U affine affine > /volume1/docker/stacks/affine/backup.sql

# Or backup the entire data directory:
tar czf /volume1/docker/stacks/affine/backup.tar.gz /volume1/docker/stacks/affine/data
```

## Backups

Include `$STACK_PATH/data` in your Synology backup task (Hyper Backup, Syncthing, etc.). This directory contains:
- PostgreSQL database files (all documents, pages, user data)
- User uploads and attachments
- Application configuration

**Critical:** Back up this directory regularly — it's your entire Affine instance.

## Troubleshooting

### Migration Job Fails

1. Check migration logs:
   ```shell
   docker logs affine_migration_job
   ```
2. Verify PostgreSQL is healthy:
   ```shell
   docker exec affine_postgres pg_isready -U affine -d affine
   ```
3. Check Redis is accessible:
   ```shell
   docker exec affine_redis redis-cli ping
   ```

### Can't Access Web UI

1. Verify the Tailscale serve mapping is applied:
   ```shell
   ssh <ssh-host> "sudo tailscale serve status"
   ```
2. Check the container is running:
   ```shell
   docker ps | grep affine_server
   ```
3. Test from the NAS shell:
   ```shell
   curl http://127.0.0.1:3010
   ```

### Database Connection Failed

1. Check PostgreSQL logs:
   ```shell
   docker logs affine_postgres
   ```
2. Verify the database exists:
   ```shell
   docker exec affine_postgres psql -U affine -d affine -c "\l"
   ```
3. Check the password matches what's in the environment variables

### Redis Not Responding

1. Check Redis logs:
   ```shell
   docker logs affine_redis
   ```
2. Test Redis connectivity:
   ```shell
   docker exec affine_redis redis-cli ping
   ```
3. Verify Redis is healthy:
   ```shell
   docker exec affine_redis redis-cli --raw incr ping
   ```

## References

- [Affine Documentation](https://docs.affine.pro/)
- [Affine GitHub](https://github.com/toeverything/AFFiNE)
- [pgvector Documentation](https://github.com/pgvector/pgvector)
