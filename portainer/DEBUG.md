# Debug Commands

Quick reference for troubleshooting the Portainer stack.

## Container Access

```bash
docker exec -it portainer-ts sh
```

> ⚠️ This stack is a Tailscale sidecar that provides tailnet HTTPS access
> to Portainer itself. Portainer's main containers run via Portainer's own
> bootstrap/agent pattern.

## Tailscale Serve Configuration

```bash
# Inside the sidecar:
cat /config/serve.json
tailscale serve status
```

## Container Logs

```bash
docker logs portainer-ts
docker logs -f portainer-ts
```

## Tailscale Connectivity

```bash
docker exec portainer-ts tailscale status
docker exec portainer-ts tailscale ip
docker exec portainer-ts tailscale serve status
```

## Access

- **Via Tailscale:** `https://portainer.${TS_TAILNET_DOMAIN}`
- **Direct:** `http://<host>:9000` (HTTP), `https://<host>:9443` (HTTPS)

## Restart Services

```bash
docker compose -f /volume1/docker/stacks/portainer/docker-compose.yml restart portainer-ts
```

## Config Files

| Purpose | Host Path |
|---------|-----------|
| Tailscale serve config | `/volume1/docker/stacks/portainer/ts-config/serve.json` |
| Tailscale state | `/volume1/docker/stacks/portainer/ts-state` |
