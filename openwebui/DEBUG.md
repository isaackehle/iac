# Debug Commands

Quick reference for troubleshooting the OpenWebUI stack.

## Container Access

```bash
docker exec -it openwebui-ts sh
docker exec -it openwebui sh
docker exec -it openwebui-config sh
```

## Tailscale Serve Configuration

```bash
# Inside the sidecar:
cat /config/serve.json
tailscale serve status
```

## Container Logs

```bash
docker logs openwebui
docker logs openwebui-ts
docker logs openwebui-config
docker logs -f openwebui
```

## Tailscale Connectivity

```bash
docker exec openwebui-ts tailscale status
docker exec openwebui-ts tailscale ip
docker exec openwebui-ts tailscale serve status
```

## OpenWebUI-Specific Commands

```bash
# Check if OpenWebUI is responding inside the container
docker exec openwebui curl -sf http://localhost:8080/health

# View Ollama engine config
docker exec openwebui-config cat /scripts/configure-ollama.sh
```

## Access

- **Via Tailscale:** `https://openwebui.${TS_TAILNET_DOMAIN}`

## Restart Services

```bash
docker compose -f /volume1/docker/stacks/openwebui/docker-compose.yml restart
docker compose -f /volume1/docker/stacks/openwebui/docker-compose.yml restart openwebui
docker compose -f /volume1/docker/stacks/openwebui/docker-compose.yml restart openwebui-ts
```

## Config Files

| Purpose | Host Path |
|---------|-----------|
| OpenWebUI data | `/volume1/docker/stacks/openwebui/data` |
| Tailscale serve config | `/volume1/docker/stacks/openwebui/ts-config/serve.json` |
| Tailscale state | `/volume1/docker/stacks/openwebui/ts-state` |
