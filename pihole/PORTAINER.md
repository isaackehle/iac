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
   - **Repository URL:** `github.com/isaackehle/iac.git`
   - **Repository reference:** `refs/heads/main`
   - **Compose path:** `pihole/docker-compose.yml`
4. Under **Environment variables**, paste the contents of `.env.example` with
   real values filled in:
   - `PIHOLE_PASSWORD` — Pi-hole web admin password
   - `PIHOLE_UPSTREAMS` — upstream DNS servers (e.g. `1.1.1.1 8.8.8.8`)
   - `TZ` — timezone (e.g. `America/New_York`)
   - `TS_AUTHKEY` — Tailscale auth key (reusable, pre-authorized)
   - `TS_CERT_DOMAIN` — Tailscale MagicDNS domain (e.g. `pihole.${TS_TAILNET_DOMAIN}`)
5. Click **Deploy the stack**

## What the Stack Contains

| Container   | Image                        | Role                                                                 |
| ----------- | ---------------------------- | -------------------------------------------------------------------- |
| `pihole`    | `pihole/pihole:latest`       | Pi-hole DNS/ad blocker — publishes ports 53, 8080, 8443 on the host  |
| `ts-pihole` | `tailscale/tailscale:latest` | Tailscale sidecar — also has a `serve.json` for tailnet HTTPS access |

## Pi-hole Patterns

Pi-hole uses a **hybrid** setup — both host-level `tailscale serve` (Pattern A)
and a sidecar container (Pattern B) are active simultaneously:

- **Host-level serve:** `nas.${TS_TAILNET_DOMAIN}:8080` (HTTP) and `:8443` (HTTPS)
  — applied via `scripts/deploy.sh serve pihole <ssh-host>` or
  `scripts/serve-all.sh`. See `scripts/lib.sh` (`STACK_SERVE_PORTS`).
- **Sidecar serve:** `pihole.${TS_TAILNET_DOMAIN}` via `ts-pihole`'s own
  `serve.json` — proxies to `http://127.0.0.1:8443`.

> ⚠️ This is the only stack that uses both patterns. Don't use it as a template
> for a new stack; pick one instead.

## First-Run Pi-hole Setup

1. From a device on your tailnet, visit `https://pihole.${TS_TAILNET_DOMAIN}`
   (sidecar) or `https://nas.${TS_TAILNET_DOMAIN}:8443` (host-level serve).
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

| URL                                     | Description                                  |
| --------------------------------------- | -------------------------------------------- |
| `https://pihole.${TS_TAILNET_DOMAIN}`   | Pi-hole admin (tailnet-only, via sidecar)    |
| `https://nas.${TS_TAILNET_DOMAIN}:8443` | Pi-hole admin (tailnet-only, via host serve) |
| `http://nas.${TS_TAILNET_DOMAIN}:8080`  | Pi-hole admin (tailnet-only, HTTP)           |

## Backups

Include `$STACK_PATH/etc-pihole` and `$STACK_PATH/ts-state` in your Synology
backup task (Hyper Backup, Syncthing, etc.). The `etc-pihole` directory holds
your blocklists and DNS config; `ts-state` preserves the sidecar's tailnet
identity so it doesn't need re-authentication after a restore.

## References

- [How to Install Pi-Hole on Your Synology NAS – Marius Hosting](https://mariushosting.com/how-to-install-pi-hole-on-your-synology-nas/)
