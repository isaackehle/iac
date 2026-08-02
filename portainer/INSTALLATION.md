# Portainer Server Installation

> **Recommended**: Deploy via Synology Container Manager UI — one-click import from YAML with `.env` binding.
> The manual steps below are the equivalent broken out for troubleshooting or automation.

Deploy the Portainer server stack itself via Synology Container Manager. This is the only stack that requires Container Manager (not Portainer UI) because
you're bootstrapping Portainer itself.

## Prerequisites

- Synology NAS with Container Manager installed
- Tailscale network configured on target machine
- Tailscale auth key for device registration (`tskey-...`)
- SSH access or File Station access to Synology NAS

## Directory Setup (on Synology NAS)

```shell
# On voyager (or target NAS)
STACK_PATH="/volume1/docker/stacks/portainer"

# Create IAC-style directory structure
mkdir -p $STACK_PATH/{data/compose/10,portainer-secrets,ts-config,ts-state}

# Create secure secrets directory (700, root:root)
mkdir -p $STACK_PATH/portainer-secrets/{certs,chisel}
chmod 700 $STACK_PATH/portainer-secrets
chown root:root $STACK_PATH/portainer-secrets

# Place certificates and chisel key in secure location
# cert.pem and key.pem go into certs/
# private-key.pem goes into chisel/
chmod 600 $STACK_PATH/portainer-secrets/certs/* $STACK_PATH/portainer-secrets/chisel/*
chown root:root $STACK_PATH/portainer-secrets/certs/* $STACK_PATH/portainer-secrets/chisel/*
```

## Environment File

Create `/volume1/docker/stacks/portainer/.env`:

```shell
# Tailscale configuration
TS_HOSTNAME_PORTAINER=portainer
TS_AUTHKEY=tskey-your-auth-key-here

# Optional: custom domain for HTTPS routing
# TS_CERT_DOMAIN=portainer.your-tailnet.ts.net
```

Generate the auth key from Tailscale console: <https://login.tailscale.com/admin/machines>

## Deployment via Container Manager UI

### Step 1: Get the Compose YAML

Copy the compose file from your IAC repo:

```shell
# On your Mac
cat ~/code/isaackehle/iac/portainer/old/compose.yaml
```

Or SSH to NAS and copy from the IAC repo stored on disk:

```shell
# On NAS
cat /volume1/docker/stacks/portainer/data/compose/10/portainer/docker-compose.yml
```

### Step 2: Import into Container Manager

1. **Open Container Manager** → **Project** tab
2. Click **Create** → **Project**
3. Choose **Import from YAML/JSON**
4. Paste the entire compose.yaml content into the YAML editor

### Step 3: Configure Environment

1. Click **Next**
2. Select **Use existing .env file**
3. Browse to: `/volume1/docker/stacks/portainer/.env`
4. Click **Apply**

### Step 4: Wait for Deployment

Container Manager will deploy two containers:

- `ts-portainer` - Tailscale sidecar proxy
- `portainer` - Portainer CE server (attached to Tailscale network)

Wait 30-60 seconds for both to start.

## Verification

### Check Container Status

```shell
sudo /var/packages/ContainerManager/target/tool/docker ps | grep portainer
```

Expected output:

```text
ts-portainer       tailscale/tailscale:latest      "start.sh"             Up       portainer_net
portainer          portainer/portainer-ce:latest   "/run.sh"              Up       portainer_net
```

### Check Tailscale Status

```shell
sudo /var/packages/ContainerManager/target/tool/docker exec ts-portainer tailscale status
```

You should see `portainer` listed as online with a Tailscale IP.

### Access Portainer

Open in browser:

- **Tailscale URL**: `http://voyager.tail303fda.ts.net:9000`
- **Local URL**: `http://voyager.local:9000` (if on local network)

On first launch, you'll be prompted to:

1. Create admin user (username/password)
2. Connect Portainer to external environments (optional)

## Serving via Tailscale HTTPS

After initial setup, Tailscale's HTTP proxy routes traffic through your custom domain:

1. **Render serve.json** from template:

   ```shell
   # On NAS
   /volume1/docker/stacks/portainer/data/compose/10/scripts/gen-env.sh portainer > /volume1/docker/stacks/portainer/ts-config/serve.json
   ```

2. **Restart the Tailscale sidecar** to pick up the config:

   ```shell
   sudo /var/packages/ContainerManager/target/tool/docker restart ts-portainer
   ```

3. **Access via HTTPS**:

   ```text
   https://portainer.your-tailnet.ts.net
   ```

The `serve.json.tmpl` renders:

```json
{
  "Web": {
    "portainer.your-tailnet.ts.net:443": {
      "Handlers": {
        "/": {
          "Proxy": "http://127.0.0.1:9000"
        }
      }
    }
  }
}
```

## Updates

### Via Container Manager UI

1. Open Container Manager → **Project** tab
2. Select the `portainer` project
3. Click **Update** → **Edit**
4. Make changes to compose YAML or `.env`
5. Click **Apply**

### Via CLI

```shell
cd /volume1/docker/stacks/portainer
sudo /var/packages/ContainerManager/target/tool/docker compose pull
sudo /var/packages/ContainerManager/target/tool/docker compose up -d
```

## Troubleshooting

### Container Won't Start

Check logs:

```shell
sudo /var/packages/ContainerManager/target/tool/docker logs ts-portainer
sudo /var/packages/ContainerManager/target/tool/docker logs portainer
```

Common issues:

- **TS_AUTHKEY invalid**: Generate new key from Tailscale console
- **Port already in use**: Check if 9000/19443/8000 are occupied
- **Tailscale not connecting**: Verify `/dev/net/tun` device exists

### Tailscale Not Online

```shell
# Check Tailscale auth
sudo /var/packages/ContainerManager/target/tool/docker exec ts-portainer tailscale status

# Restart Tailscale sidecar
sudo /var/packages/ContainerManager/target/tool/docker restart ts-portainer

# Re-authenticate if needed
sudo /var/packages/ContainerManager/target/tool/docker exec -it ts-portainer tailscale up
```

### Portainer Not Accessible

1. Verify container is running: `docker ps | grep portainer`
2. Check port bindings: `docker port portainer`
3. Test from local machine: `curl http://voyager.local:9000`
4. Check Tailscale IP: `tailscale ip`

## Files Reference

**IAC Repo:**

- Compose YAML: `~/code/isaackehle/iac/portainer/old/compose.yaml`
- serve.json template: `~/code/isaackehle/iac/portainer/old/serve.json.tmpl`
- gen-env script: `~/code/isaackehle/iac/portainer/old/scripts/gen-env.sh`

**NAS Files:**

- `.env`: `/volume1/docker/stacks/portainer/.env`
- Compose YAML: `/volume1/docker/stacks/portainer/docker-compose.yml` (after deployment)
- serve.json: `/volume1/docker/stacks/portainer/ts-config/serve.json`
- Secure secrets: `/volume1/docker/portainer-secrets/`
- Portainer data: `/volume1/docker/portainer/`

**IAC Repo (on NAS):**

- Source of truth: `/volume1/docker/stacks/portainer/data/compose/10/`
- Portainer compose: `/volume1/docker/stacks/portainer/data/compose/10/portainer/docker-compose.yml`
- Scripts: `/volume1/docker/stacks/portainer/data/compose/10/scripts/`

## Next Steps

After Portainer is running:

1. **Deploy Synology MCP Server** via Portainer UI
   - See `~/code/isaackehle/iac/synology-mcp/INSTALLATION.md`

2. **Deploy other stacks** via Portainer UI
   - Home Assistant, Frigate, n8n, Nextcloud, etc.

3. **Configure backups** for Portainer data
   - `/volume1/docker/portainer/` contains all Portainer configuration
