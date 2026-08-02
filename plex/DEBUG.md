# Debug Commands

Quick reference for troubleshooting the Plex stack.

## Container Access

```shell
docker exec -it ts-plex sh
docker exec -it plex sh
```

## Tailscale Serve Configuration

```shell
# Inside the sidecar:
cat /config/serve.json
tailscale serve status
```

## Container Logs

```shell
docker logs plex
docker logs ts-plex
docker logs -f plex
```

## Tailscale Connectivity

```shell
docker exec ts-plex tailscale status
docker exec ts-plex tailscale ip
docker exec ts-plex tailscale serve status
```

## Plex-Specific Commands

```shell
# Check Plex is responding inside the container
docker exec plex curl -sf http://localhost:32400/identity
```

## Access

- **Via Tailscale:** `https://plex.${TS_TAILNET_DOMAIN}`

## Restart Services

```shell
docker compose -f /volume1/docker/stacks/plex/docker-compose.yml restart
docker compose -f /volume1/docker/stacks/plex/docker-compose.yml restart plex
docker compose -f /volume1/docker/stacks/plex/docker-compose.yml restart ts-plex
```

## Config Files

| Purpose | Host Path |
|---------|-----------|
| Plex config | `/volume1/docker/stacks/plex/config` |
| Media libraries | `/volume1/media` (adjust as needed) |
| Tailscale serve config | `/volume1/docker/stacks/plex/ts-config/serve.json` |
| Tailscale state | `/volume1/docker/stacks/plex/ts-state` |
