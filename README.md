# Infrastructure as Code

Docker Compose stacks and Tailscale serve configuration for **NAS**, a
self-hosted Synology server on the `${TS_TAILNET_DOMAIN}` tailnet.

---

## Stacks

| Stack           | Tailscale URL                                     | Pattern            |
| --------------- | ------------------------------------------------- | ------------------ |
| `affine`        | `https://nas.${TS_TAILNET_DOMAIN}:3010`           | host serve         |
| `frigate`       | `https://nas.${TS_TAILNET_DOMAIN}:8971`           | host serve         |
| `homeassistant` | `https://homeassistant.${TS_TAILNET_DOMAIN}`      | TS sidecar         |
| `langfuse`      | `https://langfuse.${TS_TAILNET_DOMAIN}`           | TS sidecar         |
| `mosquitto`     | n/a — LAN/tailnet IP only, port 1883              | none               |
| `n8n`           | `https://n8n.${TS_TAILNET_DOMAIN}`                | TS sidecar         |
| `nextcloud`     | `https://nextcloud.${TS_TAILNET_DOMAIN}`          | TS sidecar         |
| `openwebui`     | `https://openwebui.${TS_TAILNET_DOMAIN}`          | TS sidecar         |
| `pihole`        | `https://pihole.${TS_TAILNET_DOMAIN}`             | TS sidecar + Caddy |
| `plex`          | `https://plex.${TS_TAILNET_DOMAIN}`               | TS sidecar         |
| `portainer`     | `https://portainer.${TS_TAILNET_DOMAIN}`          | TS sidecar         |
| `postgresql`    | `https://nas.${TS_TAILNET_DOMAIN}:2660` (pgAdmin) | host serve         |
| `syncthing`     | `https://syncthing.${TS_TAILNET_DOMAIN}`          | TS sidecar         |

---

## Secrets

Real secrets (Tailscale auth keys, passwords, API keys) live in a single
file at the repo root, gitignored and never committed:

```shell
iac-secrets.env
```

Override the location with `IAC_SECRETS_FILE=/some/path` if you keep it
somewhere else (e.g. a synced folder outside the repo).

`iac-secrets.env.example` (repo root) documents every key each stack needs
and is safe to commit — it has no real values. Copy it to `iac-secrets.env`
once and fill in real values there.

Each stack still has a `.env.example` describing what _that stack_ needs;
`scripts/gen-env.sh` cross-references the two to produce a real `env.txt`
per stack (gitignored, never committed). It's named `env.txt` rather than
`.env` on purpose — Portainer's "Load variables from .env file" button opens
a normal OS file picker, and dotfiles are hidden by default in most of
those, making a literal `.env` annoying to select manually:

```bash
scripts/gen-env.sh <stack>     # generate ./<stack>/env.txt
scripts/gen-env.sh --all       # generate env.txt for every stack
```

Any key still blank or left as a placeholder (`changeme`, `tskey-auth-xxxx`,
`${TS_TAILNET_DOMAIN}`, ...) after generation is printed as a warning — fill it into
`iac-secrets.env` and re-run.

`TS_CERT_DOMAIN` doesn't need to be repeated per stack in the secrets file:
set `TS_TAILNET_DOMAIN` once (e.g. `${TS_TAILNET_DOMAIN}`) and `gen-env.sh`
derives `<stack>.<TS_TAILNET_DOMAIN>` automatically for any stack that needs
it, unless you override it explicitly.

---

## Deploying a stack

`scripts/deploy.sh` pushes a stack from your laptop to the NAS over SSH —
no manual copy/paste into Portainer required, though that still works too.

```bash
scripts/deploy.sh env   <stack>                # generate <stack>/env.txt locally
scripts/deploy.sh dirs  <stack> <ssh-host>      # mkdir -p + chown on the NAS
scripts/deploy.sh push  <stack> <ssh-host>      # scp compose file, env.txt, serve.json, etc.
scripts/deploy.sh serve <stack> <ssh-host>      # apply host-level tailscale serve (if applicable)
scripts/deploy.sh up    <stack> <ssh-host>      # ssh in, docker compose up -d
scripts/deploy.sh all   <stack> <ssh-host>      # all of the above, in order
```

`<ssh-host>` is anything `ssh`/`scp` accepts — an `~/.ssh/config` alias
(`nas`) or `user@192.168.1.20`.

Directory layout, which extra files get copied where, and which stacks get
host-level `tailscale serve` mappings all come from `scripts/lib.sh` — that
file is the single source of truth, so every stack is provisioned the same
way instead of each having its own bespoke setup script (the old per-stack
`init.sh` / `apply-serve.sh` / `deploy-*.sh` scripts have been removed).

To apply/reset every stack's host-level serve mapping at once:

```bash
scripts/serve-all.sh <ssh-host>              # apply all mappings
scripts/serve-all.sh <ssh-host> --reset      # reset first, then apply all
```

### Adding a new stack

1. Copy `_template/` to `<new-stack>/` and follow its `README.md`.
2. Add the secrets it needs to `iac-secrets.env.example` and your real
   `./iac-secrets.env (repo root, gitignored)`.
3. Add an entry for it in `scripts/lib.sh` (`ALL_STACKS`, `STACK_REMOTE_DIR`,
   `STACK_DIRS`, and `STACK_EXTRA_FILES`/`STACK_SERVE_PORTS` if needed).
4. `scripts/deploy.sh info <new-stack>` to preview the deploy steps.
5. `scripts/deploy.sh all <new-stack> <ssh-host>`.

---

## Tailscale patterns

Two patterns are used across this repo. Do not mix them for the same
service.

### Pattern A — Host-level `tailscale serve` (NAS node)

Used by: `affine`, `frigate`, `postgresql`

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

### Pattern B — Tailscale sidecar container (own tailnet node)

Used by: `homeassistant`, `langfuse`, `n8n`, `nextcloud`, `openwebui`, `plex`,
`portainer`, `syncthing` (`pihole` uses a variant of this, see below)

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
sidecar's netns) still resolve siblings by name. See
`nextcloud/docker-compose.yml` (db + redis) or `n8n/docker-compose.yml`
(browserless) for real examples.

`syncthing` inverts the usual direction: the app container is primary and
keeps its own `ports:`/`hostname:`, and `ts-syncthing` borrows _its_ netns
instead of the other way around.

#### ⚠️ `TS_HOSTNAME` vs `hostname:` — known DNS collision

Always set the sidecar's tailnet name via the `TS_HOSTNAME` environment
variable. Do **not** use the Docker Compose `hostname:` field on the
sidecar — it collides with Docker's internal DNS resolver, breaking
MagicDNS resolution for _every_ sidecar on the host, not just this one.

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

### `pihole` — Pattern B + Caddy (TCPForward, not Web/Proxy mode)

`pihole` is a Pattern B sidecar setup with one difference: `ts-pihole`'s
`serve.json` does **not** use the usual `Web`/`Proxy` HTTP-reverse-proxy
mode. Instead it uses Tailscale's `TCPForward` + `TerminateTLS` mode —
`tailscaled` still terminates TLS on 443 with its own automatic cert, but
instead of parsing and re-proxying the HTTP request itself, it forwards the
decrypted bytes as a raw TCP stream to a third sibling container, `caddy`,
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
`network_mode: service:pihole` shared namespace between `ts-pihole`, `caddy`,
and `pihole` itself. `pihole` still separately publishes `8280:80/tcp`
directly (bypassing Caddy entirely) as a raw plain-HTTP debug path.

This pattern (Caddy sidecar + `TCPForward`/`TerminateTLS` instead of
`Web`/`Proxy`) is worth reapplying to any other Pattern B stack that hits
the same slow-proxy wall — it's not pihole-specific, just not yet needed
elsewhere. Each stack doing this needs its **own** Caddy instance sharing
**its own** sidecar's identity/cert — a single shared Caddy can't front
multiple stacks' separate `<name>.${TS_TAILNET_DOMAIN}` hostnames, since
each hostname's cert is bound to that stack's own Tailscale node.

---

## Directory layout

All stacks live under `/volume1/docker/stacks/<name>`. Each stack's directory
contains its compose file, generated `env.txt`, and any extra config
(serve.json, etc.). The `scripts/lib.sh` file is the single source of truth
for paths.

---

## Non-HTTP ports (not proxied by Tailscale Serve)

These ports are reachable directly via the Tailscale IP/hostname but are
not handled by `tailscale serve` (HTTP/HTTPS only):

| Service             | Port  | Protocol  | Notes                                                                                                                                       |
| ------------------- | ----- | --------- | ------------------------------------------------------------------------------------------------------------------------------------------- |
| Pi-hole DNS         | 53    | TCP + UDP | Configure as tailnet DNS resolver in admin console                                                                                          |
| Langfuse / MinIO    | 9090  | TCP       | S3 API for direct media uploads — see langfuse's Pattern note (published directly on the `minio` sibling, not routed through `langfuse-ts`) |
| Frigate RTSP        | 8554  | TCP       | Use an RTSP client pointed at the Tailscale IP                                                                                              |
| Frigate WebRTC      | 8555  | TCP + UDP | UDP not proxiable via serve                                                                                                                 |
| Syncthing sync      | 22000 | TCP + UDP | Syncthing handles tailnet peers natively                                                                                                    |
| Syncthing discovery | 21027 | UDP       | —                                                                                                                                           |
| PostgreSQL          | 2665  | TCP       | Connect via Tailscale IP directly                                                                                                           |
| Mosquitto MQTT      | 1883  | TCP       | No Tailscale integration; reachable because the NAS host itself runs `tailscaled`                                                           |

---

## Port Registry — master list, pull from here before assigning a new port

Every host-bound port across every stack, one table, sorted by port number.
Covers Pattern A `tailscale serve` targets, non-HTTP direct ports, and the
handful of ports published straight to the host outside either Tailscale
pattern (syncthing's GUI, portainer's DSM-fronted ports). Check here before
adding a new `STACK_SERVE_PORTS` entry, a new sidecar host port, or a new
non-HTTP port — collisions on the NAS host are otherwise easy to hit blind.

| Port         | Stack            | Protocol  | Access path                             | Notes                                                                                   |
| ------------ | ---------------- | --------- | --------------------------------------- | --------------------------------------------------------------------------------------- |
| 53           | pihole           | TCP + UDP | Direct (non-HTTP)                       | DNS                                                                                     |
| 443          | pihole           | TCP       | `tailscaled` (TCPForward → Caddy)       | web UI, TLS terminated by Tailscale, not published to host — reachable only via tailnet |
| 1883         | mosquitto        | TCP       | Direct (non-HTTP)                       | MQTT — no Tailscale integration                                                         |
| 2660         | postgresql       | TCP       | Pattern A (host serve)                  | pgAdmin                                                                                 |
| 2665         | postgresql       | TCP       | Direct (non-HTTP)                       | raw Postgres, connect via Tailscale IP                                                  |
| 3010         | affine           | TCP       | Pattern A (host serve)                  |                                                                                         |
| 8000         | portainer        | TCP       | DSM reverse proxy (not Tailscale)       | edge agent port                                                                         |
| 8280         | pihole           | TCP       | Direct host publish (bypasses Caddy)    | raw plain-HTTP debug path straight to Pi-hole                                           |
| 8384         | syncthing        | TCP       | Pattern B sidecar + direct host publish | web GUI                                                                                 |
| 8554         | frigate          | TCP       | Direct (non-HTTP)                       | RTSP                                                                                    |
| 8555         | frigate          | TCP + UDP | Direct (non-HTTP)                       | WebRTC — UDP not proxiable via serve                                                    |
| 8971         | frigate          | TCP       | Pattern A (host serve)                  |                                                                                         |
| 9000         | portainer        | TCP       | DSM reverse proxy (not Tailscale)       | Portainer HTTP                                                                          |
| 9090         | langfuse (minio) | TCP       | Direct (non-HTTP)                       | S3 API, published on the `minio` sibling                                                |
| 19443 → 9443 | portainer        | TCP       | DSM reverse proxy (not Tailscale)       | Portainer HTTPS; `ts-portainer` sidecar exists but is **not enabled**                   |
| 21027        | syncthing        | UDP       | Direct (non-HTTP)                       | discovery                                                                               |
| 22000        | syncthing        | TCP + UDP | Direct (non-HTTP)                       | sync protocol                                                                           |

Not host-bound, so not in the table above but worth knowing about: pihole's
`caddy` sibling listens on **8444** inside the stack's shared network
namespace only — never published to the host, not reachable outside the
`network_mode: service:pihole` group. Won't collide with anything.

Not covered here: DSM's own native ports (Login Portal 5000/5001, SSH 22,
etc.) — cross-check Control Panel → Network → Firewall/Router if a
collision is suspected outside this table.

Currently actually deployed on the NAS: **syncthing** and (mid-rebuild)
**pihole**. Everything else in this table is either not yet deployed or
(portainer) deployed but fronted by DSM's reverse proxy instead of Tailscale.

---

## Tailscale Serve — host-level reference

### How `tailscale serve --bg` works

`tailscale serve --bg` tells the Tailscale daemon (`tailscaled`) to:

1. Open an HTTPS listener on the specified port on the node's Tailscale
   interface.
2. Reverse-proxy inbound requests from tailnet clients to the corresponding
   local container.
3. Present a valid TLS certificate issued by Tailscale for the tailnet
   hostname, even when the backend uses a self-signed cert or plain HTTP.

All endpoints are **tailnet-only**. Nothing is reachable from the public
internet unless explicitly enabled via Funnel.

### Managing host serve mappings

```bash
# Apply all mappings (idempotent)
scripts/serve-all.sh <ssh-host>

# Reset everything and re-apply
scripts/serve-all.sh <ssh-host> --reset

# Check current state
ssh <ssh-host> tailscale serve status

# Remove a single port
ssh <ssh-host> "sudo tailscale serve --https=8971 off"

# Remove all
ssh <ssh-host> "sudo tailscale serve reset"
```

### Persistence

`tailscale serve --bg` writes config into `tailscaled`'s internal state at
`/var/lib/tailscale/`. It is not a running process — mappings survive
reboots automatically as long as `tailscaled` starts at boot
(`sudo systemctl enable --now tailscaled`).

### `serve.json` format (sidecar pattern)

Sidecar stacks mount a `serve.json` via `TS_SERVE_CONFIG`. The format uses
`TCP` and `Web` top-level keys. `${TS_CERT_DOMAIN}` is substituted at
runtime with the node's full MagicDNS name.

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

The sidecar re-reads this file on container start — unlike the host
pattern, the file must remain present at the mounted path.

`pihole` uses a different `TCP` handler shape — `TCPForward` +
`TerminateTLS` instead of `HTTPS: true` + a `Web` entry — to route around a
documented performance problem in `tailscaled`'s own `Web`/`Proxy` mode.
See the `pihole` — Pattern B + Caddy section above for why and the exact
schema.

### Templated files (`*.tmpl`)

Every sidecar stack keeps its committed `serve.json` source as
`serve.json.tmpl`; `scripts/gen-env.sh` renders it to `serve.json`
(gitignored, like `env.txt`) at deploy time. For most stacks the render just
copies the file through, since Tailscale's own `${TS_CERT_DOMAIN}`
substitution covers the node's own domain. `{{KEY}}` tokens (filled from
`./iac-secrets.env (repo root, gitignored)`) are only needed for values Tailscale can't
substitute — e.g. a backend on a _different_ tailnet node, as in
`portainer/serve.json.tmpl` (backend is the separate `voyager` node); or a
value inside a `TCP` handler rather than a `Web` map key, since `${...}`
runtime substitution is only confirmed to apply to the latter — see
`pihole/serve.json.tmpl`'s `TerminateTLS` field, templated with
`{{TS_TAILNET_DOMAIN}}`. If you add a new `.tmpl` file (beyond the standard
`serve.json.tmpl`), also add its rendered output path to `.gitignore`.
