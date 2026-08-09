# Tailscale MCP Server

MCP server for interacting with the Tailscale Admin API.

## Prerequisites

1. **Tailscale API Key** - Create via Tailscale Admin Console:
   - Navigate to https://login.tailscale.com/admin/api
   - Generate a new API key with `Read` and `Write` permissions
   - Copy the key (starts with `tskey-api-...`)

## Environment Variables

- `TAILSCALE_API_KEY` - Your Tailscale API key (required)
- `TAILSCALE_TAILNET` - Your tailnet name (e.g., `tail303fda`)

## Tools Available

### `list_devices`
Get all devices in the Tailscale tailnet with their status and details.

### `get_device`
Get details for a specific device by ID.

### `reboot_device`
Reboot a specific device in the Tailscale network.

### `list_users`
Get all users in the Tailscale tailnet.

### `get_acl`
Get the current ACL (Access Control List) configuration.

### `get_network_settings`
Get network settings and configuration for the tailnet.

## Deployment

### Local Testing

```bash
export TAILSCALE_API_KEY="tskey-api-..."
export TAILSCALE_TAILNET="tail303fda"
docker build -t tailscale-mcp:latest .
docker run --rm -e TAILSCALE_API_KEY -e TAILSCALE_TAILNET tailscale-mcp:latest
```

### Deploy to Synology via Portainer

1. Build the image locally:
   ```bash
   cd /Users/isaac/code/isaackehle/mcp-servers/tailscale
   docker build -t tailscale-mcp:latest .
   ```

2. Push to a registry (or use Portainer's "Upload compose" feature)

3. Deploy via Portainer UI:
   - Navigate to Stacks → Add Stack
   - Choose "Web editor" mode
   - Paste the docker-compose.yml content
   - Set environment variables in Portainer
   - Click "Deploy"

### Configure in Hermes

Add to your Hermes MCP configuration:

```json
{
  "tailscale-admin": {
    "type": "local",
    "command": [
      "/Users/isaac/.local/bin/uv",
      "tool",
      "run",
      "--with",
      "mcp<2.0",
      "tailscale-mcp",
      "--host",
      "100.67.2.89",
      "--port",
      "8000"
    ],
    "enabled": true,
    "env": {
      "TAILSCALE_API_KEY": "{env:TAILSCALE_API_KEY}",
      "TAILSCALE_TAILNET": "tail303fda"
    }
  }
}
```

## API Endpoints

This server wraps the Tailscale Admin API v2:
- `GET /api/v2/tailnet/{tailnet}/device` - List devices
- `GET /api/v2/tailnet/{tailnet}/device/{id}` - Get device
- `POST /api/v2/tailnet/{tailnet}/device/{id}/reboot` - Reboot device
- `GET /api/v2/tailnet/{tailnet}/user` - List users
- `GET /api/v2/tailnet/{tailnet}/acl` - Get ACL
- `GET /api/v2/tailnet/{tailnet}/settings` - Get settings

## Security

- API key is stored as an environment variable only
- No credentials are logged or persisted
- Server runs with minimal permissions
- Communication is over HTTPS to Tailscale API

## Troubleshooting

### Connection Refused
- Verify the container is running: `docker ps | grep tailscale-mcp`
- Check logs: `docker logs tailscale-mcp`
- Verify environment variables are set correctly

### API Authentication Error
- Verify TAILSCALE_API_KEY is correct
- Check API key has Read/Write permissions
- Ensure tailnet name matches your Tailscale tailnet

### Tool Not Found
- Verify MCP server is running and accessible
- Check Hermes MCP configuration points to correct host/port
- Restart Hermes after adding MCP server config
