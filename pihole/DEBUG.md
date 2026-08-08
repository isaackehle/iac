# Debug Commands

Quick reference for troubleshooting the Pi-hole + Tailscale + Caddy stack.

## Container Access

```shell
# Enter the Pi-hole container
docker exec -it pihole sh

# Enter the Tailscale sidecar container
docker exec -it pihole-tailscale sh

# Enter the Caddy container
docker exec -it pihole-caddy sh
```

## Pi-hole Configuration

```shell
# View Pi-hole configuration
docker exec pihole pihole-FTL --config

# Check a specific setting (e.g. confirm the reverse-proxy domain fix took)
docker exec pihole pihole-FTL --config webserver.domain

# Check blocklist status and query counts
docker exec pihole pihole status

# List active gravity (blocklist) databases
docker exec pihole ls -la /etc/pihole/
```

## Tailscale Serve Configuration

```shell
# View the serve config mounted in the sidecar
docker exec pihole-tailscale cat /config/serve.json

# Check what Tailscale Serve is doing (from inside the sidecar)
docker exec pihole-tailscale tailscale serve status
```

Expect a single `TCPForward` entry on port 443 pointing at `127.0.0.1:8444`
(Caddy) with `TerminateTLS` set — **not** a `Web`/`Proxy` entry. If you see
`Web` handlers instead, the stack is running an older `serve.json` and
needs a real recreate (`docker compose up -d --force-recreate`), not just a
restart — Tailscale only re-reads `TS_SERVE_CONFIG` on container start.

## Verifying the Caddy Hop

```shell
# From pihole-tailscale: can it reach Caddy on the internal forward port?
docker exec pihole-tailscale wget -qO- --timeout=5 http://127.0.0.1:8444/admin/login && echo OK

# From Caddy: can it reach Pi-hole?
docker exec pihole-caddy wget -qO- --timeout=5 http://127.0.0.1:80/admin/login && echo OK

# Caddy's own logs (access logs + any reverse_proxy errors)
docker logs pihole-caddy
```

## Container Logs

```shell
docker logs pihole
docker logs pihole-tailscale
docker logs pihole-caddy

# Follow logs in real-time
docker logs -f pihole
```

## Tailscale Connectivity

```shell
# Check Tailscale status and IP
docker exec pihole-tailscale tailscale status

# Check IP addresses assigned to this node
docker exec pihole-tailscale tailscale ip

# Verify the sidecar is connected to the tailnet
docker exec pihole-tailscale tailscale ping pihole
```

## DNS Testing

```shell
# Test DNS resolution via Pi-hole (from any device on tailnet)
dig @pihole.tail303fda.ts.net example.com

# Test from the NAS host
dig @127.0.0.1 -p 53 example.com

# Check if a domain is blocked (should return 0.0.0.0)
docker exec pihole dig @127.0.0.1 doubleclick.net +short
```

## Access URLs

| URL                                       | Description                                                       |
| ------------------------------------------ | --------------------------------------------------------------------- |
| `https://pihole.${TS_TAILNET_DOMAIN}`     | Pi-hole admin — primary path: `pihole-tailscale` (TLS) → `caddy` → Pi-hole  |
| `http://pihole.${TS_TAILNET_DOMAIN}:8280` | Raw debug path straight to Pi-hole — no TLS, no Caddy, no Tailscale proxying involved beyond basic reachability |

If the primary URL doesn't work but the `:8280` one does, the problem is
specifically in the `pihole-tailscale`→`caddy` TCPForward hop — use the "Verifying
the Caddy Hop" commands above to find which link is broken.

## Restart Services

```shell
# Restart all three containers
docker compose restart

# Restart a single service
docker compose restart pihole
docker compose restart pihole-tailscale
docker compose restart caddy

# Restart Pi-hole DNS only (doesn't restart container)
docker exec pihole pihole restartdns
```

## Config Files

| Purpose                 | Host Path                                            |
| ------------------------ | ----------------------------------------------------- |
| Pi-hole config           | `/volume1/docker/stacks/pihole/etc-pihole`           |
| Tailscale serve config   | `/volume1/docker/stacks/pihole/ts-config/serve.json` |
| Tailscale state          | `/volume1/docker/stacks/pihole/ts-state`             |
| Caddyfile                | `/volume1/docker/stacks/pihole/caddy-config`         |
