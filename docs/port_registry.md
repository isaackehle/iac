# Port registry

Every port the stacks use, from the compose files and `serve.json.tmpl` files
(checked 2026-09-26). Check here before adding a published port or a serve
listener: collisions on the NAS are easy to hit blind.

## Published on the NAS (LAN, and the NAS's tailnet address)

Sorted by port. "Published by" is the container that owns the `ports:` entry: the
Tailscale sidecar in normal stacks, the app itself in the inverted ones (see
[tailscale_patterns.md](tailscale_patterns.md)).

| Port         | Stack         | Published by  | Protocol  | What                                                                               |
| ------------ | ------------- | ------------- | --------- | ---------------------------------------------------------------------------------- |
| 53           | pihole        | primary       | TCP + UDP | DNS                                                                                |
| 1883         | mosquitto     | tailscale     | TCP       | MQTT, for LAN devices                                                              |
| 2665 → 5432  | postgresql    | tailscale     | TCP       | Postgres                                                                           |
| 3010         | affine        | tailscale     | TCP       | Web UI (LAN)                                                                       |
| 5678         | n8n           | primary       | TCP       | Web UI (LAN)                                                                       |
| 8000         | portainer     | tailscale     | TCP       | Portainer edge-agent tunnel                                                        |
| 8280 → 80    | pihole        | primary       | TCP       | Plain-HTTP admin (debugging)                                                       |
| 8281 → 80    | nextcloud     | primary       | TCP       | Plain-HTTP web (debugging). Moved off 8280 on 2026-09-26 (it clashed with pihole). |
| 8384         | syncthing     | primary       | TCP       | Web GUI (LAN)                                                                      |
| 8485         | mcp           | tailscale     | TCP       | Synology MCP at `http://nas.<tailnet>:8485/mcp`, for older clients                 |
| 8554         | frigate       | tailscale     | TCP       | RTSP restream                                                                      |
| 8555         | frigate       | tailscale     | TCP + UDP | WebRTC                                                                             |
| 8971         | frigate       | tailscale     | TCP       | Web UI (LAN, plain HTTP; Frigate's own TLS is off)                                 |
| 9000         | portainer     | tailscale     | TCP       | Portainer HTTP (LAN)                                                               |
| 9001         | mosquitto     | tailscale     | TCP       | MQTT over WebSocket, for LAN clients                                               |
| 9090 → 9000  | langfuse      | storage       | TCP       | MinIO S3 API                                                                       |
| 19443 → 9443 | portainer     | tailscale     | TCP       | Portainer HTTPS, self-signed (LAN)                                                 |
| 21027        | syncthing     | primary       | UDP       | Local discovery                                                                    |
| 22000        | syncthing     | primary       | TCP + UDP | Sync protocol                                                                      |

## Tailnet-only (each stack's own Tailscale node)

These listen on `<node>.<tailnet>.ts.net`, not on the NAS. Every node serves 443;
the exceptions are listed.

| Node                | Ports                           | What                                                                                                                                |
| ------------------- | ------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------- |
| every sidecar stack | 443                             | HTTPS with Tailscale's certificate, forwarded to the app                                                                            |
| `mosquitto`         | 443, 1883, 8883                 | WebSocket over TLS (→ 9001), plain MQTT, MQTT over TLS (→ 1883)                                                                     |
| `ha`                | 80, 443, 4357, 8123, 9584, 2222 | HA UI (HTTP/HTTPS), Observer health page (proxied HTTP), UI on its native port (raw TCP), MCP server, SSH into the HA box (raw TCP) |
| `mcp`               | 443                             | MCP servers by path: `/synology` (→ 8485), `/tailscale` (→ 8488)                                                                    |

## Local ports inside shared namespaces

Containers sharing a sidecar's namespace share `127.0.0.1`, so ports must be
unique within a stack. The one stack where this matters is `mcp`: its port table
is in `mcp/docker-compose.yml` (8485 and 8488 in use; 8486, 8487 and 8489 reserved).

## Not covered

DSM's own ports: 5000 (HTTP) and 5001 (HTTPS) by default, and 22 for SSH. DSM's
Security Advisor recommends moving the web ports (Control Panel → Login Portal → DSM
tab). If you have, keep the real numbers out of this repo: they go in `~/.env` as
`DSM_HTTP_PORT` / `DSM_HTTPS_PORT` (see `iac-secrets.env.example`). If you suspect a
clash outside this table, check Control Panel → Network.
