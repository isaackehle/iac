# Debug Commands

Quick reference for troubleshooting the Home Assistant stack.

## Container Access

```bash
docker exec -it ts-homeassistant sh
```

> ⚠️ This stack only has a Tailscale sidecar container — Home Assistant itself
> is managed separately (e.g. via Home Assistant OS). The sidecar provides
> tailnet HTTPS access to it.

## Tailscale Serve Configuration

```bash
# Inside the sidecar:
cat /config/serve.json
tailscale serve status
```

## Container Logs

```bash
docker logs ts-homeassistant
docker logs -f ts-homeassistant
```

## Tailscale Connectivity

```bash
docker exec ts-homeassistant tailscale status
docker exec ts-homeassistant tailscale ip
docker exec ts-homeassistant tailscale serve status
```

## Access

- **Via Tailscale:** `https://homeassistant.${TS_TAILNET_DOMAIN}`

## Restart Services

```bash
docker compose -f /volume1/docker/stacks/homeassistant/docker-compose.yml restart ts-homeassistant
```

## Config Files

| Purpose | Host Path |
|---------|-----------|
| Tailscale serve config | `/volume1/docker/stacks/homeassistant/ts-config/serve.json` |
| Tailscale state | `/volume1/docker/stacks/homeassistant/ts-state` |
