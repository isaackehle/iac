# Debug Commands

Quick reference for troubleshooting the Pi-hole + Tailscale stack.

## Container Access

```bash
# Enter the Pi-hole container
docker exec -it pihole sh

# Enter the Tailscale sidecar container
docker exec -it ts-pihole sh
```

## Pi-hole Configuration

```bash
# View Pi-hole configuration
docker exec pihole pihole-FTL --config

# Check blocklist status and query counts
docker exec pihole pihole status

# Show blocked/allowed query counts
docker exec pihole pihole-FTL --status

# List active gravity (blocklist) databases
docker exec pihole ls -la /etc/pihole/
```

## Tailscale Serve Configuration

```bash
# View the serve config mounted in the sidecar
cat /config/serve.json

# Check what Tailscale Serve is doing (from inside the sidecar)
docker exec ts-pihole tailscale serve status
```

## Container Logs

```bash
# Pi-hole logs
docker logs pihole

# Tailscale sidecar logs
docker logs ts-pihole

# Follow logs in real-time
docker logs -f pihole
```

## Tailscale Connectivity

```bash
# Check Tailscale status and IP
docker exec ts-pihole tailscale status

# Check IP addresses assigned to this node
docker exec ts-pihole tailscale ip

# Verify the sidecar is connected to the tailnet
docker exec ts-pihole tailscale ping pihole
```

## DNS Testing

```bash
# Test DNS resolution via Pi-hole (from any device on tailnet)
dig @<pihole-tailnet-ip> example.com

# Test from the NAS host
dig @127.0.0.1 -p 53 example.com

# Check if a domain is blocked
docker exec pihole pihole-FTL --test
```

## Access URLs

| URL                                     | Description                      |
| --------------------------------------- | -------------------------------- |
| `https://pihole.${TS_TAILNET_DOMAIN}`   | Pi-hole admin (sidecar)          |
| `https://nas.${TS_TAILNET_DOMAIN}:8443` | Pi-hole admin (host serve)       |
| `http://nas.${TS_TAILNET_DOMAIN}:8080`  | Pi-hole admin (host serve, HTTP) |
| `http://<host>:8080`                    | Direct host access               |
| `http://<host>:8443`                    | Direct host access (HTTPS)       |

## Restart Services

```bash
# Restart both containers
docker compose restart

# Restart a single service
docker compose restart pihole
docker compose restart ts-pihole

# Restart Pi-hole DNS only (doesn't restart container)
docker exec pihole pihole restartdns
```

## Config Files

| Purpose                | Host Path                                            |
| ---------------------- | ---------------------------------------------------- |
| Pi-hole config         | `/volume1/docker/stacks/pihole/etc-pihole`           |
| Tailscale serve config | `/volume1/docker/stacks/pihole/ts-config/serve.json` |
| Tailscale state        | `/volume1/docker/stacks/pihole/ts-state`             |
