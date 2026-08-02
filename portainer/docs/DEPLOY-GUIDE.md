# Deploy Portainer on Synology NAS via Container Manager UI

## Current Status

- ✅ Container Manager package installed
- ✅ Docker socket accessible (Pihole is running)
- ❌ No standard `docker` CLI available on Synology
- ❌ Portainer container exists but is **exited** (missing Tailscale sidecar)

## Why CLI Doesn't Work

Synology's Container Manager package doesn't expose a standard `docker` CLI command. It uses Synology's internal Docker API which requires:

- Authentication via DSM web interface
- Synology's proprietary container management tools

## Solution: Deploy via Container Manager UI

### Step 1: Access Container Manager

1. Open DSM web interface: `http://voyager.tail303fda.ts.net:5000` or `http://192.168.68.78:5000`
2. Login with your credentials
3. Open **Container Manager** from the main menu
4. Go to **Project** tab

### Step 2: Create Simple Portainer Project

1. Click **Create** → **Project**
2. Choose **Import from YAML/JSON**
3. Copy the content from `~/code/isaackehle/iac/portainer/simple/docker-compose.yml`:

```yaml
version: '3.8'

services:
  portainer:
    image: portainer/portainer-ce:latest
    container_name: portainer
    restart: always
    ports:
      - '9000:9000'
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - /volume1/docker/portainer-data:/data

volumes:
  portainer-data:
```

4. Click **Next**

### Step 3: Configure Environment

No environment variables needed for simple Portainer.

### Step 4: Deploy

1. Click **Apply** to deploy the project
2. Wait for the container to start (may take 1-2 minutes)
3. Check status in the **Project** tab

### Step 5: Verify Deployment

1. Check that the `portainer` container is **running**
2. Access Portainer at: `http://voyager.tail303fda.ts.net:9000`

## First-Time Setup

1. Navigate to `http://voyager.tail303fda.ts.net:9000`
2. Create admin user (username/password)
3. You now have Portainer running!

## Next Steps After Portainer is Running

### Deploy Synology MCP Server

1. Go to Portainer → **Stacks** → **Add stack**
2. Choose **Web editor**
3. Copy content from `~/code/isaackehle/iac/synology-mcp/docker-compose.yml`
4. Set working directory to `/volume1/docker/stacks/synology-mcp`
5. Click **Load from file** and select `~/code/isaackehle/iac/synology-mcp/.env`
6. Click **Deploy the stack**

### Verify MCP Server

1. Check container logs: `docker logs synology-mcp`
2. Test Web API connectivity via Portainer's terminal

## Troubleshooting

### Portainer Won't Start

1. Check logs in Container Manager UI
2. Verify disk space: `df -h /volume1/docker`
3. Check if port 9000 is already in use

### Web API Error 101

The Synology Web API HTTP endpoint returns error 101. This is a DSM 7.3.2 limitation.

**Solution**: The MCP server will work via the Docker MCP implementation once deployed.

### Tailscale Certificate Issue

The Tailscale certificate was generated but nginx needs restart to activate it.

**Current status**: Certificate files are in `/usr/syno/etc/certificate/_archive/emdbz8/`

## Alternative: Fix Existing Portainer Stack

If you want to restore the existing Portainer stack with Tailscale:

1. The `ts-portainer` (Tailscale sidecar) container is missing
2. You need to manually create and start the sidecar container first
3. Then start the Portainer container

See `~/code/isaackehle/iac/portainer/old/compose.yaml` for the full configuration.

## Files Reference

- Simple Portainer compose: `~/code/isaackehle/iac/portainer/simple/docker-compose.yml`
- MCP server stack: `~/code/isaackehle/iac/synology-mcp/docker-compose.yml`
- MCP credentials: `~/code/isaackehle/iac/synology-mcp/.env`
- Recovery guide: `~/code/isaackehle/iac/portainer/RECOVERY.md`
