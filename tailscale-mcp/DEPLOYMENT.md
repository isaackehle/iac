# Tailscale MCP Server - Deployment Instructions

## Quick Deploy via Portainer UI

### Step 1: Get Your Tailscale API Key

1. Go to <https://login.tailscale.com/admin/api>
2. Click "Generate API key"
3. Select `Read` and `Write` permissions
4. Copy the key (starts with `tskey-api-...`)

### Step 2: Deploy via Portainer

1. Open Portainer: <https://portainer.tail303fda.ts.net>
2. Navigate to **Stacks** → **Add stack**
3. Choose **Web editor**
4. Paste the contents of `docker-compose.yml` from this directory
5. In the **Environment variables** section, add:
   - `TAILSCALE_API_KEY` = your API key from Step 1
   - `TAILSCALE_TAILNET` = `tail303fda`
6. Click **Deploy**

### Step 3: Verify Deployment

1. Check the stack is running in Portainer
2. Test the MCP server:

   ```bash
   curl http://100.67.2.89:8000/health
   ```

## Configure Hermes to Use the MCP Server

Add this to your Hermes MCP configuration (typically in `~/.hermes/config.yaml` or your MCP client config):

```yaml
mcp:
  tailscale-admin:
    type: streamablehttp
    url: http://100.67.2.89:8000
    enabled: true
```

## Available Tools

Once configured, you can use these MCP tools:

- `list_devices` - Get all devices in your Tailscale network
- `get_device <device_id>` - Get details for a specific device
- `reboot_device <device_id>` - Reboot a device remotely
- `list_users` - Get all users in your tailnet
- `get_acl` - View current access control list
- `get_network_settings` - Get network configuration

## Troubleshooting

### Container Won't Start

- Check logs: `docker logs tailscale-mcp`
- Verify TAILSCALE_API_KEY is set correctly
- Ensure the API key has Read/Write permissions

### MCP Client Can't Connect

- Verify the container is running: `docker ps | grep tailscale-mcp`
- Check port 8000 is accessible: `nc -zv 100.67.2.89 8000`
- Restart your MCP client after adding the configuration

### API Authentication Errors

- Verify your API key hasn't expired
- Check that the tailnet name matches (tail303fda)
- Ensure the API key has the required permissions
