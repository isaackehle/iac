# Debug Commands

Quick reference for troubleshooting the Plex stack.

## Container Access

```bash
docker exec -it ts-plex sh
docker exec -it plex sh
```

## Tailscale Serve Configuration

```bash
# Inside the sidecar:
cat /config/serve.json
tailscale serve status
```

## Container Logs

```bash
docker logs plex
docker logs ts-plex
docker logs -f plex
```

## Tailscale Connectivity

```bash
docker exec ts-plex tailscale status
docker exec ts-plex tailscale ip
docker exec ts-plex tailscale serve status
```

## Plex-Specific Commands

```bash
# Check Plex is responding inside the container
docker exec plex curl -sf http://localhost:32400/identity
```

## Access

- **Via Tailscale:** `https://plex.${TS_TAILNET_DOMAIN}`

## Restart Services

```bash
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
