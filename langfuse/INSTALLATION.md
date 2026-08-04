# Langfuse — Portainer Stack Deployment

> **Recommended:** `scripts/deploy.sh all langfuse <ssh-host>` from the repo root handles directory setup, `.env` generation, file placement, and bringing the
> stack up in one step — see root `README.md`/`QUICKSTART.md`. The manual steps below are the equivalent broken out.

## Prerequisites

### 1. Create the Langfuse database in PostgreSQL

Langfuse **reuses** the existing `postgresql` stack — it does **not** run its own Postgres. Before deploying, connect to the PostgreSQL stack and create the database/user:

```shell
# Connect to the postgresql stack:
docker exec -it postgresql psql -U root -d thunder_db

# Create the langfuse database and user:
CREATE DATABASE langfuse;
CREATE USER langfuse WITH PASSWORD '<your-strong-password>';
GRANT ALL PRIVILEGES ON DATABASE langfuse TO langfuse;
\q
```

Replace `<your-strong-password>` with the same value you'll set as `LANGFUSE_DB_PASSWORD` in the environment variables.

### 2. Directory Setup (on Synology NAS)

```shell
STACK_PATH="/volume1/docker/stacks/langfuse"

mkdir -p $STACK_PATH/{clickhouse-data,clickhouse-logs,redis-data,minio-data,ts-state,ts-config}
```

Copy `serve.json` into `$STACK_PATH/ts-config/` — the sidecar mounts the whole `ts-config` directory at `/config`, so the file lands at `/config/serve.json`.

## Deploy via Portainer

1. Go to **Stacks → Add stack**
2. Choose **Repository** as the build method
3. Set:
   - **Repository URL:** `https://github.com/isaackehle/iac.git`
   - **Repository reference:** `refs/heads/main`
   - **Compose path:** `langfuse/docker-compose.yml`
4. Under **Environment variables**, fill in all required values (no working defaults — the stack fails to start rather than running with placeholders):

### Required Environment Variables

| Variable | Description | How to Generate |
|----------|-------------|-----------------|
| `LANGFUSE_DB_PASSWORD` | PostgreSQL password for the `langfuse` user | Choose a strong password (same as used in CREATE USER above) |
| `LANGFUSE_DB_HOST` | NAS LAN IP (e.g., `192.168.1.100`) | The NAS's LAN IP address |
| `LANGFUSE_CLICKHOUSE_PASSWORD` | ClickHouse password | `openssl rand -base64 32` |
| `LANGFUSE_REDIS_AUTH` | Redis password | `openssl rand -base64 32` |
| `LANGFUSE_MINIO_ROOT_PASSWORD` | MinIO password | `openssl rand -base64 32` |
| `LANGFUSE_SALT` | App salt | `openssl rand -hex 32` |
| `LANGFUSE_NEXTAUTH_SECRET` | NextAuth secret | `openssl rand -hex 32` |
| `LANGFUSE_ENCRYPTION_KEY` | 64-hex encryption key | `openssl rand -hex 32` |
| `LANGFUSE_INIT_PROJECT_PUBLIC_KEY` | API public key | `python3 -c "import secrets; print('pk-lf-' + secrets.token_hex(16))"` |
| `LANGFUSE_INIT_PROJECT_SECRET_KEY` | API secret key | `python3 -c "import secrets; print('sk-lf-' + secrets.token_hex(16))"` |
| `LANGFUSE_INIT_USER_EMAIL` | Admin email | Your email address |
| `LANGFUSE_INIT_USER_PASSWORD` | Admin password | Choose a strong password |
| `TS_AUTHKEY` | Tailscale auth key | Generate at <https://login.tailscale.com/admin/settings/keys> (reusable, pre-authorized) |
| `TS_CERT_DOMAIN` | Tailscale MagicDNS domain | Auto-derived as `langfuse.${TS_TAILNET_DOMAIN}` |

5. Click **Deploy the stack**

---

## Deploy via SSH (Recommended for GitOps)

> **Recommended:** `scripts/deploy.sh all langfuse <ssh-host>` from the repo root handles everything in one step.

### Prerequisites

- SSH access to the NAS (e.g., `nas` alias in `~/.ssh/config`)
- The `scripts/deploy.sh` and `scripts/gen-env.sh` tools available on your laptop
- The central secrets file `iac-secrets.env` with all required Langfuse secrets set
- **Important:** Create the `langfuse` database in PostgreSQL first (see Prerequisites section above)

### One-Line Deployment

```shell
cd ~/code/isaackehle/iac
scripts/deploy.sh all langfuse nas
```

This single command does:

1. Generates `langfuse/env.txt` from `iac-secrets.env`
2. Creates `/volume1/docker/stacks/langfuse/{clickhouse-data,clickhouse-logs,redis-data,minio-data,ts-state,ts-config}` on the NAS
3. Copies `docker-compose.yml`, `env.txt`, and `serve.json` via SCP
4. Runs `docker compose up -d` on the NAS

### Step-by-Step (if you need more control)

```shell
# 1. Create the langfuse database in PostgreSQL first
docker exec -it postgresql psql -U root -d thunder_db <<EOF
CREATE DATABASE langfuse;
CREATE USER langfuse WITH PASSWORD 'your-strong-password';
GRANT ALL PRIVILEGES ON DATABASE langfuse TO langfuse;
EOF

# 2. Generate env.txt locally
scripts/gen-env.sh langfuse

# 3. Create directories on the NAS
ssh nas "mkdir -p /volume1/docker/stacks/langfuse/{clickhouse-data,clickhouse-logs,redis-data,minio-data,ts-state,ts-config}"

# 4. Push files to the NAS
scp -O langfuse/docker-compose.yml nas:/volume1/docker/stacks/langfuse/
scp -O langfuse/env.txt nas:/volume1/docker/stacks/langfuse/
scp -O langfuse/serve.json nas:/volume1/docker/stacks/langfuse/ts-config/

# 5. Start the stack
ssh nas "cd /volume1/docker/stacks/langfuse && docker compose up -d"
```

### Verify Deployment

```shell
# Check containers are running
ssh nas "docker ps | grep langfuse"

# Check logs
ssh nas "docker logs --tail 50 langfuse"

# Verify Langfuse is accessible
curl -v https://langfuse.tail303fda.ts.net
```

---

## What the Stack Contains

| Container | Image | Role |
|-----------|-------|------|
| `langfuse` | `langfuse/langfuse:3` | Web/API — main application |
| `langfuse-worker` | `langfuse/langfuse-worker:3` | Async trace ingestion — if traces aren't showing in the UI, check this container's logs first |
| `ts-langfuse` | `tailscale/tailscale:latest` | Tailscale sidecar — Langfuse is only reachable via your tailnet |
| `langfuse-clickhouse` | `clickhouse/clickhouse-server:24.3` | Trace/observation storage |
| `langfuse-redis` | `redis:7-alpine` | Queues/caching |
| `langfuse-minio` | `minio/minio:latest` | S3-compatible blob storage for event/media payloads |

All containers share the `langfuse-net` bridge network. The `langfuse` container uses `network_mode: service:ts-langfuse` — it borrows the sidecar's network
namespace entirely, so it has no `ports:` of its own. That means Langfuse is reachable **only** via the tailnet hostname.

**Note:** MinIO's S3 API is published directly on the `minio` sibling (host port 9090), deliberately not routed through the sidecar — see README.md's port registry.

## First-Run Langfuse Setup

1. From a device on your tailnet, visit `https://langfuse.${TS_TAILNET_DOMAIN}`
2. You should land directly on the Langfuse dashboard (no signup wizard — headless bootstrap via `LANGFUSE_INIT_*` variables)
3. Log in with the `LANGFUSE_INIT_USER_EMAIL` / `LANGFUSE_INIT_USER_PASSWORD` credentials
4. Verify the setup:
   - Go to **Settings → Overview** and check database connectivity
   - Check that traces are appearing in the UI (if not, check `langfuse-worker` logs)

## Persistent Data

| Host Path | Container Path | Contents |
|-----------|----------------|----------|
| `$STACK_PATH/clickhouse-data` | `/var/lib/clickhouse` | ClickHouse trace/observation data |
| `$STACK_PATH/clickhouse-logs` | `/var/log/clickhouse-server` | ClickHouse logs |
| `$STACK_PATH/redis-data` | `/data` | Redis cache/queues |
| `$STACK_PATH/minio-data` | `/data/langfuse` | MinIO event/media blobs |
| `$STACK_PATH/ts-state` | `/var/lib/tailscale` | Tailscale identity (survives container recreation) |
| `$STACK_PATH/ts-config/serve.json` | `/config/serve.json` | Tailscale serve rules |

## Access

| URL | Description |
|-----|-------------|
| `https://langfuse.${TS_TAILNET_DOMAIN}` | Langfuse Web UI (tailnet-only) |
| `http://<NAS-Tailscale-IP>:9090` | MinIO S3 API (direct, not via sidecar) |

## Backups

Include `$STACK_PATH` (all data directories and `ts-state`) in your Synology backup task (Hyper Backup, Syncthing, etc.). Critical directories:

- `clickhouse-data` — all trace/observation data
- `redis-data` — cache/queues (can be regenerated, but improves performance)
- `minio-data` — event/media blobs
- `ts-state` — preserves the sidecar's tailnet identity so it doesn't need re-authentication after a restore

## Upgrade Langfuse

1. Stop the stack in Portainer
2. Pull the latest images:

   ```shell
   cd /volume1/docker/stacks/langfuse
   docker compose pull
   ```

3. Restart the stack:

   ```shell
   docker compose down && docker compose up -d
   ```

4. Check the [Langfuse changelog](https://github.com/langfuse/langfuse/releases) for any manual upgrade steps between major versions

## Troubleshooting

### Traces Not Appearing in UI

1. Check the worker logs:

   ```shell
   docker logs --tail 100 langfuse-worker
   ```

2. Verify ClickHouse is healthy:

   ```shell
   docker exec langfuse-clickhouse wget -qO- http://localhost:8123/ping
   ```

3. Verify Redis is accessible:

   ```shell
   docker exec langfuse-redis redis-cli -a $LANGFUSE_REDIS_AUTH ping
   ```

### Sidecar Not Accessible

1. Check all containers are running with matching uptimes:

   ```shell
   docker ps --format '{{.Names}}\t{{.RunningSince}}'
   ```

2. If `ts-langfuse` has been running much longer than others, restart the entire stack:

   ```shell
   cd /volume1/docker/stacks/langfuse
   docker compose down
   docker compose up -d
   ```

### Database Connection Failed

1. Verify the `langfuse` database and user exist in PostgreSQL:

   ```shell
   docker exec -it postgresql psql -U root -d thunder_db -c "\l" -c "\du"
   ```

2. Check `LANGFUSE_DB_HOST` is set to the NAS's LAN IP (not `localhost`)
3. Verify the password matches what you set in `CREATE USER`

## References

- [Langfuse Documentation](https://langfuse.com/docs)
- [Langfuse Docker Image](https://hub.docker.com/r/langfuse/langfuse)
- [ClickHouse Documentation](https://clickhouse.com/docs)
- [MinIO Documentation](https://min.io/docs/minio/linux/index.html)
