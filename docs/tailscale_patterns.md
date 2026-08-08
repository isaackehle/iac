# Tailscale Patterns

Two patterns are used across this repo. Do not mix them for the same service.

## Pattern A — Host-level `tailscale serve` (NAS node)

Used by: `affine`, `frigate`, `homeassistant`, `postgresql`

`homeassistant` is here rather than Pattern B for a specific reason: it needs
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

Used by: `langfuse`, `openwebui`, `plex`, `portainer`

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
they share the same namespace. Sibling containers (db, browserless, caddy)
join `<stack>-net` as usual; the primary resolves them directly and the
sidecar inherits that resolution.

### ⚠️ `TS_HOSTNAME` vs `hostname:` — known DNS collision

Always set the sidecar's tailnet name via the `TS_HOSTNAME` environment
variable. Do **not** use the Docker Compose `hostname:` field on the
sidecar — it collides with Docker's internal DNS resolver, breaking
MagicDNS resolution for _every_ sidecar on the host, not just this one.

**Correct:**

```yaml
tailscale-sidecar:
  environment:
    - TS_HOSTNAME=plex # ✓ registered via Tailscale, no Docker DNS conflict
```

**Wrong:**

```yaml
tailscale-sidecar:
  hostname: plex # ✗ collides with other sidecar hostnames on the host
```

## `pihole` — Pattern B + Caddy (TCPForward, not Web/Proxy mode)

`pihole` is a Pattern B sidecar setup with one difference: the `tailscale-sidecar`'s
`serve.json` does **not** use the usual `Web`/`Proxy` HTTP-reverse-proxy
mode. Instead it uses Tailscale's `TCPForward` + `TerminateTLS` mode —
`tailscaled` still terminates TLS on 443 with its own automatic cert, but
instead of parsing and re-proxying the HTTP request itself, it forwards the
decrypted bytes as a raw TCP stream to a third sibling container, `caddy-sidecar`,
which does the actual HTTP reverse-proxying to Pi-hole on `127.0.0.1:80`.

Why: `tailscaled`'s own built-in `Web`/`Proxy` mode is
[documented as 5-10x slower](https://github.com/tailscale/tailscale/issues/18307)
than a real reverse proxy under concurrent load — enough that Pi-hole's
admin UI would hang indefinitely loading its own CSS/JS assets (a dozen-plus
parallel requests on page load) even though a single sequential `curl`
worked fine. `TCPForward`/`TerminateTLS` sidesteps `tailscaled`'s slow HTTP
path entirely while still getting automatic TLS from Tailscale — Caddy never
needs its own cert.

`pihole/serve.json.tmpl`:

```json
{
  "TCP": {
    "443": {
      "TCPForward": "127.0.0.1:8444",
      "TerminateTLS": "pihole.{{TS_TAILNET_DOMAIN}}"
    }
  }
}
```

Note `TerminateTLS` takes the literal hostname as its value (not `true`) —
confirmed from the `ipn.TCPPortHandler` struct in Tailscale's own source
(`ipn/serve.go`). It's templated via `{{TS_TAILNET_DOMAIN}}` rather than
Tailscale's own `${TS_CERT_DOMAIN}` runtime substitution, since that
substitution is only confirmed to apply to `Web` map keys, not arbitrary
`TCP` handler string fields — untested territory not worth gambling on.

Port 8444 is never published to the host — it's only reachable via the
`network_mode: service:primary` shared namespace between `tailscale-sidecar`,
`caddy-sidecar`,
and `primary` itself. `primary` still separately publishes `8280:80/tcp`
directly (bypassing Caddy entirely) as a raw plain-HTTP debug path.

This pattern (Caddy sidecar + `TCPForward`/`TerminateTLS` instead of
`Web`/`Proxy`) is worth reapplying to any other Pattern B stack that hits
the same slow-proxy wall — it's not pihole-specific, just not yet needed
elsewhere. Each stack doing this needs its **own** Caddy instance sharing
**its own** sidecar's identity/cert — a single shared Caddy can't front
multiple stacks' separate `<name>.${TS_TAILNET_DOMAIN}` hostnames, since
each hostname's cert is bound to that stack's own Tailscale node.
