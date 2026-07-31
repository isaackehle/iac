# Debug Commands

Quick reference for troubleshooting the n8n stack.

## Container Access

```bash
docker exec -it n8n-ts sh
docker exec -it n8n sh
docker exec -it n8n-browserless sh
```

## Tailscale Serve Configuration

```bash
# Inside the sidecar:
cat /config/serve.json
tailscale serve status
```

## Container Logs

```bash
docker logs n8n
docker logs n8n-ts
docker logs n8n-browserless
docker logs -f n8n
```

## Tailscale Connectivity

```bash
docker exec n8n-ts tailscale status
docker exec n8n-ts tailscale ip
docker exec n8n-ts tailscale serve status
```

## Access

- **Via Tailscale:** `https://n8n.${TS_TAILNET_DOMAIN}`

## Restart Services

```bash
docker compose -f /volume1/docker/stacks/n8n/docker-compose.yml restart
docker compose -f /volume1/docker/stacks/n8n/docker-compose.yml restart n8n
docker compose -f /volume1/docker/stacks/n8n/docker-compose.yml restart n8n-ts
docker compose -f /volume1/docker/stacks/n8n/docker-compose.yml restart browserless
```

## Config Files

| Purpose | Host Path |
|---------|-----------|
| n8n config/workflows | `/volume1/docker/stacks/n8n/config` |
| n8n files | `/volume1/docker/stacks/n8n/files` |
| Tailscale serve config | `/volume1/docker/stacks/n8n/ts-config/serve.json` |
| Tailscale state | `/volume1/docker/stacks/n8n/ts-state` |
