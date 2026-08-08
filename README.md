# Infrastructure as Code

Docker Compose stacks and Tailscale serve configuration for **NAS**, a
self-hosted Synology server on the `${TS_TAILNET_DOMAIN}` tailnet.

---

## Stacks

|| Stack           | Tailscale URL                                     | Pattern            |
| --------------- | ------------------------------------------------- | ------------------ |  |
| `affine` | `https://nas.${TS_TAILNET_DOMAIN}:3010` | host serve |  |
| `frigate` | `https://nas.${TS_TAILNET_DOMAIN}:8971` | host serve |  |
| `homeassistant` | `https://homeassistant.${TS_TAILNET_DOMAIN}` | host serve |  |
| `langfuse` | `https://langfuse.${TS_TAILNET_DOMAIN}` | TS sidecar |  |
| `mosquitto` | n/a — LAN/tailnet IP only, port 1883 | none |  |
| `n8n` | `https://n8n.${TS_TAILNET_DOMAIN}` | TS sidecar |  |
| `nextcloud` | `https://nextcloud.${TS_TAILNET_DOMAIN}` | TS sidecar |  |
| `openwebui` | `https://openwebui.${TS_TAILNET_DOMAIN}` | TS sidecar |  |
| `pihole` | `https://pihole.${TS_TAILNET_DOMAIN}` | TS sidecar + Caddy |  |
| `plex` | `https://plex.${TS_TAILNET_DOMAIN}` | TS sidecar |  |
| `portainer` | `https://portainer.${TS_TAILNET_DOMAIN}` | TS sidecar |  |
| `postgresql` | `https://nas.${TS_TAILNET_DOMAIN}:2660` (pgAdmin) | host serve |  |
| `syncthing` | `https://syncthing.${TS_TAILNET_DOMAIN}` | TS sidecar |  |

---

## Documentation

- **[docs/portainer_ui_basics.md](docs/portainer_ui_basics.md)** — Complete guide to Portainer UI operations
- **[docs/tailscale_patterns.md](docs/tailscale_patterns.md)** — Tailscale deployment patterns (A & B)
- **[docs/tailscale_serve_reference.md](docs/tailscale_serve_reference.md)** — Host-level `tailscale serve` reference
- **[docs/port_registry.md](docs/port_registry.md)** — Master port registry across all stacks
- **[docs/docker_compose_standards.md](docs/docker_compose_standards.md)** — Docker Compose best practices

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

```shell
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

```shell
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

```shell
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

## Directory layout

All stacks live under `/volume1/docker/stacks/<name>`. Each stack's directory
contains its compose file, generated `env.txt`, and any extra config
(serve.json, etc.). The `scripts/lib.sh` file is the single source of truth
for paths.

---

## Non-HTTP ports

These ports are reachable directly via the Tailscale IP/hostname but are
not handled by `tailscale serve` (HTTP/HTTPS only):

|| Service             | Port  | Protocol  | Notes                                                                                                                                       |
| ------------------- | ----- | --------- | ------------------------------------------------------------------------------------------------------------------------------------------- |  |
| Pi-hole DNS | 53 | TCP + UDP | Configure as tailnet DNS resolver in admin console |  |
| Langfuse / MinIO | 9090 | TCP | S3 API for direct media uploads — see langfuse's Pattern note (published directly on the `minio` sibling, not routed through `langfuse-tailscale`) |  |
| Frigate RTSP | 8554 | TCP | Use an RTSP client pointed at the Tailscale IP |  |
| Frigate WebRTC | 8555 | TCP + UDP | UDP not proxiable via serve |  |
| Syncthing sync | 22000 | TCP + UDP | Syncthing handles tailnet peers natively |  |
| Syncthing discovery | 21027 | UDP | — |  |
| PostgreSQL | 2665 | TCP | Connect via Tailscale IP directly |  |
| Mosquitto MQTT | 1883 | TCP | No Tailscale integration; reachable because the NAS host itself runs `tailscaled` |  |

See **[docs/port_registry.md](docs/port_registry.md)** for the complete master list.

---

## Quick Links

- **[QUICKSTART.md](QUICKSTART.md)** — Getting started guide
- **[AGENTS.md](AGENTS.md)** — Agent rules and documentation
- **[docs/TODO.md](docs/TODO.md)** — Known outstanding work
