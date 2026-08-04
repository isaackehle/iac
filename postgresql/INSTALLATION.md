# PostgreSQL — Portainer Stack Deployment

> **Recommended:** `scripts/deploy.sh all postgresql <ssh-host>` from the repo root handles directory setup, `.env` generation, file placement, and bringing the
> stack up in one step — see root `README.md`/`QUICKSTART.md`. The manual steps below are the equivalent broken out.

## Directory Setup (on Synology NAS)

```shell
STACK_PATH="/volume1/docker/stacks/postgresql"

mkdir -p $STACK_PATH/{data,pgadmin,ts-state,ts-config}
```

## Deploy via Portainer

1. Go to **Stacks → Add stack**
2. Choose **Repository** as the build method
3. Set:
   - **Repository URL:** `https://github.com/isaackehle/iac.git`
   - **Repository reference:** `refs/heads/main`
   - **Compose path:** `postgresql/docker-compose.yml`
4. Under **Environment variables**, fill in:
   - `POSTGRES_PASSWORD` — PostgreSQL superuser password (choose a strong password)
   - `PGADMIN_DEFAULT_EMAIL` — pgAdmin admin email (e.g., `you@example.com`)
   - `PGADMIN_DEFAULT_PASSWORD` — pgAdmin admin password (can be different from Postgres password)
   - `TS_AUTHKEY` — Tailscale auth key (optional, for future sidecar integration)
   - `TS_CERT_DOMAIN` — Tailscale MagicDNS domain (auto-derived as `postgresql.${TS_TAILNET_DOMAIN}`)
5. Click **Deploy the stack**

---

## Deploy via SSH (Recommended for GitOps)

> **Recommended:** `scripts/deploy.sh all postgresql <ssh-host>` from the repo root handles everything in one step.

### Prerequisites

- SSH access to the NAS (e.g., `nas` alias in `~/.ssh/config`)
- The `scripts/deploy.sh` and `scripts/gen-env.sh` tools available on your laptop
- The central secrets file `iac-secrets.env` with `POSTGRES_PASSWORD`, `PGADMIN_DEFAULT_EMAIL`, and `PGADMIN_DEFAULT_PASSWORD` set

### One-Line Deployment

```shell
cd ~/code/isaackehle/iac
scripts/deploy.sh all postgresql nas
```

This single command does:

1. Generates `postgresql/env.txt` from `iac-secrets.env`
2. Creates `/volume1/docker/stacks/postgresql/{data,pgadmin,ts-state,ts-config}` on the NAS
3. Copies `docker-compose.yml`, `env.txt`, and any extra files via SCP
4. Runs `docker compose up -d` on the NAS

### Step-by-Step (if you need more control)

```shell
# 1. Generate env.txt locally
scripts/gen-env.sh postgresql

# 2. Create directories on the NAS
ssh nas "mkdir -p /volume1/docker/stacks/postgresql/{data,pgadmin,ts-state,ts-config}"

# 3. Push files to the NAS
scp -O postgresql/docker-compose.yml nas:/volume1/docker/stacks/postgresql/
scp -O postgresql/env.txt nas:/volume1/docker/stacks/postgresql/

# 4. Start the stack
ssh nas "cd /volume1/docker/stacks/postgresql && docker compose up -d"
```

### Verify Deployment

```shell
# Check containers are running
ssh nas "docker ps | grep -E 'postgresql|pgAdmin'"

# Check logs
ssh nas "docker logs --tail 50 postgresql"
ssh nas "docker logs --tail 50 pgAdmin"

# Verify pgAdmin is accessible
curl -v https://nas.tail303fda.ts.net:2660
```

---

## What the Stack Contains

| Container    | Image                   | Role                                                                         |
| ------------ | ----------------------- | ---------------------------------------------------------------------------- |
| `postgresql` | `postgres`              | PostgreSQL database server — listens on port 5432 (mapped to host port 2665) |
| `pgAdmin`    | `dpage/pgadmin4:latest` | pgAdmin web interface — PostgreSQL administration tool                       |

The stack publishes two ports on the NAS host:

- **2665:5432** — PostgreSQL database port (for client connections)
- **2660:5050** — pgAdmin web interface (for database administration)

## First-Run PostgreSQL Setup

1. Wait for the stack to start (check `docker ps` for both containers)
2. Access pgAdmin:
   - Open `https://nas.tail303fda.ts.net:2660` (or the direct Tailscale IP)
   - Log in with the `PGADMIN_DEFAULT_EMAIL` / `PGADMIN_DEFAULT_PASSWORD` credentials
3. Create a new server connection in pgAdmin:
   - Right-click **Servers → Create → Server**
   - Name: `NAS PostgreSQL`
   - Host: `localhost` (or the NAS's Tailscale IP)
   - Port: `5432`
   - Maintenance database: `thunder_db` (default)
   - Username: `root`
   - Password: the `POSTGRES_PASSWORD` you set
4. Verify the database is running:

   ```shell
   docker logs postgresql | grep "database system is ready"
   ```

## Persistent Data

| Host Path                          | Container Path        | Contents                                                   |
| ---------------------------------- | --------------------- | ---------------------------------------------------------- |
| `$STACK_PATH/data`                 | `/var/lib/postgresql` | PostgreSQL database files (all databases, tables, indexes) |
| `$STACK_PATH/pgadmin`              | `/var/lib/pgadmin`    | pgAdmin settings, saved servers, query history             |
| `$STACK_PATH/ts-state`             | `/var/lib/tailscale`  | Tailscale identity (for future sidecar integration)        |
| `$STACK_PATH/ts-config/serve.json` | `/config/serve.json`  | Tailscale serve rules (for future sidecar integration)     |

## Access

| URL/Endpoint                         | Description                                              |
| ------------------------------------ | -------------------------------------------------------- |
| `https://nas.tail303fda.ts.net:2660` | pgAdmin Web UI (tailnet-only, via host-level serve)      |
| `postgresql.tail303fda.ts.net:2665`  | PostgreSQL database (tailnet-only, via host-level serve) |
| `<NAS-Tailscale-IP>:2665`            | Direct Tailscale IP access to PostgreSQL                 |
| `<NAS-LAN-IP>:2665`                  | LAN access to PostgreSQL (if NAS is on same network)     |

## Common PostgreSQL Operations

### Connect via psql CLI

```shell
# From your laptop (install postgresql-client if needed):
brew install postgresql-client

# Connect to the database:
psql -h postgresql.tail303fda.ts.net -p 2665 -U root -d thunder_db

# Enter the POSTGRES_PASSWORD when prompted
```

### Create a New Database

```sql
-- In pgAdmin or via psql:
CREATE DATABASE myapp;
```

### Create a New User

```sql
-- In pgAdmin or via psql:
CREATE USER myapp_user WITH PASSWORD 'strong-password';
GRANT ALL PRIVILEGES ON DATABASE myapp TO myapp_user;
```

### Backup a Database

```shell
# From your laptop:
pg_dump -h postgresql.tail303fda.ts.net -p 2665 -U root -d thunder_db > backup.sql

# Or from the NAS shell:
docker exec postgresql pg_dump -U root thunder_db > /volume1/docker/stacks/postgresql/backup.sql
```

### Restore a Database

```shell
# From the NAS shell:
docker exec -i postgresql psql -U root thunder_db < /volume1/docker/stacks/postgresql/backup.sql
```

## Backups

Include `$STACK_PATH/data` in your Synology backup task (Hyper Backup, Syncthing, etc.). This directory contains:

- All PostgreSQL database files
- All databases, tables, indexes, and data
- Transaction logs

**Critical:** Back up this directory regularly — it's the most important data in the entire stack.

## Troubleshooting

### Container Won't Start

1. Check logs:

   ```shell
   docker logs postgresql
   docker logs pgAdmin
   ```

2. Verify `POSTGRES_PASSWORD` is set (required)
3. Check if port 2665 is already in use:

   ```shell
   docker ps | grep 2665
   ```

### Can't Connect to Database

1. Verify the container is running:

   ```shell
   docker ps | grep postgresql
   ```

2. Check the database is ready:

   ```shell
   docker exec postgresql pg_isready -U root -d thunder_db
   ```

3. Verify the port mapping:

   ```shell
   docker ps | grep postgresql
   # Should show: 0.0.0.0:2665->5432/tcp
   ```

### pgAdmin Won't Start

1. Check logs:

   ```shell
   docker logs pgAdmin
   ```

2. Verify `PGADMIN_DEFAULT_EMAIL` and `PGADMIN_DEFAULT_PASSWORD` are set
3. Check if port 2660 is already in use

### Database Corruption

1. Stop the stack:

   ```shell
   docker compose down
   ```

2. Check the data directory:

   ```shell
   ls -la /volume1/docker/stacks/postgresql/data/
   ```

3. If the directory is empty or missing, you may need to restore from backup
4. Restart the stack:

   ```shell
   docker compose up -d
   ```

## References

- [PostgreSQL Documentation](https://www.postgresql.org/docs/)
- [pgAdmin Documentation](https://www.pgadmin.org/docs/)
- [PostgreSQL Docker Image](https://hub.docker.com/_/postgres)
- [pgAdmin Docker Image](https://hub.docker.com/r/dpage/pgadmin4)
