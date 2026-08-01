# Pi-hole — Portainer Stack Deployment

> Recommended: `scripts/deploy.sh all pihole <ssh-host>` from the repo root
> handles directory setup, `.env` generation, file placement, and bringing
> the stack up in one step — see root `README.md`/`QUICKSTART.md`. The
> manual steps below are the equivalent broken out.

## Directory Setup (on Synology NAS)

```shell
STACK_PATH="/volume1/docker/stacks/pihole"

mkdir -p $STACK_PATH/{etc-pihole,ts-state,ts-config}
```

Copy `serve.json` into `$STACK_PATH/ts-config/` — it's mounted at
`/config/serve.json` inside the Tailscale sidecar.

## Deploy via Portainer

1. Go to **Stacks → Add stack**
2. Choose **Repository** as the build method
3. Set:
   - **Repository URL:** `https://github.com/isaackehle/iac.git`
   - **Repository reference:** `refs/heads/main`
   - **Compose path:** `pihole/docker-compose.yml`
4. Under **Environment variables**, paste the contents of `.env.example` with
   real values filled in:
   - `PIHOLE_PASSWORD` — Pi-hole web admin password
   - `PIHOLE_UPSTREAMS` — upstream DNS servers (e.g. `1.1.1.1;8.8.8.8`)
   - `TZ` — timezone (e.g. `America/New_York`)
   - `TS_AUTHKEY` — Tailscale auth key (reusable, pre-authorized)
   - `TS_CERT_DOMAIN` — Tailscale MagicDNS domain (e.g. `pihole.${TS_TAILNET_DOMAIN}`)
5. Click **Deploy the stack**

## What the Stack Contains

| Container   | Image                        | Role                                                                                                           |
| ----------- | ---------------------------- | -------------------------------------------------------------------------------------------------------------- |
| `pihole`    | `pihole/pihole:latest`       | Pi-hole DNS/ad blocker — HTTP admin UI on container port 80 only                                               |
| `ts-pihole` | `tailscale/tailscale:latest` | Publishes DNS (53) + Pi-hole's HTTP UI on host ports 8280/8243; tailnet-only fallback via its own `serve.json` |

## Pi-hole Patterns

**Reverted 2026-08-01 (superseding the 2026-07-31 correction below):** the
"ts- first" approach — letting `ts-pihole`'s own `serve.json` or Tailscale's
host-level `tailscale serve` own port 443 — is **not** the access path
anymore. Reason: DSM already owns 443 on the NAS's real LAN/domain interface
for its own Login Portal and other reverse-proxied services, so anything
else wanting 443 on that same IP has to go through **DSM's built-in Reverse
Proxy** (Control Panel → Login Portal → Advanced → Reverse Proxy), not
compete with it via Tailscale.

Current setup: `ts-pihole` publishes `8280:80/tcp` and `8243:80/tcp` in
addition to `53:53` — both forward to Pi-hole's plain-HTTP admin UI
(container port 80; Pi-hole itself never terminates TLS). **DSM's Reverse
Proxy is configured manually in the DSM UI, not tracked in this repo** —
it needs two source rules pointing at the NAS's own `localhost`:

- Source `<domain>:80` (HTTP) → Destination `localhost:8280`
- Source `<domain>:443` (HTTPS, DSM terminates the cert) → Destination `localhost:8243`

`ts-pihole`'s `serve.json` / `TS_SERVE_CONFIG` is left in place as a
tailnet-only fallback (`https://pihole.${TS_TAILNET_DOMAIN}`) but is no
longer the primary path — don't rely on it for LAN/domain access.

See `pihole/DEBUG.md`'s "Access URLs" section and `homelab/docs/DECISIONS.md`
DEC-153 (supersedes DEC-152, which diagnosed the prior sidecar-only gap).

> ⚠️ **Open question, not yet confirmed:** whether the DSM Reverse Proxy
> rules above are actually configured with these exact backend ports — that
> lives entirely in DSM's UI and isn't visible from this repo. Confirm in
> Control Panel before assuming this path works end-to-end.

## First-Run Pi-hole Setup

1. From your LAN or public domain, visit `https://<your-domain>` — routed by
   DSM's Reverse Proxy to `localhost:8243` → Pi-hole's HTTP UI. From the
   tailnet only, `https://pihole.${TS_TAILNET_DOMAIN}` also still works via
   the sidecar's `serve.json`.
2. Log in with the `PIHOLE_PASSWORD` you set.
3. Go to **Settings → DNS** and verify your upstream servers are correct.
4. Configure your router or individual devices to use the Pi-hole's IP as
   their DNS server (port 53 is published on the host).

## Persistent Data

| Host Path                          | Container Path          | Contents                                           |
| ---------------------------------- | ----------------------- | -------------------------------------------------- |
| `$STACK_PATH/etc-pihole`           | `/etc/pihole`           | Pi-hole configuration, blocklists, DNS records     |
| `$STACK_PATH/ts-state`             | `/var/lib/tailscale`    | Tailscale identity (survives container recreation) |
| `$STACK_PATH/ts-config/serve.json` | `/config/serve.json:ro` | Tailscale serve rules                              |

## Access

| URL                                   | Description                                                             |
| ------------------------------------- | ----------------------------------------------------------------------- |
| `https://<your-domain>`               | Pi-hole admin — via DSM Reverse Proxy → `localhost:8243` (primary path) |
| `http://<your-domain>`                | Same, plain HTTP — via DSM Reverse Proxy → `localhost:8280`             |
| `https://pihole.${TS_TAILNET_DOMAIN}` | Pi-hole admin — tailnet-only fallback, via `ts-pihole`'s `serve.json`   |

## Backups

Include `$STACK_PATH/etc-pihole` and `$STACK_PATH/ts-state` in your Synology
backup task (Hyper Backup, Syncthing, etc.). The `etc-pihole` directory holds
your blocklists and DNS config; `ts-state` preserves the sidecar's tailnet
identity so it doesn't need re-authentication after a restore.

## References

- [How to Install Pi-Hole on Your Synology NAS – Marius Hosting](https://mariushosting.com/how-to-install-pi-hole-on-your-synology-nas/)
