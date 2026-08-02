# Debug Commands

Quick reference for troubleshooting the PostgreSQL stack.

## Container Access

```shell
docker exec -it PostgreSQL sh
docker exec -it pgAdmin sh
```

## Container Logs

```shell
docker logs PostgreSQL
docker logs pgAdmin
docker logs -f PostgreSQL
```

## Databases hosted here for other stacks

This shared instance backs more than just `thunder_db` — rather than run a
dedicated Postgres per stack, other stacks get their own database + user
created here once, manually (the postgres image's init-db scripts only run
against an empty data dir, and this instance already has data):

| Database   | User       | Used by                                                                                |
| ---------- | ---------- | -------------------------------------------------------------------------------------- |
| `litellm`  | `litellm`  | LiteLLM Proxy's Admin UI (`homelab` repo, discovery) — `general_settings.database_url` |
| `langfuse` | `langfuse` | The `langfuse` stack in this repo                                                      |

To add a new one:

```shell
docker exec -it PostgreSQL psql -U root -c "CREATE DATABASE <name>;"
docker exec -it PostgreSQL psql -U root -c "CREATE USER <name> WITH PASSWORD '<password>';"
docker exec -it PostgreSQL psql -U root -c "GRANT ALL PRIVILEGES ON DATABASE <name> TO <name>;"
```

Connect from elsewhere on the tailnet via `postgresql://<user>:<password>@<host>:2665/<name>`.

## Database Commands

```shell
# Connect to PostgreSQL
docker exec -it PostgreSQL psql -U root -d thunder_db

# List databases
docker exec PostgreSQL psql -U root -l

# Check database size
docker exec PostgreSQL psql -U root -d thunder_db -c "SELECT pg_database_size('thunder_db');"

# View active connections
docker exec PostgreSQL psql -U root -d thunder_db -c "SELECT * FROM pg_stat_activity;"
```

## pgAdmin

```shell
# Verify pgAdmin is responding
docker exec pgAdmin wget -qO- http://localhost:5050 | head -20
```

## Access

- **PostgreSQL (host):** `<host>:2665` → `5454` inside container
- **pgAdmin (via Tailscale):** `https://nas.${TS_TAILNET_DOMAIN}:2660`
- **pgAdmin (direct):** `http://<host>:2660`

## Restart Services

```shell
docker compose -f /volume1/docker/stacks/postgresql/docker-compose.yml restart
docker compose -f /volume1/docker/stacks/postgresql/docker-compose.yml restart PostgreSQL
docker compose -f /volume1/docker/stacks/postgresql/docker-compose.yml restart pgAdmin
```

## Config Files

| Purpose         | Host Path                                   |
| --------------- | ------------------------------------------- |
| PostgreSQL data | `/volume1/docker/stacks/postgresql`         |
| pgAdmin data    | `/volume1/docker/stacks/postgresql/pgadmin` |
