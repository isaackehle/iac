# ha: Tailscale front door for Home Assistant

Gives Home Assistant (`HA_LAN_IP` in `iac-secrets.env`) the tailnet name
`https://ha.<tailnet>.ts.net`, and its MCP server `https://ha.<tailnet>.ts.net:9584`.
See the header of `docker-compose.yml` for why it's a separate node and why it
uses Tailscale's Web/Proxy serve mode.

## 1. Let Home Assistant trust the proxy

Without this, HA rejects proxied requests with HTTP 400. In HA's
`configuration.yaml`, add (or merge into an existing `http:` block):

```yaml
http:
  use_x_forwarded_for: true
  trusted_proxies:
    - <NAS_LAN_IP>   # the NAS (NAS_LAN_IP in iac-secrets.env); the ha container's traffic leaves through it
```

Restart Home Assistant.

## 2. Deploy

```shell
scripts/gen-env.sh ha              # .env (TS_AUTHKEY) + serve.json from serve.json.tmpl
scripts/deploy.sh all ha nas       # dirs, files, docker compose up -d
# or, Portainer-managed: push the repo, then scripts/deploy.sh api ha
```

## 3. Verify

```shell
docker exec ha-tailscale tailscale serve status
curl -sS -o /dev/null -w '%{http_code}\n' https://ha.<tailnet>.ts.net/      # from a tailnet machine: 200
curl -sS -o /dev/null -w '%{http_code}\n' https://ha.<tailnet>.ts.net:9584/ # MCP add-on: 404 at / is normal
```

Then point the MCP client at the new URL: `HOMEASSISTANT_MCP_URL` in
`~/.config/ha-mcp/env` becomes `https://ha.<tailnet>.ts.net:9584/private_<id>`.
