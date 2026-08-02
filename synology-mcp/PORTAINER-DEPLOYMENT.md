# Deploy Portainer on Synology NAS

## Current Status

- ✅ Container Manager package installed on Synology
- ✅ Portainer stack directory exists at `/volume1/docker/stacks/portainer/old/`
- ❌ Portainer container is offline (not running)
- ❌ Tailscale device `portainer` is offline

## Option 1: Deploy via Synology Container Manager UI (Recommended)

### Step 1: Access Container Manager

1. Open DSM web interface: `http://voyager.tail303fda.ts.net:5000` or `http://192.168.68.78:5000`
2. Login with your credentials
3. Open **Container Manager** from the main menu
4. Go to **Project** tab

### Step 2: Create Portainer Project

1. Click **Create** → **Project**
2. Choose **Import from YAML/JSON**
3. Copy the compose.yaml from `~/code/isaackehle/iac/portainer/old/compose.yaml`
4. Set the working directory to `/volume1/docker/stacks/portainer/old`
5. Click **Next**

### Step 3: Configure Environment Variables

Create a `.env` file with:

```bash
TS_AUTHKEY=tskey-auth-kvViEukri721CNTRL-6WuqT3p75ZZE92qTaV2dYZ2TxeaEENmZe
TS_CERT_DOMAIN=portainer.tail303fda.ts.net
TS_HOSTNAME_PORTAINER=portainer
```

### Step 4: Deploy

1. Click **Apply** to deploy the project
2. Wait for the containers to start
3. Check status in the **Project** tab

### Step 5: Verify Deployment

1. Check that both `ts-portainer` and `portainer` containers are running
2. Verify Tailscale device is online: `tailscale status`
3. Access Portainer at:
   - `http://voyager.tail303fda.ts.net:9000`
   - `https://portainer.tail303fda.ts.net:8000` (via Tailscale serve)

## Option 2: Deploy via SSH

### Step 1: Copy Files

```bash
# SSH into Synology
ssh isaac@voyager.tail303fda.ts.net

# Create directory
mkdir -p /volume1/docker/stacks/portainer/old

# Copy compose.yaml from your Mac
scp ~/code/isaackehle/iac/portainer/old/compose.yaml isaac@voyager.tail303fda.ts.net:/volume1/docker/stacks/portainer/old/

# Copy serve.json
scp ~/code/isaackehle/iac/portainer/serve.json.tmpl isaac@voyager.tail303fda.ts.net:/volume1/docker/stacks/portainer/old/serve.json

# Create .env file
cat > /volume1/docker/stacks/portainer/old/.env << 'EOF'
TS_AUTHKEY=tskey-auth-kvViEukri721CNTRL-6WuqT3p75ZZE92qTaV2dYZ2TxeaEENmZe
TS_CERT_DOMAIN=portainer.tail303fda.ts.net
TS_HOSTNAME_PORTAINER=portainer
EOF
```

### Step 2: Deploy

```bash
# Deploy the stack
cd /volume1/docker/stacks/portainer/old
docker compose -f compose.yaml up -d

# Check status
docker compose ps
```

## Option 3: Deploy Portainer Without Tailscale Sidecar

If you just want Portainer without Tailscale integration:

### Step 1: Create Simple Portainer Stack

```bash
# Create directory
mkdir -p /volume1/docker/stacks/portainer-simple

# Create docker-compose.yml
cat > /volume1/docker/stacks/portainer-simple/docker-compose.yml << 'EOF'
version: "3.8"

services:
  portainer:
    image: portainer/portainer-ce:latest
    container_name: portainer
    restart: always
    ports:
      - "9000:9000"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - /volume1/docker/portainer-data:/data
EOF

# Deploy
cd /volume1/docker/stacks/portainer-simple
docker compose up -d
```

### Step 2: Access Portainer

- Navigate to: `http://voyager.tail303fda.ts.net:9000`
- Complete initial setup
- You now have Portainer running!

## Verify Portainer is Running

```bash
# Check containers
ssh isaac@voyager.tail303fda.ts.net "docker ps | grep portainer"

# Check Tailscale status
ssh isaac@voyager.tail303fda.ts.net "tailscale status"

# Test Portainer access
curl -skL http://voyager.tail303fda.ts.net:9000
```

## Next Steps After Portainer is Running

1. **Deploy Synology MCP Server**:
   - Go to Portainer UI
   - Select your Docker environment
   - Create a new stack from `~/code/isaackehle/iac/synology-mcp/docker-compose.yml`

2. **Verify MCP Server**:
   - Check container logs: `docker compose logs synology-mcp`
   - Test Web API connectivity

## Troubleshooting

### Portainer Container Won't Start

1. Check logs: `docker compose logs portainer`
2. Verify Docker socket is accessible
3. Check disk space: `df -h`

### Tailscale Device Offline

1. Check Tailscale service: `systemctl status tailscaled`
2. Restart Tailscale: `sudo systemctl restart tailscaled`
3. Re-authenticate: `sudo tailscale up`

### Portainer Not Accessible

1. Check if port 9000 is open: `nc -zv voyager.tail303fda.ts.net 9000`
2. Verify container is running: `docker ps | grep portainer`
3. Check network configuration

## Files Reference

- Compose file: `~/code/isaackehle/iac/portainer/old/compose.yaml`
- MCP stack: `~/code/isaackehle/iac/synology-mcp/docker-compose.yml`
- MCP credentials: `~/code/isaackehle/iac/synology-mcp/.env`
