# Debug Commands

Quick reference for troubleshooting the `langfuse` stack.

## Container Access

```shell
docker exec -it ts-langfuse sh
docker exec -it langfuse sh
docker exec -it langfuse-worker sh
docker exec -it langfuse-clickhouse sh
docker exec -it langfuse-redis sh
docker exec -it langfuse-minio sh
```

## Tailscale Serve Configuration

```shell
# View the current serve config mounted in the container
cat /config/serve.json

# Check what Tailscale Serve is doing (from inside the sidecar)
docker exec ts-langfuse tailscale serve status
```

## Container Logs

```shell
docker logs langfuse            # web/API — most user-facing errors show here
docker logs langfuse-worker      # async ingestion — if traces aren't showing up
docker logs langfuse-clickhouse
docker logs langfuse-minio
docker logs langfuse-redis
docker logs -f ts-langfuse
```

## Tailscale Connectivity

```shell
docker exec ts-langfuse tailscale status
docker exec ts-langfuse tailscale ip
docker exec ts-langfuse tailscale serve status
```

## Postgres (reused from the `postgresql` stack, not local to this one)

```shell
# From the NAS, or anywhere on the tailnet:
docker exec -it PostgreSQL psql -U root -d langfuse

# Confirm the langfuse database/user exist (one-time setup step, see
# .env.example) — if this errors, that setup step hasn't been done yet:
docker exec PostgreSQL psql -U root -c "\l" | grep langfuse
```

## Traces not showing up?

1. Confirm LiteLLM's `LITELLM_OTEL_V2=true` and `LANGFUSE_PUBLIC_KEY`/
   `LANGFUSE_SECRET_KEY`/`LANGFUSE_HOST` are actually set on the *installed*
   plist (`~/Library/LaunchAgents/com.kehle.litellm.plist`), not just the
   repo's `config.yaml` — the callback needs both.
2. `docker logs langfuse-worker` — ingestion happens here, not in the web
   container.
3. Confirm `langfuse-worker`/`clickhouse`/`redis`/`minio` can all reach
   each other — they're all on `langfuse-net`, but `langfuse` (the web
   container) only reaches them because `ts-langfuse` also joined
   `langfuse-net` and `langfuse` borrows its netns. If DNS resolution
   between them ever breaks, check that both conditions still hold.

## Restart Services

```shell
docker compose -f /volume1/docker/stacks/langfuse/docker-compose.yml restart
docker compose -f /volume1/docker/stacks/langfuse/docker-compose.yml restart langfuse
docker compose -f /volume1/docker/stacks/langfuse/docker-compose.yml restart langfuse-worker
```

## Config Files

| Purpose                | Host Path                                                |
| ----------------------- | --------------------------------------------------------- |
| ClickHouse data         | `/volume1/docker/stacks/langfuse/clickhouse-data`         |
| ClickHouse logs         | `/volume1/docker/stacks/langfuse/clickhouse-logs`         |
| MinIO data              | `/volume1/docker/stacks/langfuse/minio-data`               |
| Redis data              | `/volume1/docker/stacks/langfuse/redis-data`                |
| Tailscale serve config  | `/volume1/docker/stacks/langfuse/ts-config/serve.json`    |
| Tailscale state         | `/volume1/docker/stacks/langfuse/ts-state`                  |

## Access

- **Web UI (via Tailscale):** `https://langfuse.${TS_TAILNET_DOMAIN}`
- **MinIO S3 API (direct, for media uploads):** `<nas-tailscale-ip>:9090`
