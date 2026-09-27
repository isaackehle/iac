# iac: NAS stacks

Docker Compose stacks for **NAS**, a Synology DS920+ on the `${TS_TAILNET_DOMAIN}`
tailnet. Each stack runs in Docker on the NAS and gets its own name on the tailnet
(`https://<stack>.${TS_TAILNET_DOMAIN}`) through a Tailscale sidecar container, so
nothing depends on the NAS's own Tailscale or on DSM's reverse proxy. Stacks are
deployed through Portainer where possible, and over SSH where not.

- **New here:** [QUICKSTART.md](QUICKSTART.md) walks through the one-time setup and
  a first deploy.
- **Agents:** read [AGENTS.md](AGENTS.md) first. It has the conventions and the
  mistakes not to repeat.
- **Not in this repo:** the local AI fleet (LM Studio, LiteLLM, model roles) lives
  in the `homelab` repo. Home Assistant runs on its own machine; this repo only
  gives it a tailnet front door (`ha`).

## Repo layout

```text
<stack>/                 one directory per stack
  docker-compose.yml     the stack (the only file Portainer reads)
  .env.example           the variables it needs, with generic placeholders
  serve.json.tmpl        its Tailscale serve config, rendered to serve.json
  INSTALLATION.md        how to deploy it; DEBUG.md: how to troubleshoot it
_template/               starting point for a new stack
scripts/                 deploy tooling; scripts/lib.sh holds every per-stack setting
docs/                    cross-stack docs (patterns, ports, Portainer, runbooks)
iac-secrets.env          every real value (gitignored); .example is committed
```

On the NAS, each stack lives in `/volume1/docker/stacks/<stack>/`: its compose
file, `.env`, Tailscale state (`ts-state/`), serve config (`ts-config/`) and data.

## Stacks

Every stack pins its Docker network to a `172.20.x.0/24` subnet (see the rules
below for why that matters). The next free subnet is `172.20.34.0/24`.

### Infrastructure

| Stack | What it is | URL | Network | Docs |
| --- | --- | --- | --- | --- |
| `portainer` | Docker management UI; deploys the other stacks | `https://portainer.${TS_TAILNET_DOMAIN}` | 172.20.21.0/24 | [install](portainer/INSTALLATION.md), [debug](portainer/DEBUG.md) |
| `pihole` | DNS ad blocking for the LAN and tailnet (DNS on 53) | `https://pihole.${TS_TAILNET_DOMAIN}` | 172.20.20.0/24 | [install](pihole/INSTALLATION.md), [debug](pihole/DEBUG.md) |
| `ha` | Tailnet front door for Home Assistant, which runs on its own machine | `https://ha.${TS_TAILNET_DOMAIN}`, MCP on `:9584` | 172.20.23.0/24 | [install](ha/INSTALLATION.md) |
| `mcp` | MCP servers for AI agents, one path each (`/synology`, ...). Server catalog: `~/code/isaackehle/mcp-servers/README.md` | `https://mcp.${TS_TAILNET_DOMAIN}/<server>/...` | 172.20.27.0/24 | [install](mcp/INSTALLATION.md) |

`portainer` is deployed over SSH: Portainer can't manage the stack it runs in, so
it always shows as "Limited" there.

### AI

| Stack | What it is | URL | Network | Docs |
| --- | --- | --- | --- | --- |
| `openwebui` | Chat UI in front of every fleet host's LiteLLM gateway | `https://openwebui.${TS_TAILNET_DOMAIN}` | 172.20.22.0/24 | [install](openwebui/INSTALLATION.md), [debug](openwebui/DEBUG.md), [readme](openwebui/README.md) |
| `langfuse` | LLM tracing and observability (MinIO S3 on 9090) | `https://langfuse.${TS_TAILNET_DOMAIN}` | 172.20.28.0/24 | [install](langfuse/INSTALLATION.md), [debug](langfuse/DEBUG.md) |

`openwebui` is the reference stack for the sidecar pattern.

### Home and devices

| Stack | What it is | URL | Network | Docs |
| --- | --- | --- | --- | --- |
| `mosquitto` | MQTT broker for IoT devices | `mosquitto.${TS_TAILNET_DOMAIN}`: MQTT 1883, MQTT/TLS 8883, WebSocket/TLS 443 | 172.20.26.0/24 | [install](mosquitto/INSTALLATION.md), [debug](mosquitto/DEBUG.md) |
| `frigate` | Camera NVR with object detection (RTSP 8554, WebRTC 8555) | `https://frigate.${TS_TAILNET_DOMAIN}` | 172.20.25.0/24 | [install](frigate/INSTALLATION.md), [debug](frigate/DEBUG.md) |
| `plex` | Media server | `https://plex.${TS_TAILNET_DOMAIN}` | 172.20.31.0/24 | [install](plex/INSTALLATION.md), [debug](plex/DEBUG.md) |

### Files, notes and automation

| Stack | What it is | URL | Network | Docs |
| --- | --- | --- | --- | --- |
| `nextcloud` | File storage and collaboration | `https://nextcloud.${TS_TAILNET_DOMAIN}` | 172.20.30.0/24 | [install](nextcloud/INSTALLATION.md), [debug](nextcloud/DEBUG.md) |
| `syncthing` | File sync between devices | `https://syncthing.${TS_TAILNET_DOMAIN}` | 172.20.33.0/24 | [install](syncthing/INSTALLATION.md), [debug](syncthing/DEBUG.md) |
| `affine` | Whiteboard and notes | `https://affine.${TS_TAILNET_DOMAIN}` | 172.20.24.0/24 | [install](affine/INSTALLATION.md), [debug](affine/DEBUG.md) |
| `n8n` | Workflow automation | `https://n8n.${TS_TAILNET_DOMAIN}` | 172.20.29.0/24 | [install](n8n/INSTALLATION.md), [debug](n8n/DEBUG.md) |
| `postgresql` | Shared Postgres (on 2665) with pgAdmin | `https://postgresql.${TS_TAILNET_DOMAIN}` (pgAdmin) | 172.20.32.0/24 | [install](postgresql/INSTALLATION.md), [debug](postgresql/DEBUG.md) |

### Not deployable yet

| Stack | Why |
| --- | --- |
| `tailscale-mcp` | A stdio-only MCP server, but its compose file publishes port 8000 (which also clashes with Portainer's) and health-checks a port nothing listens on. It belongs in `mcp` behind `mcp-proxy`; see [mcp/INSTALLATION.md](mcp/INSTALLATION.md). Not registered in `scripts/lib.sh`. |

## How a stack reaches the tailnet

The standard shape, used by every stack above:

```text
client on the tailnet
  │  https://<stack>.<tailnet>.ts.net  (Tailscale's own certificate)
  ▼
<stack>-tailscale   joins the tailnet as "<stack>"; serve.json:
  │                 TerminateTLS on 443, then TCPForward to 127.0.0.1:<app port>
  ▼
<stack> (app)       shares the sidecar's network namespace, so 127.0.0.1 is shared
```

- **Ports:** any port the LAN also needs (DNS, MQTT, RTSP...) is published on the
  sidecar, because the app has no network of its own.
- **Siblings:** containers like databases join the stack's network normally; the app
  reaches them by service name through the sidecar.
- **Inverted:** in `n8n`, `nextcloud`, `pihole` and `syncthing` the app owns the
  namespace and the sidecar borrows it. Same result.
- **Proxy mode:** `ha` (a machine elsewhere on the LAN that only speaks HTTPS) and
  `mcp` (routing by path) use Tailscale's web proxy mode instead of `TCPForward`.
- **Non-HTTP:** `mosquitto` forwards raw MQTT ports.

The full explanation, and why there's no Caddy or other reverse proxy:
[docs/tailscale_patterns.md](docs/tailscale_patterns.md). Every port:
[docs/port_registry.md](docs/port_registry.md). The serve config format:
[docs/tailscale_serve_reference.md](docs/tailscale_serve_reference.md).

## Rules that have caused outages

Each of these broke something at least once. [docs/outage_2026_08_03.md](docs/outage_2026_08_03.md)
covers the worst.

- **Pin every stack's network** to a `172.20.x.0/24` subnet. DSM's firewall drops
  forwarded traffic from Docker's default `192.168.x.0/20` pool, so an unpinned stack
  can silently lose outbound access (image pulls, Tailscale relays, certificates).
  Portainer did, on 2026-09-26.
- **Never restart a sidecar on its own.** The app keeps pointing at the old network
  namespace and gets "connection refused". `down` then `up -d` the whole stack.
- **Never put a literal `${TS_CERT_DOMAIN}` in `serve.json`.** Nothing expands it,
  and the node fails with "connection refused". Use `{{TS_TAILNET_DOMAIN}}` in
  `serve.json.tmpl`, which `gen-env.sh` renders.
- **Use absolute bind-mount paths** (`/volume1/docker/stacks/<stack>/...`).
  Portainer CE runs compose inside its own container, so `./file` resolves to a path
  that doesn't exist on the NAS, and Docker mounts an empty directory instead.
- **Terminate TLS once.** If the app serves HTTPS itself (Frigate does by default),
  turn that off or use proxy mode. `TCPForward` after `TerminateTLS` sends plaintext.
- **Verify every flag and setting** in the image's docs or `--help` before using it.
  An invented Portainer flag crash-looped it on 2026-09-26.

## Secrets and generated files

- **`iac-secrets.env`** (repo root, gitignored) holds every real value: auth keys,
  passwords, LAN IPs. Values can be 1Password `op://` references. Set
  `IAC_SECRETS_FILE` to keep it elsewhere.
- **`iac-secrets.env.example`** lists every key with generic placeholders
  (`192.168.x.x`, `your-tailnet-name.ts.net`). Keep real IPs, hostnames and keys out
  of it and out of every stack's `.env.example`.
- **`scripts/gen-env.sh <stack>`** (or `--all`) produces the per-stack files, both
  gitignored:
  - `<stack>/.env`, filled from the secrets file following the stack's `.env.example`;
  - every `*.tmpl` rendered to its plain name (`serve.json.tmpl` → `serve.json`),
    with `{{KEY}}` replaced from the secrets file.
- **`TS_CERT_DOMAIN`** is derived as `<stack>.<TS_TAILNET_DOMAIN>` unless set
  explicitly.
- **Placeholders** still blank or unchanged after generation are printed as
  warnings. Fill them in and re-run.

## Deploying

### Portainer-managed (preferred)

Portainer pulls the compose file from GitHub (`main`), so it can update and
redeploy the stack itself, and the stack shows as "Total" control in Portainer.

```shell
scripts/gen-env.sh <stack>              # .env + rendered templates
git push                                 # Portainer reads the compose file from GitHub main
scripts/deploy.sh dirs <stack> nas       # create the bind-mount folders (Portainer won't; the deploy fails without them)
scripts/deploy.sh extras <stack> nas     # copy bind-mounted files (serve.json, scripts) to the NAS
scripts/deploy.sh api <stack>            # create the stack in Portainer, with <stack>/.env as its variables
```

- **Requires** `PORTAINER_URL` and `PORTAINER_API_KEY` in `iac-secrets.env`.
- **The compose file has to be on `main`** on GitHub first, because that's what
  Portainer reads.
- **Moving a stack started with `docker compose` into Portainer** (it shows
  "Limited"): `docker compose down` on the NAS, then run the steps above. Data in
  `/volume1/docker/stacks/<stack>` bind mounts is kept, and so is the Tailscale
  identity in `ts-state/`, so no re-login.
- **Updating:** push, then in Portainer Stacks → `<stack>` → Pull and redeploy (or
  wait for its poll). Re-run `extras` if a bind-mounted file changed.

More: [docs/portainer_deployment.md](docs/portainer_deployment.md),
[docs/portainer_ui_basics.md](docs/portainer_ui_basics.md),
[scripts/README-PORTAINER-API.md](scripts/README-PORTAINER-API.md).

### Over SSH (bootstrap, and Portainer itself)

```shell
scripts/deploy.sh all <stack> nas        # env + dirs + push + serve + up
```

| Command | Does |
| --- | --- |
| `env <stack>` | Generate `<stack>/.env` locally. |
| `dirs <stack> <host>` | `mkdir -p` and `chown` the stack's directories on the NAS. |
| `push <stack> <host>` | Copy the compose file, `.env` and extra config. |
| `extras <stack> <host>` | Copy only the bind-mounted extra files (for Portainer-managed stacks). |
| `serve <stack> <host>` | Apply host-level `tailscale serve` mappings. No current stack has any. |
| `up <stack> <host>` | `docker compose up -d`. |
| `down <stack> <host>` | `docker compose down -v`. **Removes named volumes**; bind mounts survive. |
| `api <stack>` | Create the stack in Portainer (above). |
| `info <stack>` | Print the deploy steps for a stack. |

- **`<host>`** is anything `ssh` accepts: an `~/.ssh/config` alias like `nas`, or
  `user@<nas-ip>`.
- **Per-stack settings** come from [scripts/lib.sh](scripts/lib.sh): which
  directories to create, which extra files go where, and any host serve ports. There
  are no per-stack deploy scripts.
- **Updating Container Manager itself over SSH:**
  [docs/container_manager_update_via_ssh/](docs/container_manager_update_via_ssh/).

### Checking a deploy

```shell
docker ps --format 'table {{.Names}}\t{{.Status}}'      # on the NAS: app + sidecar up, matching uptimes
docker exec <stack>-tailscale tailscale serve status    # the forward it's serving
curl -sS -o /dev/null -w '%{http_code}\n' https://<stack>.<tailnet>.ts.net/   # from another tailnet machine
```

Test from another tailnet machine, not the NAS itself.

## Troubleshooting

| Symptom | Likely cause | Where to look |
| --- | --- | --- |
| "Connection refused" on the tailnet URL | `serve.json` wrong or stale, or the sidecar was restarted alone | The stack's `DEBUG.md`, [docs/tailscale_patterns.md](docs/tailscale_patterns.md) |
| Connects, then hangs at the TLS handshake | Tailscale chose a broken direct path. `pihole` and `portainer` force relaying with `TS_DEBUG_ALWAYS_USE_DERP=1` | [pihole/DEBUG.md](pihole/DEBUG.md), [docs/outage_2026_08_03.md](docs/outage_2026_08_03.md) |
| Sidecar logs "UDP is blocked", certificate timeouts | Unpinned network on a `192.168.x.x` subnet | Pin the subnet (rules above) |
| Container stuck in "Created" | A host port is already taken | [docs/port_registry.md](docs/port_registry.md) |
| Portainer shows the stack as "Limited" | Started with `docker compose`, not by Portainer | Deploying → Portainer-managed |
| Home Assistant answers 400 through `ha` | HA doesn't trust the proxy yet | [ha/INSTALLATION.md](ha/INSTALLATION.md) |

General Docker commands: [docs/debug_docker_commands.md](docs/debug_docker_commands.md).

## Adding a stack

1. **Copy `_template/`** to `<stack>/` and follow its [README](_template/README.md).
   Keep the sidecar pattern, and pin the next free subnet (`172.20.34.0/24`).
2. **Use absolute paths** for bind mounts.
3. **Add its keys** to `iac-secrets.env.example` (placeholders) and
   `iac-secrets.env` (real values).
4. **Register it in [scripts/lib.sh](scripts/lib.sh):** `ALL_STACKS`,
   `STACK_REMOTE_DIR`, `STACK_DIRS` (include `ts-state ts-config`),
   `STACK_EXTRA_FILES` (`serve.json:ts-config/serve.json`).
5. **Document it:** add it to the tables above and to
   [docs/port_registry.md](docs/port_registry.md). Write its `INSTALLATION.md`.
6. **Deploy:** `scripts/deploy.sh info <stack>`, then Portainer-managed if you can.

**Adding an MCP server** doesn't need a new stack: it's a new service in `mcp`. See
[mcp/INSTALLATION.md](mcp/INSTALLATION.md).

## Docs

| Doc | For |
| --- | --- |
| [QUICKSTART.md](QUICKSTART.md) | One-time setup and a first deploy |
| [AGENTS.md](AGENTS.md) | Conventions for AI agents working in this repo |
| [docs/tailscale_patterns.md](docs/tailscale_patterns.md) | How each stack is exposed, and why |
| [docs/tailscale_serve_reference.md](docs/tailscale_serve_reference.md) | `serve.json` format and host serve commands |
| [docs/tailscale.md](docs/tailscale.md) | Tailscale notes |
| [docs/port_registry.md](docs/port_registry.md) | Every port, every stack |
| [docs/docker_compose_standards.md](docs/docker_compose_standards.md) | Compose layout and correctness rules |
| [docs/portainer_deployment.md](docs/portainer_deployment.md) | Deploying through Portainer |
| [docs/portainer_ui_basics.md](docs/portainer_ui_basics.md) | Using the Portainer UI |
| [docs/portainer_iac_migration.md](docs/portainer_iac_migration.md) | Moving stacks into Portainer |
| [docs/portainer_api/](docs/portainer_api/) | Portainer API notes |
| [docs/debug_docker_commands.md](docs/debug_docker_commands.md) | Troubleshooting commands |
| [docs/docker_no_sudo.md](docs/docker_no_sudo.md) | Running `docker` on DSM without sudo |
| [docs/nas_terminal_config.md](docs/nas_terminal_config.md) | Shell setup on the NAS |
| [docs/scp_sync.md](docs/scp_sync.md) | Copying files to the NAS (`scp -O`) |
| [docs/markdown_linting.md](docs/markdown_linting.md) | Markdown lint setup |
| [docs/outage_2026_08_03.md](docs/outage_2026_08_03.md) | The Portainer outage behind several rules |
| [docs/rebuild_2026_08.md](docs/rebuild_2026_08.md) | The August 2026 rebuild |
| [docs/TODO.md](docs/TODO.md) | Known outstanding work |

## Known issues

- **`tailscale-mcp`:** not deployable as written (see "Not deployable yet").
