# esphome

ESPHome compiler + dashboard, hosted on NAS and exposed only via the
Tailscale tailnet. Sole purpose: keep IoT firmware tooling alive
across HA-OS restarts or upgrades, and let the HA-side `esphome`
integration point here via "Add device → by host".

## Why a stack at all

Today the `esphome` add-on runs inside HA-OS on the Pi. If HA Core
restarts or the OS reboots, the dashboard goes down with it, and any
in-progress firmware flash is interrupted. Hosting the dashboard on
NAS moves that dependency to a node (Synology) that already runs other
GitOps stacks via Portainer.

## Why this shape

| Concern           | Decision                                                                                          |
| ----------------- | ------------------------------------------------------------------------------------------------- |
| mDNS multicast    | `network_mode: host` on the primary (mDNS is link-local; it doesn't cross a Docker bridge)        |
| External exposure | Tailscale sidecar + `TS_HOSTNAME=esphome`; never `0.0.0.0` and never published via `ports:`       |
| TLS to dashboard  | Tailscale terminates TLS using its Let's Encrypt cert and forwards plain HTTP to `127.0.0.1:6052` |
| Auth              | ESPHome's own `api:` + `password:` per-device YAML; no credentials in this repo                   |
| Data location     | `config/` (gitignored), holds YAML source + compiled firmware per device                          |
| Secrets           | `iac-secrets.env` at repo root; `TS_AUTHKEY` only ever as a placeholder here                      |

## HA-side wiring

After deployment, in HA's `esphome` integration use **Add device →
by host** and point it at
`https://esphome.${TS_TAILNET_DOMAIN}`. HA can still discover ESPHome
devices on the local LAN via `esphome` integration's mDNS scope (as
long as the Pi and NAS are on the same broadcast domain).

## Deploy

The supported path is the Portainer API. From the repo root:

```shell
scripts/deploy.sh api esphome
```

Portainer (GitOps mode) pulls `esphome/docker-compose.yml` from
`isaackehle/iac` `main` and tracks subsequent edits. Redeploys after
a compose change: `scripts/deploy.sh redeploy esphome`. SSH-based
fallback if Portainer is unreachable: `scripts/deploy.sh all esphome
nas`. Full steps in `INSTALLATION.md`.

## See also

- `_template/README.md` for the sidecar pattern this follows.
- `dsm/docker-compose.yml` for the bridged-sidecar variant.
- `ha/` for the broader HA-on-Pi context this stack decouples from.
- `homelab/profiles/ds9/README.md` for the data-plane side downstream
  of these devices (Wyoming STT/TTS calls `ds9` services).
- `devops/portainer-api-deploy` skill for the Portainer API flow.
