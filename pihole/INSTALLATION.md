# Pi-hole — Portainer Stack Deployment

> Recommended: `scripts/deploy.sh all pihole <ssh-host>` from the repo root
> handles directory setup, `.env` generation, file placement, and bringing
> the stack up in one step — see root `README.md`/`QUICKSTART.md`. The
> manual steps below are the equivalent broken out.

## Directory Setup (on Synology NAS)

- Create paths

  ```shell
  STACK_PATH="/volume1/docker/stacks/pihole"

  mkdir -p $STACK_PATH/{etc-pihole,ts-state,ts-config,caddy-config}
  ```

- Copy `serve.json` into `$STACK_PATH/ts-config/`
  — it's mounted at `/config/serve.json` inside the Tailscale sidecar.

- Copy `Caddyfile` into `$STACK_PATH/caddy-config/`
  — it's mounted at `/etc/caddy` inside the `caddy` container.

## Deploy via Portainer

1. Go to **Stacks → Add stack**
1. Add **pihole** as the stack name
1. Choose **Repository** as the build method
1. Set:
   - **Repository URL:** `https://github.com/isaackehle/iac.git`
   - **Repository reference:** `refs/heads/main`
   - **Compose path:** `pihole/docker-compose.yml`
1. Under **Environment variables**, paste the contents of `.env.example` with
   real values filled in:
   - `PIHOLE_PASSWORD` — Pi-hole web admin password
   - `PIHOLE_UPSTREAMS` — upstream DNS servers (e.g. `1.1.1.1;8.8.8.8`)
   - `TZ` — timezone (e.g. `America/New_York`)
   - `TS_AUTHKEY` — Tailscale auth key (reusable, pre-authorized)
   - `TS_CERT_DOMAIN` — Tailscale MagicDNS domain (e.g. `pihole.${TS_TAILNET_DOMAIN}`)
1. Click **Deploy the stack**

## What the Stack Contains

| Container   | Image                        | Role                                                                                                                                       |
| ----------- | ---------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------ |
| `pihole`    | `pihole/pihole:latest`       | Pi-hole DNS/ad blocker — HTTP admin UI on container port 80 only, publishes DNS (53) + a plain-HTTP debug port (8280) directly to the host |
| `ts-pihole` | `tailscale/tailscale:latest` | Joins the tailnet as the `pihole` node; terminates TLS on 443 and forwards decrypted bytes to `caddy` (see below)                          |
| `caddy`     | `caddy:2-alpine`             | Real HTTP reverse proxy from `ts-pihole`'s TCP forward to Pi-hole's `127.0.0.1:80`                                                         |

## Pi-hole Access Architecture

**Current design (2026-08-01), superseding both prior attempts** — see
`homelab/docs/DECISIONS.md` for the full history (DEC-152 diagnosed a
sidecar-only gap; DEC-153 briefly tried routing through DSM's Reverse Proxy;
this design replaced that after finding it wasn't actually what was wanted).

`ts-pihole`, `caddy`, and `pihole` all share one network namespace
(`network_mode: service:pihole`). The tailnet-facing path is:

```text
client --TLS--> ts-pihole:443 (tailscaled terminates TLS,
                                automatic Tailscale cert)
             --plaintext TCP--> caddy:8444 (internal only, not published)
             --HTTP--> pihole:80
```

This uses Tailscale's `TCPForward`/`TerminateTLS` serve mode rather than its
usual `Web`/`Proxy` mode — `tailscaled`'s own built-in HTTP reverse proxy is
[documented as significantly slower](https://github.com/tailscale/tailscale/issues/18307)
under concurrent load, enough to make Pi-hole's admin UI hang loading its
own CSS/JS. Caddy does the actual HTTP-level proxying instead; Tailscale
still handles all TLS, so Caddy needs no cert of its own.

DSM's own Reverse Proxy is **not** used for this stack — that was a
same-day detour, reverted. See `README.md`'s "pihole — Pattern B + Caddy"
section for the exact `serve.json` schema.

A raw plain-HTTP path also exists at `pihole:8280`, published directly on
the host and bypassing Caddy entirely — useful for debugging without any
TLS/proxy layer in the way.

## First-Run Pi-hole Setup

1. From your tailnet, visit `https://pihole.${TS_TAILNET_DOMAIN}`.
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
| `$STACK_PATH/caddy-config`         | `/etc/caddy:ro`         | `Caddyfile`                                        |

## Access

| URL                                       | Description                                                       |
| ----------------------------------------- | ----------------------------------------------------------------- |
| `https://pihole.${TS_TAILNET_DOMAIN}`     | Pi-hole admin — primary path, via `ts-pihole` → `caddy` → Pi-hole |
| `http://pihole.${TS_TAILNET_DOMAIN}:8280` | Raw debug path, straight to Pi-hole, no TLS/proxy involved        |

## Backups

Include `$STACK_PATH/etc-pihole` and `$STACK_PATH/ts-state` in your Synology
backup task (Hyper Backup, Syncthing, etc.). The `etc-pihole` directory holds
your blocklists and DNS config; `ts-state` preserves the sidecar's tailnet
identity so it doesn't need re-authentication after a restore.

## References

- [How to Install Pi-Hole on Your Synology NAS – Marius Hosting](https://mariushosting.com/how-to-install-pi-hole-on-your-synology-nas/)
- [tailscale serve HTTP proxy is ~5x slower than directly connecting or Caddy · Issue #18307](https://github.com/tailscale/tailscale/issues/18307)
