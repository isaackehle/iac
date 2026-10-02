# Debug Commands

Quick reference for troubleshooting the `actualbudget` + Tailscale stack.

Replace `actualbudget`, `actualbudget-tailscale`, and `/volume1/docker/stacks/actualbudget` with real values.

## Container Access

```shell
# Enter the Tailscale sidecar container
docker exec -it actualbudget-tailscale sh

# Enter the app container
docker exec -it actualbudget sh
```

## Tailscale Serve Configuration

```shell
# View the current serve config mounted in the container
cat /config/serve.json

# Check what Tailscale Serve is doing (from inside the sidecar)
docker exec actualbudget-tailscale tailscale serve status
```

## Container Logs

```shell
# App logs
docker logs actualbudget

# Tailscale sidecar logs
docker logs actualbudget-tailscale

# Follow logs in real-time
docker logs -f actualbudget-tailscale
```

## Tailscale Connectivity

```shell
# Check Tailscale status and IP
docker exec actualbudget-tailscale tailscale status

# Check IP addresses assigned to this node
docker exec actualbudget-tailscale tailscale ip
docker exec actualbudget-tailscale tailscale serve status
```

## Restart Services

```shell
# Restart both containers
docker compose -f /volume1/docker/stacks/actualbudget/docker-compose.yml restart
# Restart a single service
docker compose -f /volume1/docker/stacks/actualbudget/docker-compose.yml restart actualbudget
docker compose -f /volume1/docker/stacks/actualbudget/docker-compose.yml restart actualbudget-tailscale
```

## Config Files

| Purpose                | Host Path                                                  |
| ---------------------- | ---------------------------------------------------------- |
| App config             | `/volume1/docker/stacks/actualbudget/config`               |
| Tailscale serve config | `/volume1/docker/stacks/actualbudget/ts-config/serve.json` |
| Tailscale state        | `/volume1/docker/stacks/actualbudget/ts-state`             |
