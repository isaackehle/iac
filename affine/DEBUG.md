# Debug Commands

Quick reference for troubleshooting the Affine stack.

## Container Access

```shell
docker exec -it affine_server sh
docker exec -it affine_redis sh
docker exec -it affine_postgres sh
docker exec -it affine_migration_job sh
```

## Container Logs

```shell
docker logs affine_server
docker logs -f affine_server

# Sibling containers
docker logs affine_redis
docker logs affine_postgres
docker logs affine_migration_job
```

## Health Checks

```shell
# Redis health
docker exec affine_redis redis-cli ping

# PostgreSQL health
docker exec affine_postgres pg_isready -U root -d affine
```

## Access

- **Via Tailscale:** `https://nas.${TS_TAILNET_DOMAIN}:3010`

## Restart Services

```shell
docker compose -f /volume1/docker/stacks/affine/docker-compose.yaml restart
docker compose -f /volume1/docker/stacks/affine/docker-compose.yaml restart affine_server
```

## Config Files

| Purpose | Host Path |
|---------|-----------|
| Affine config | `/volume1/docker/stacks/affine/data/config` |
| Affine storage/uploads | `/volume1/docker/stacks/affine/data/storage` |
| PostgreSQL data | `/volume1/docker/stacks/affine/data/postgres` |
