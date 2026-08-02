# Debug Commands

Quick reference for troubleshooting the Portainer stack.

## Container Access

```shell
docker exec -it ts-portainer sh
```

> ⚠️ This stack is a Tailscale sidecar that provides tailnet HTTPS access
> to Portainer itself. Portainer's main containers run via Portainer's own
> bootstrap/agent pattern.

## Tailscale Serve Configuration

```shell
# Inside the sidecar:
cat /config/serve.json
tailscale serve status
```

## Container Logs

```shell
docker logs ts-portainer
docker logs -f ts-portainer
```

## Tailscale Connectivity

```shell
docker exec ts-portainer tailscale status
docker exec ts-portainer tailscale ip
docker exec ts-portainer tailscale serve status
```

## Access

- **Via Tailscale:** `https://portainer.${TS_TAILNET_DOMAIN}`
- **Direct:** `http://<host>:9000` (HTTP), `https://<host>:9443` (HTTPS)

## Restart Services

```shell
docker compose -f /volume1/docker/stacks/portainer/docker-compose.yml restart ts-portainer
```

## Config Files

| Purpose                | Host Path                                               |
| ---------------------- | ------------------------------------------------------- |
| Tailscale serve config | `/volume1/docker/stacks/portainer/ts-config/serve.json` |
| Tailscale state        | `/volume1/docker/stacks/portainer/ts-state`             |
