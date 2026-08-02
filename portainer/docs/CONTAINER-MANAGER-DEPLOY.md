# Deploy Portainer via Container Manager UI

## Goal

Deploy Portainer using Container Manager's Project feature with the YAML from the IAC repo.

## Current State

- `/volume1/docker/stacks/portainer/` - Exists with `.env`, `data/`, `ts-config/`, `ts-state/`
- `/volume1/docker/portainer/compose/` - **GONE** (cleaned up)
- Portainer container exists but is **exited** (missing Tailscale sidecar)
- IAC config lives only in: `~/code/isaackehle/iac/portainer/old/compose.yaml` (on your Mac)

## Step 1: Get the YAML File

Copy the Portainer compose file from the IAC repo to the NAS:

```shell
# Option A: Copy directly via SSH
scp ~/code/isaackehle/iac/portainer/old/compose.yaml isaac@voyager.tail303fda.ts.net:/volume1/docker/stacks/portainer/

# Option B: Create file directly on NAS
ssh isaac@voyager.tail303fda.ts.net "cat > /volume1/docker/stacks/portainer/docker-compose.yml << 'EOF'
version: "3.8"

services:
  ts-portainer:
    image: tailscale/tailscale:latest
    container_name: ts-portainer
    restart: unless-stopped
    hostname: portainer
    environment:
      - TS_HOSTNAME=${TS_HOSTNAME_PORTAINER:-portainer}
      - TS_AUTHKEY=${TS_AUTHKEY}
      - TS_STATE_DIR=/var/lib/tailscale
      - TS_AUTH_ONCE=false
      - TS_SERVE_CONFIG=/config/serve.json
    volumes:
      - /volume1/docker/portainer/ts-state:/var/lib/tailscale
      - /volume1/docker/stacks/portainer/ts-config:/config
    devices:
      - /dev/net/tun:/dev/net/tun
    cap_add:
      - NET_ADMIN
      - SYS_MODULE
      - NET_RAW
    ports:
      - "19443:9443"
      - "9000:9000"
      - "8000:8000"
    networks:
      - portainer_net

  portainer:
    image: portainer/portainer-ce:latest
    container_name: portainer
    restart: always
    security_opt:
      - no-new-privileges:true
    network_mode: service:ts-portainer
    depends_on:
      - ts-portainer
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - /volume1/docker/portainer:/data

networks:
  portainer_net:
    driver: bridge

volumes:
  ts-portainer-proxy-data:
EOF
"
```

## Step 2: Verify .env File

Ensure `/volume1/docker/stacks/portainer/.env` exists with:

```shell
TS_AUTHKEY=tskey-auth-xxxx
TS_CERT_DOMAIN=portainer.tail303fda.ts.net
TS_HOSTNAME_PORTAINER=portainer
```

## Step 3: Deploy via Container Manager UI

1. **Open Container Manager**
   - DSM → Container Manager → **Project** tab

2. **Create New Project**
   - Click **Create** → **Project**
   - Choose **Import from YAML/JSON**

3. **Paste YAML Content**
   - Copy the content from `/volume1/docker/stacks/portainer/docker-compose.yml`
   - Paste into the YAML editor

4. **Configure Environment**
   - Click **Next**
   - Select **Use existing .env file**
   - Browse to: `/volume1/docker/stacks/portainer/.env`

5. **Deploy**
   - Click **Apply**
   - Wait for both containers to start

## Step 4: Verify Deployment

```shell
# Check container status
ssh isaac@voyager.tail303fda.ts.net "sudo /var/packages/ContainerManager/target/tool/docker ps | grep portainer"

# Check Tailscale status
ssh isaac@voyager.tail303fda.ts.net "tailscale status"

# Access Portainer
# http://voyager.tail303fda.ts.net:9000
```

## Notes

- **YAML file location**: `/volume1/docker/stacks/portainer/docker-compose.yml`
- **Environment file**: `/volume1/docker/stacks/portainer/.env`
- **Data location**: `/volume1/docker/portainer/` (unchanged)
- **Tailscale state**: `/volume1/docker/stacks/portainer/ts-state/`
- **Tailscale config**: `/volume1/docker/stacks/portainer/ts-config/`

## Next Steps

Once Portainer is running:

1. Access Portainer at `http://voyager.tail303fda.ts.net:9000`
2. Deploy MCP server via Portainer → Stacks → Add stack
3. Use `~/code/isaackehle/iac/synology-mcp/docker-compose.yml`
