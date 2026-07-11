# Infrastructure as Code

This repo contains Docker Compose stacks and Tailscale serve configuration for
**NAS** (`nas.<tailnet>.ts.net`), a self-hosted Linux server running on
the `<tailnet>.ts.net` tailnet.

---

## Stacks

| Stack           | Tailscale URL                                 | Pattern    | Port(s)                                |
| --------------- | --------------------------------------------- | ---------- | -------------------------------------- |
| `affine`        | `https://nas.<tailnet>.ts.net:3010`           | host serve | 3010                                   |
| `frigate`       | `https://nas.<tailnet>.ts.net:8971`           | host serve | 8971 (web), 8554 (rtsp), 8555 (webrtc) |
| `homeassistant` | `https://nas.<tailnet>.ts.net:8123`           | host serve | 8123                                   |
| `nextcloud`     | `https://nextcloud.<tailnet>.ts.net`         | TS sidecar | 443 → container:80                     |
| `pihole`        | `https://nas.<tailnet>.ts.net:8080` / `:8443` | host serve | 8080→80, 8443→443                      |
| `plex`          | `https://plex.<tailnet>.ts.net`              | TS sidecar | 443 → container:32400                  |
| `postgresql`    | `https://nas.<tailnet>.ts.net:2660`           | host serve | 2660→5050 (pgAdmin)                    |
| `syncthing`     | `https://syncthing.<tailnet>.ts.net`         | TS sidecar | 443 → container:8384                   |

---

## Tailscale patterns

Two patterns are used across this repo. Do not mix them for the same service.

### Pattern A — Host-level `tailscale serve` (NAS node)

Used by: `affine`, `frigate`, `homeassistant`, `pihole`, `postgresql`

The container binds a port on the host. The `NAS` host's Tailscale daemon
reverse-proxies that port over HTTPS via `tailscale serve --bg`. Access is via
`nas.<tailnet>.ts.net:<port>`.

Each stack has an `apply-serve.sh` that registers its port(s). The top-level
`apply-serve.sh` at the repo root traverses all subdirectories and calls each
one in sequence.

```bash
# Apply all host serve mappings
./apply-serve.sh

# Reset everything and re-apply
./apply-serve.sh --reset
```

#### Home Assistant on Tailscale

Home Assistant uses the **host-level serve** pattern in this repo.

That means the Home Assistant container is **not** its own Tailscale node.
Instead:

1. Home Assistant publishes its web UI on the host, typically on port `8123`.
2. The `NAS` host joins the tailnet and runs `tailscaled`.
3. `tailscale serve --bg` terminates HTTPS on the `NAS` node and proxies
   requests to the Home Assistant backend on the local host.

Example:

```bash
tailscale serve --bg https:8123 http://127.0.0.1:8123
```

Clients on the tailnet then reach Home Assistant at:

```text
https://nas.<tailnet>.ts.net:8123
```

If the backend container uses plain HTTP, use `http://127.0.0.1:<port>`.
If the backend container serves HTTPS with a self-signed certificate, use
`https+insecure://127.0.0.1:<port>` instead.

#### Adding a container to the Tailscale network

“Add the container to Tailscale” can mean two different things in this repo:

- **Host serve pattern:** the container publishes a port on `NAS`, and the
  host's Tailscale daemon proxies traffic to it. The container itself does not
  join the tailnet.
- **Sidecar pattern:** a dedicated `tailscale/tailscale` container joins the
  tailnet as its own node and proxies to the app container over Docker
  networking.

For Home Assistant, use the **host serve pattern** unless there is a specific
reason to give it its own tailnet identity.

### Pattern B — Tailscale sidecar container (own tailnet node)

Used by: `nextcloud`, `plex`, `syncthing`

Each stack includes a `ts-<name>` sidecar container running
`tailscale/tailscale:latest`. The sidecar registers as its own node on the
tailnet (e.g. `plex.<tailnet>.ts.net`) and applies a `serve.json` config that
proxies HTTPS traffic to the app container via `network_mode: service:ts-<name>`.

Each stack's `ts-config-serve.json` is mounted into the sidecar at
`/config/serve.json` via `TS_SERVE_CONFIG`.

#### ⚠️ `TS_HOSTNAME` vs `hostname:` — known DNS collision

Always set the node name via the `TS_HOSTNAME` environment variable on the
sidecar. Do **not** use the Docker Compose `hostname:` field on the sidecar
service.

Using `hostname:` on the sidecar causes a DNS collision with other sidecar nodes
on the same host — Docker's internal DNS resolver and Tailscale's MagicDNS
both try to own the name, resulting in broken resolution for all sidecar nodes
on the host.

**Correct:**

```yaml
ts-plex:
  environment:
    - TS_HOSTNAME=plex # ✓ registered via Tailscale, no Docker DNS conflict
```

**Wrong:**

```yaml
ts-plex:
  hostname: plex # ✗ collides with other sidecar hostnames on the host
```

---

## Auth keys

Each sidecar stack requires its own Tailscale auth key set in `.env`.
Generate reusable, pre-authorized keys at:
[https://login.tailscale.com/admin/settings/keys](https://login.tailscale.com/admin/settings/keys)

| Stack       | `.env` variable        |
| ----------- | ---------------------- |
| `nextcloud` | `TS_AUTHKEY_NEXTCLOUD` |
| `plex`      | `TS_AUTHKEY_PLEX`      |
| `syncthing` | `TS_AUTHKEY_SYNCTHING` |

`.env` files are gitignored. Copy the `.env.example` in each stack directory
and fill in values before running `docker compose up`.

---

## Non-HTTP ports (not proxied by Tailscale Serve)

These ports are accessible directly via Tailscale IP or tailnet hostname but
are not handled by `tailscale serve` (which is HTTP/HTTPS only):

| Service             | Port  | Protocol  | Notes                                              |
| ------------------- | ----- | --------- | -------------------------------------------------- |
| Pi-hole DNS         | 53    | TCP + UDP | Configure as tailnet DNS resolver in admin console |
| Frigate RTSP        | 8554  | TCP       | Use an RTSP client pointed at Tailscale IP         |
| Frigate WebRTC      | 8555  | TCP + UDP | UDP not proxiable via serve                        |
| Syncthing sync      | 22000 | TCP + UDP | Syncthing handles tailnet peers natively           |
| Syncthing discovery | 21027 | UDP       | —                                                  |
| PostgreSQL          | 5432  | TCP       | Connect via Tailscale IP directly                  |

---

## Directory structure

```text
iac/
├── README.md                  ← this file
├── apply-serve.sh             ← top-level runner (traverses all stacks)
├── affine/
│   ├── apply-serve.sh
│   └── docker-compose.yaml
├── frigate/
│   ├── apply-serve.sh
│   ├── docker-compose.yaml
│   └── frigate-config.yml
├── homeassistant/
│   ├── apply-serve.sh
│   └── docker-compose.yaml
├── nextcloud/
│   ├── docker-compose.yml
│   └── ts-config-serve.json
├── pihole/
│   ├── apply-serve.sh
│   └── docker-compose.yaml
├── plex/
│   ├── apply-serve.sh         ← host-only fallback; not needed with sidecar
│   ├── docker-compose.yaml
│   ├── plex.env.example
│   └── ts-config-serve.json
├── postgresql/
│   ├── apply-serve.sh
│   └── docker-compose.yaml
├── syncthing/
│   ├── apply-serve.sh
│   ├── docker-compose.yaml
│   ├── syncthing-ts-config-serve.json
│   └── syncthing.env.example
└── tailscale/
    └── apply-serve.sh         ← full master list of all host serve mappings
```

---

## Tailscale Serve — host-level reference

### How `tailscale serve --bg` works

`tailscale serve --bg` tells the Tailscale daemon (`tailscaled`) to:

1. Open an HTTPS listener on the specified port on the node's Tailscale interface.
2. Reverse-proxy inbound requests from tailnet clients to the corresponding local container.
3. Present a valid TLS certificate issued by Tailscale for the tailnet hostname to clients, even when the backend uses a self-signed cert or plain HTTP.

All endpoints are **tailnet-only**. Nothing is reachable from the public internet unless explicitly enabled via Funnel.

### Backend scheme rules

| Backend type                          | Use                                 |
| ------------------------------------- | ----------------------------------- |
| Plain HTTP container                  | `http://127.0.0.1:<port>`           |
| HTTPS container with self-signed cert | `https+insecure://127.0.0.1:<port>` |

Portainer (`9443`) and Pi-hole HTTPS (`8443`) both serve self-signed certs internally and require `https+insecure://`.

### Managing host serve mappings

```bash
# Apply all mappings (idempotent)
./apply-serve.sh

# Reset everything and re-apply
./apply-serve.sh --reset

# Check current state
tailscale serve status

# Remove a single port
tailscale serve --https=8971 off

# Remove all
tailscale serve reset
```

### Persistence

`tailscale serve --bg` writes config into `tailscaled`'s internal state at
`/var/lib/tailscale/`. It is not a running process — mappings survive reboots
automatically as long as `tailscaled` starts at boot:

```bash
sudo systemctl enable --now tailscaled
```

### `ts-config-serve.json` format (sidecar pattern)

Sidecar stacks mount a `serve.json` via `TS_SERVE_CONFIG`. The format uses
`TCP` and `Web` top-level keys. `${TS_CERT_DOMAIN}` is substituted at runtime
with the node's full MagicDNS name.

```json
{
  "TCP": {
    "443": { "HTTPS": true }
  },
  "Web": {
    "${TS_CERT_DOMAIN}:443": {
      "Handlers": {
        "/": { "Proxy": "http://127.0.0.1:<port>" }
      }
    }
  }
}
```

The sidecar re-reads this file on container start — unlike the host pattern,
the file must remain present at the mounted path.
