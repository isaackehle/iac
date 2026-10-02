# Tailscale Patterns

Every stack in this repo gets onto the tailnet through its own Tailscale node
(Pattern B, a sidecar). Pattern A (the NAS's own `tailscale serve`) is kept below
for reference; no stack uses it since 2026-09-26, when `affine` and `frigate` got
sidecars and `homeassistant` left the repo (Home Assistant runs on its own machine,
fronted by the `ha` node).

## Pattern A — Host-level `tailscale serve` (NAS node)

Used by: none (2026-09-26). Use it only for a stack that needs host networking.

The reason it existed: `homeassistant` needed
`network_mode: host` for device discovery (mDNS, Chromecast, HomeKit), and a
sidecar borrowing a host-networked namespace would run a second `tailscaled`
inside the host netns alongside the NAS's own. Host networking and the sidecar
pattern are mutually exclusive — if a stack needs the former, it belongs here.

The container binds a port on the host. The NAS host's own Tailscale daemon
reverse-proxies that port over HTTPS via `tailscale serve --bg`. Access is
via `nas.${TS_TAILNET_DOMAIN}:<port>`. Mappings are defined in
`scripts/lib.sh` (`STACK_SERVE_PORTS`) and applied with
`scripts/deploy.sh serve <stack> <ssh-host>` or `scripts/serve-all.sh`.

Backend scheme matters:

| Backend type                          | Use                                 |
| ------------------------------------- | ----------------------------------- |
| Plain HTTP container                  | `http://127.0.0.1:<port>`           |
| HTTPS container with self-signed cert | `https+insecure://127.0.0.1:<port>` |

## Pattern B — Tailscale sidecar container (own tailnet node)

Used by: `affine`, `frigate`, `langfuse`, `mosquitto`, `openwebui`, `plex`,
`portainer`, `postgresql`, and the special nodes `ha` and `mcp` (below).

Each stack includes a `tailscale/tailscale:latest` sidecar that joins the
tailnet as its own node (e.g. `plex.${TS_TAILNET_DOMAIN}`). The app container
has **no `ports:` and no `networks:` of its own** — it runs
`network_mode: service:<sidecar>` and borrows the sidecar's entire network
namespace. The sidecar mounts a `serve.json` (via
`TS_SERVE_CONFIG=/config/serve.json`), which it re-reads on container start.

If the app needs an extra LAN/host port besides the tailnet URL, add that
`ports:` entry to the **sidecar** service, not the app.

If the app has sibling containers (a db, browserless, etc.), those siblings
join a dedicated bridge network (`<stack>-net`) and the **sidecar also
joins that network** — that's what lets the app (which has borrowed the
sidecar's netns) still resolve siblings by name.

### Pattern B inverted — primary owns namespace

Used by: `n8n`, `nextcloud`, `pihole`, `syncthing`

The **primary app owns the network namespace** (has `ports:`, `hostname:`,
joins `<stack>-net`) and the Tailscale sidecar borrows it via
`network_mode: service:primary` with `depends_on: [primary]`. The sidecar's
`serve.json` proxies to `127.0.0.1:<port>` which reaches the primary since
they share the same namespace. Sibling containers (db, browserless)
join `<stack>-net` as usual; the primary resolves them directly and the
sidecar inherits that resolution.

### ⚠️ `TS_HOSTNAME` vs `hostname:` — known DNS collision

Always set the sidecar's tailnet name via the `TS_HOSTNAME` environment
variable. Do **not** use the Docker Compose `hostname:` field on the
sidecar — it collides with Docker's internal DNS resolver, breaking
MagicDNS resolution for *every* sidecar on the host, not just this one.

**Correct:**

```yaml
tailscale:
  environment:
    - TS_HOSTNAME=plex # ✓ registered via Tailscale, no Docker DNS conflict
```

**Wrong:**

```yaml
tailscale:
  hostname: plex # ✗ collides with other sidecar hostnames on the host
```

## Sidecar `serve.json` — one shape for every stack (TCPForward, no Caddy)

Every Pattern B / B-inverted stack uses the shape `openwebui` proved out
(2026-09-25, DEC-186), standardised across all stacks 2026-09-26:

```json
{
  "TCP": {
    "443": {
      "TCPForward": "127.0.0.1:<app-port>",
      "TerminateTLS": "<ts-hostname>.{{TS_TAILNET_DOMAIN}}"
    }
  }
}
```

`tailscaled` terminates TLS on 443 with its own automatic cert and relays
the decrypted bytes as raw TCP to the app. `{{TS_TAILNET_DOMAIN}}` is
rendered by `scripts/lib.sh render_templates` at deploy time.
`TerminateTLS` takes the literal hostname as its value (not `true`) — see
the `ipn.TCPPortHandler` struct in Tailscale's `ipn/serve.go`.

Do **not** use:

- **`HTTPS: true` + a `Web` map keyed by a literal `${TS_CERT_DOMAIN}:443`.**
  Nothing in our pipeline expands it; the sidecar logged
  `could not connect to local backend server at 127.0.0.1:443` and the
  node was unreachable (openwebui, 2026-09-25).
- **A Caddy hop.** `pihole` and `portainer` used to forward to a Caddy
  sibling on `:8444` to dodge `tailscaled`'s slow `Web`/`Proxy` mode
  ([tailscale/tailscale#18307](https://github.com/tailscale/tailscale/issues/18307)).
  `TCPForward` never enters that code path, so Caddy added nothing; the
  "hangs on large responses" were the NAT-hairpin path issue fixed by
  `TS_DEBUG_ALWAYS_USE_DERP=1`. Removed 2026-09-26.

**Two exceptions use the `Web`/`Proxy` shape** (with a rendered hostname key, never
a literal `${TS_CERT_DOMAIN}`):

- **`ha`** fronts Home Assistant, another machine on the LAN. Its UI path speaks HTTPS
  (HA's own Let's Encrypt cert), so `TCPForward` after `TerminateTLS` would send it
  plaintext — `ha` proxies the UI to `https+insecure://{{HA_LAN_IP}}:8123` on 80/443 and
  its MCP server to `http://{{HA_LAN_IP}}:9584`. It additionally carries **raw `TCPForward`
  with no `TerminateTLS`** for `8123` (HA's UI on its native port) and `2222` (SSH into the
  HA box): a non-HTTP protocol like SSH needs end-to-end passthrough, and the tailnet is
  already WireGuard-encrypted. Forwards point at `{{HA_LAN_IP}}:<port>`, never
  `127.0.0.1` — the HA machine is a *different* host, so a loopback backend would land on
  the sidecar itself. See `ha/docker-compose.yml` and `ha/serve.json.tmpl`.
- **`mcp`** routes by path to several MCP servers sharing one node
  (`/synology` → `127.0.0.1:8485`, ...). Path routing needs HTTP, and Tailscale
  strips the prefix. See `mcp/docker-compose.yml`.

**Non-HTTP services** use `TCPForward` on their own port, with or without
`TerminateTLS`. `mosquitto` forwards 1883 as plain MQTT (the tailnet is already
WireGuard-encrypted), 8883 as MQTT over TLS, and 443 as WebSocket over TLS (to 9001).

Also pin every stack's bridge network to a `172.20.x.0/24` subnet: DSM's
firewall drops forwarded traffic from Docker's default `192.168.x.0/20`
pool, which kills outbound (image pulls, DERP, ACME).
