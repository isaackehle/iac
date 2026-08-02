# Synology MCP Server — Portainer Deployment

Deploy the Synology MCP server via Portainer to enable AI agents to interact with your Synology NAS.

## Prerequisites

- Portainer connected to your Synology NAS Docker environment
- Tailscale network configured on Synology (voyager.tail303fda.ts.net)
- Web API enabled on Synology (see `~/sync/plans/004_synology-web-api-enable.md`)

## Deployment Steps

### 1. Via Portainer UI

1. Log into Portainer at `http://voyager.tail303fda.ts.net:9000` (or your Portainer instance)
2. Select your Docker environment (Synology NAS)
3. Click **Stacks** → **Add stack**
4. Choose **Web editor**
5. Copy contents of `docker-compose.yml` from this directory
6. Set **Working directory** to `/volume1/docker/stacks/synology-mcp`
7. Click **Load from file** and select `.env` (create it first)
8. Click **Deploy the stack**

### 2. Via CLI (Alternative)

```bash
# On Synology NAS via SSH
mkdir -p /volume1/docker/stacks/synology-mcp/config
cd /volume1/docker/stacks/synology-mcp
docker compose -f docker-compose.yml up -d
```

## Environment Variables

| Variable | Description | Required |
|----------|-------------|----------|
| `SYNOLOGY_HOST` | Synology hostname (Tailscale or local IP) | Yes |
| `SYNOLOGY_PORT` | DSM port (5000 or 5001) | Yes |
| `SYNOLOGY_SSL` | Use HTTPS (true/false) | Yes |
| `SYNOLOGY_USERNAME` | DSM username | Yes |
| `SYNOLOGY_PASSWORD` | DSM password | Yes |
| `SYNOLOGY_OTP_CODE` | 2FA OTP code (if enabled) | Optional |

## Verification

Check container status:
```bash
docker compose -f /volume1/docker/stacks/synology-mcp/docker-compose.yml ps
```

View logs:
```bash
docker compose -f /volume1/docker/stacks/synology-mcp/docker-compose.yml logs synology-mcp
```

## Testing the MCP Server

Test the connection via the MCP inspector:
```bash
npx @modelcontextprotocol/inspector npx -y @modelcontextprotocol/servers/synology
```

Or test the Web API directly:
```bash
curl -skL https://voyager.tail303fda.ts.net:5001/webapi/entry.cgi?api=SYNO.API.Info&method=query&version=1
```

## Troubleshooting

### Web API returns error 101

The Synology Web API HTTP endpoint may be disabled. Enable it via SSH:
```bash
sudo /usr/syno/bin/synowebapi --enable-lib SYNO.API.Info.lib SYNO.API.Auth.lib SYNO.Entry.Request.lib
```

See `~/sync/plans/004_synology-web-api-enable.md` for more details.

### Certificate errors

If you see certificate errors, ensure you're using the Tailscale certificate:
- Generate: `sudo /var/packages/Tailscale*/target/bin/tailscale cert --cert-file=/tmp/voyager.crt --key-file=/tmp/voyager.key voyager.tail303fda.ts.net`
- Copy to: `/usr/syno/etc/certificate/_archive/<ID>/`
- Restart nginx: `sudo /usr/bin/nginx -s reload`

## Updates

To update the MCP server:
```bash
cd /volume1/docker/stacks/synology-mcp
docker compose pull
docker compose up -d
```
