# Debug Commands

Quick reference for troubleshooting the PostgreSQL stack.

## Container Access

```bash
docker exec -it PostgreSQL sh
docker exec -it pgAdmin sh
```

## Container Logs

```bash
docker logs PostgreSQL
docker logs pgAdmin
docker logs -f PostgreSQL
```

## Database Commands

```bash
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

```bash
# Verify pgAdmin is responding
docker exec pgAdmin wget -qO- http://localhost:5050 | head -20
```

## Access

- **PostgreSQL (host):** `<host>:2665` → `5454` inside container
- **pgAdmin (via Tailscale):** `https://nas.${TS_TAILNET_DOMAIN}:2660`
- **pgAdmin (direct):** `http://<host>:2660`

## Restart Services

```bash
docker compose -f /volume1/docker/stacks/postgresql/docker-compose.yml restart
docker compose -f /volume1/docker/stacks/postgresql/docker-compose.yml restart PostgreSQL
docker compose -f /volume1/docker/stacks/postgresql/docker-compose.yml restart pgAdmin
```

## Config Files

| Purpose | Host Path |
|---------|-----------|
| PostgreSQL data | `/volume1/docker/stacks/postgresql` |
| pgAdmin data | `/volume1/docker/stacks/postgresql/pgadmin` |
