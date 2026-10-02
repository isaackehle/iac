# ha: Tailscale front door for Home Assistant

Gives Home Assistant (`HA_LAN_IP` in `iac-secrets.env`) the tailnet name
`https://ha.<tailnet>.ts.net`, its MCP server `https://ha.<tailnet>.ts.net:9584`,
its Observer health page `https://ha.<tailnet>.ts.net:4357`, and raw-TCP relays for
HA's own ports: `8123` (UI on its native port) and `2222`
(SSH into the HA box). See the header of `docker-compose.yml` for why it's a
separate node and why the UI uses Tailscale's Web/Proxy serve mode.

## 1. Let Home Assistant trust the proxy

Without this, HA rejects proxied requests with HTTP 400. In HA's
`configuration.yaml`, add (or merge into an existing `http:` block):

```yaml
http:
  use_x_forwarded_for: true
  trusted_proxies:
    - <NAS LAN IP 1>   # the NAS's first LAN port
    - <NAS LAN IP 2>   # the NAS's second LAN port
```

List **both** NAS addresses. The NAS has two LAN ports, and it can switch which one it
uses to reach Home Assistant (it did on 2026-09-27). HA then sees requests from the
other address and answers 400 again. To see the one in use right now, run
`ip route get <HA_LAN_IP>` on the NAS (the `src` address).

Restart Home Assistant.

## 2. SSH into the HA box through this node (port 2222)

The `ha` node relays raw TCP on `2222` straight to `HA_LAN_IP:2222` — no TLS
termination, so the normal SSH handshake passes through unchanged. Add to your
`~/.ssh/config`:

```sshconfig
Host ha-pi
    HostName ha.tail303fda.ts.net
    Port 2222
    User ha-admin
    IdentityFile ~/.ssh/id_ed25519
    IdentitiesOnly Yes
```

Then `ssh ha-pi` from any tailnet machine. The user and key must match the
add-on's config (user `ha-admin` by default, `authorized_keys` list) — check
Settings → Add-ons → Advanced SSH & Web Terminal → Configuration if auth fails.
Do **not** set the add-on's `log_level` to `debug`: the add-on then runs sshd in
single-connection mode and every other connection gets reset.

**This relay only works if the HA box is listening on 2222.** If it isn't, you
get an immediate `Connection refused` at the node — that is the HA box refusing,
not Tailscale. On Home Assistant OS the common causes are:

- the **Advanced SSH & Web Terminal** add-on stopped (start it in HA Settings →
  Add-ons), or
- an sshd container previously published `2222:22` by Portainer and is now **stopped**
  (start it in Portainer). When the old host-network `homeassistant` stack was replaced
  by this proxy stack (2026-09-26, PR #2), its `2222:22` mapping went away with it.

Confirm from the HA box with `ss -ltn | grep 2222` or `netstat -ltn | grep 2222`.

## 3. Nabu Casa (Home Assistant Cloud) remote access

Nabu Casa remote access is **not configured by this stack** — it is a Home
Assistant subscription/integration, toggled by the user in **Settings → Home
Assistant Cloud** (Remote UI). This node only exposes the LAN ports a cloud
route could use. If Remote UI shows disconnected, re-enable it in the HA UI; a
repo change cannot bring it back.

## 4. Deploy

```shell
scripts/gen-env.sh ha              # .env (TS_AUTHKEY) + serve.json from serve.json.tmpl
scripts/deploy.sh all ha nas       # dirs, files, docker compose up -d
# or, Portainer-managed: push the repo, then
#   scripts/deploy.sh dirs ha nas && scripts/deploy.sh extras ha nas && scripts/deploy.sh api ha
```

Never restart the sidecar alone — always `docker compose down && docker compose
up -d --force-recreate` (Tailscale reads `serve.json` only at container start).

## 5. Verify

```shell
docker exec ha-tailscale tailscale serve status          # shows the 8123/2222 TCP listeners
curl -sS -o /dev/null -w '%{http_code}\n' https://ha.<tailnet>.ts.net/      # from a tailnet machine: 200
curl -sS -o /dev/null -w '%{http_code}\n' https://ha.<tailnet>.ts.net:9584/ # MCP add-on: 404 at / is normal
curl -sS -o /dev/null -w '%{http_code}\n' https://ha.<tailnet>.ts.net:4357/ # Observer health page: 200
ssh -p 2222 ha-admin@ha.<tailnet>.ts.net hostname        # HA box hostname (only if its sshd runs)
```

Then point the MCP client at the new URL: `HOMEASSISTANT_MCP_URL` in
`~/.config/ha-mcp/env` becomes `https://ha.<tailnet>.ts.net:9584/private_<id>`.
