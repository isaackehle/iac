# Debug Commands

Quick reference for troubleshooting the Syncthing + Tailscale stack.

## Container Access

```bash
# Enter the Tailscale sidecar container
docker exec -it ts-syncthing sh

# Enter the Syncthing container
docker exec -it syncthing sh
```

## Tailscale Serve Configuration

```bash
# View the current serve config mounted in the container
cat /config/serve.json

# Check what Tailscale Serve is doing
tailscale serve status
```

## Container Logs

```bash
# Syncthing logs
docker logs syncthing

# Tailscale sidecar logs
docker logs ts-syncthing

# Follow logs in real-time
docker logs -f ts-syncthing
```

## Tailscale Connectivity

```bash
# Check Tailscale status and IP
docker exec ts-syncthing tailscale status

# Check IP addresses assigned to this node
docker exec ts-syncthing tailscale ip

# Verify Funnel/Serve is active
docker exec ts-syncthing tailscale serve status
```

## Syncthing Access

- **Direct:** `http://<host>:8384`
- **Via Tailscale:** `https://syncthing.<tailnet>:443`

## Restart Services

```bash
# Restart both containers
docker compose restart

# Restart a single service
docker compose restart ts-syncthing
docker compose restart syncthing
```

## Config Files

| Purpose                | Host Path                                               |
| ---------------------- | ------------------------------------------------------- |
| Syncthing config       | `/volume1/docker/stacks/syncthing/config`               |
| Sync data              | `/volume1/docker/stacks/syncthing/sync`                 |
| Additional data        | `/volume1/docker/stacks/syncthing/data`                 |
| Tailscale serve config | `/volume1/docker/stacks/syncthing/ts-config/serve.json` |
| Tailscale state        | `/volume1/docker/stacks/syncthing/ts-state`             |
