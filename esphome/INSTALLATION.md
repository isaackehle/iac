# Installation: esphome

ESPHome compiler + dashboard on NAS, reachable only via the tailnet at
`https://esphome.${TS_TAILNET_DOMAIN}`.

## Prereqs

A working `iac-secrets.env` at the repo root with at minimum:

- `TS_TAILNET_DOMAIN=tail303fda.ts.net`
- A reusable, pre-authorized `TS_AUTHKEY` (generate at
  <https://login.tailscale.com/admin/settings/keys>).

Verify:

```shell
grep -E '^(TS_AUTHKEY|TS_TAILNET_DOMAIN)=' iac-secrets.env
```

## Deploy: Portainer API (preferred)

The Portainer API is the supported path: it creates the stack in
Portainer (GitOps mode), pulling `esphome/docker-compose.yml` from
GitHub `main`. Subsequent edits on `main` flow through on the next
redeploy. This is preferred because Portainer owns the stack lifecycle
— track-and-redeploy guarantees, no drift between Git and the running
compose.

```shell
scripts/deploy.sh api esphome
```

The script:

1. Validates `PORTAINER_URL` + `PORTAINER_API_KEY` (Tailnet-reachable
   at `https://portainer.${TS_TAILNET_DOMAIN}`).
2. Creates a stack named `esphome` on endpoint 3.
3. Configures Portainer to pull `isaackehle/iac` from `main`.
4. Renders `serve.json.tmpl` into a gitignored `serve.json` and
   forwards env vars (`TS_AUTHKEY`, `TS_TAILNET_DOMAIN`) as stack
   secrets.

To redeploy after a compose change:

```shell
scripts/deploy.sh redeploy esphome
```

**Pitfall.** The Portainer `GET /api/stacks?name=<stack>` query
parameter is ignored — it always returns the first stack. Always
fetch all and filter client-side:

```shell
curl -sS -H "X-Api-Key: $PORTAINER_API_KEY" \
  "$PORTAINER_URL/api/stacks" | \
  jq '.[] | select(.Name == "esphome") | {Id, Name, Status, EndpointId}'
```

## Deploy: SSH GitOps (fallback)

If the Portainer API key is missing or expired (or this host doesn't
run Portainer), fall back to the SSH-based GitOps deployer:

```shell
scripts/deploy.sh all esphome nas
```

This pushes the rendered compose to `/volume1/docker/stacks/esphome`
over SSH (`scp -O`, DSM-friendly) and starts it manually. Less
preferred because it bypasses Portainer and its
track-and-redeploy guarantees.

## Verify

```shell
ssh esphome 'docker ps -a | grep esphome'
ssh esphome 'tailscale status' | grep esphome
curl -ksSI https://esphome.${TS_TAILNET_DOMAIN}/
```

Expected:

- `esphome` and `esphome-tailscale` running for at least a minute.
- MagicDNS entry under `esphome.<tailnet>.ts.net`.
- HTTP `200` from the dashboard.

## Add a device

- Place a YAML in `config/<device>.yaml` (or use the dashboard's
  file editor).
- Connect via USB or OTA from the dashboard.
- On first compile, ESPHome downloads the matching platform
  toolchain into `./config/.esphome/` (excluded by `.gitignore`).

In HA's `esphome` integration use **Add device → by host** and point
it at `https://esphome.${TS_TAILNET_DOMAIN}`. HA can still discover
ESPHome devices on the local LAN via `esphome` integration's mDNS
scope (as long as the Pi and NAS share a broadcast domain).

## Upgrades

```shell
scripts/deploy.sh up esphome
```

Never restart the sidecar alone. See `DEBUG.md`.

## Rollback

```shell
ssh esphome 'cd /volume1/docker/stacks/esphome \
  && docker compose down \
  && rm -rf ./config ./.esphome ./ts-state ./ts-config'
```

The directory is recreated by a fresh deploy; nothing else references
this stack by host name.

## Secrets

No secrets in this repo. `TS_AUTHKEY` and `TS_TAILNET_DOMAIN` live in
`iac-secrets.env` (repo root, gitignored). For browser auth on the
ESPHome dashboard, configure `api:` + `password:` blocks per device
YAML under `config/`.
