# Debug Commands

Quick reference for troubleshooting the `<stack>` + Tailscale stack.

Replace `<stack>`, `ts-<stack>`, and `/volume1/docker/stacks/<stack>` with real values.

## Container Access

```shell
# Enter the Tailscale sidecar container
docker exec -it ts-<stack> sh

# Enter the app container
docker exec -it <stack> sh
```

## Tailscale Serve Configuration

```shell
# View the current serve config mounted in the container
cat /config/serve.json

# Check what Tailscale Serve is doing (from inside the sidecar)
docker exec ts-<stack> tailscale serve status
```

## Container Logs

```shell
# App logs
docker logs <stack>

# Tailscale sidecar logs
docker logs ts-<stack>

# Follow logs in real-time
docker logs -f ts-<stack>
```

## Tailscale Connectivity

```shell
# Check Tailscale status and IP
docker exec ts-<stack> tailscale status

# Check IP addresses assigned to this node
docker exec ts-<stack> tailscale ip
docker exec ts-<stack> tailscale serve status
```

## Restart Services

```shell
# Restart both containers
docker compose -f /volume1/docker/stacks/<stack>/docker-compose.yml restart
# Restart a single service
docker compose -f /volume1/docker/stacks/<stack>/docker-compose.yml restart <stack>
docker compose -f /volume1/docker/stacks/<stack>/docker-compose.yml restart ts-<stack>
```

## Config Files

| Purpose                | Host Path                                             |
| ---------------------- | ----------------------------------------------------- |
| App config             | `/volume1/docker/stacks/<stack>/config`               |
| Tailscale serve config | `/volume1/docker/stacks/<stack>/ts-config/serve.json` |
| Tailscale state        | `/volume1/docker/stacks/<stack>/ts-state`             |
