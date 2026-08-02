# Portainer Recovery Guide for Synology NAS

## Current Status

- ✅ Container Manager package installed
- ✅ Docker socket accessible
- ✅ Pihole container running
- ❌ Portainer container **exited** (error: "cannot join network of a non running container")
- ❌ `ts-portainer` (Tailscale sidecar) container **missing**

## Problem

The Portainer stack was deployed with a Tailscale sidecar (`ts-portainer`), but that container is missing. The main Portainer container depends on it and cannot
start.

## Solution: Deploy Simple Portainer (Without Tailscale)

### Option 1: Use the Deployment Script (Recommended)

```shell
# From your Mac
~/code/isaackehle/iac/scripts/deploy-simple-portainer.sh
```

This will:

1. Create the stack directory on Synology
2. Copy the docker-compose.yml
3. Deploy Portainer via SSH

### Option 2: Manual Deployment via SSH

```shell
# SSH into Synology
ssh isaac@voyager.tail303fda.ts.net

# Create directory
mkdir -p /volume1/docker/stacks/portainer-simple

# Copy docker-compose.yml from your Mac
scp ~/code/isaackehle/iac/portainer/simple/docker-compose.yml isaac@voyager.tail303fda.ts.net:/volume1/docker/stacks/portainer-simple/

# Deploy
cd /volume1/docker/stacks/portainer-simple
sudo /var/packages/ContainerManager/target/tool/docker compose up -d

# Check status
sudo /var/packages/ContainerManager/target/tool/docker ps
```

### Option 3: Deploy via Synology Container Manager UI

1. Open **Container Manager** in DSM
2. Go to **Project** tab
3. Click **Create** → **Project**
4. Choose **Import from YAML/JSON**
5. Copy the content from `~/code/isaackehle/iac/portainer/simple/docker-compose.yml`
6. Click **Apply**

## Access Portainer

Once deployed, access Portainer at:

- **URL**: `http://voyager.tail303fda.ts.net:9000`
- **First-time setup**: Create admin user (username/password)

## Next Steps After Portainer is Running

1. **Deploy Synology MCP Server**:
   - Go to Portainer → Stacks → Add stack
   - Use `~/code/isaackehle/iac/synology-mcp/docker-compose.yml`
   - Select the `.env` file with your credentials
   - Deploy

2. **Verify MCP Server**:
   - Check container logs: `docker compose logs synology-mcp`
   - Test Web API connectivity

## Troubleshooting

### Portainer Won't Start

```shell
# Check logs
ssh isaac@voyager.tail303fda.ts.net "sudo /var/packages/ContainerManager/target/tool/docker logs portainer"

# Check if port 9000 is open
nc -zv voyager.tail303fda.ts.net 9000
```

### Web API Error 101

The Synology Web API HTTP endpoint returns error 101. This is a DSM 7.3.2 limitation.

**Solution**: The MCP server will work via the Docker MCP implementation once deployed.

### Tailscale Certificate Issue

The Tailscale certificate was generated but nginx needs restart to activate it.

**Current status**: Certificate files are in `/usr/syno/etc/certificate/_archive/emdbz8/`

## Files Reference

- Simple Portainer compose: `~/code/isaackehle/iac/portainer/simple/docker-compose.yml`
- MCP server stack: `~/code/isaackehle/iac/synology-mcp/docker-compose.yml`
- MCP credentials: `~/code/isaackehle/iac/synology-mcp/.env`
- Deployment script: `~/code/isaackehle/iac/scripts/deploy-simple-portainer.sh`

## Alternative: Restore Tailscale Sidecar

If you want Portainer with Tailscale integration:

1. Fix the Tailscale auth key in the `.env` file
2. Ensure the `ts-portainer` container can start
3. The Tailscale device needs to be online for the sidecar to work

See `~/code/isaackehle/iac/portainer/old/compose.yaml` for the full Tailscale-enabled configuration.
