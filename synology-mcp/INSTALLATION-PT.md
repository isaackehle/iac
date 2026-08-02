# Deploy Synology MCP Server via Portainer

Deploy the Synology MCP server using Portainer UI on your Synology NAS.

## Prerequisites

- Portainer connected to your Synology NAS Docker environment
- Tailscale network configured on Synology (`voyager.tail303fda.ts.net`)
- Web API enabled on Synology (see `~/sync/plans/004_synology-web-api-enable.md`)
- Credentials in 1Password: `dev-synology`

## Option A: Portainer Already Deployed

If Portainer is already running, skip to **Step 3**.

## Step 1: Deploy Portainer (If Not Already Done)

### Via Container Manager UI

1. Open DSM web interface: `http://voyager.tail303fda.ts.net:5000`
2. Open **Container Manager**
3. Go to **Project** tab
4. Click **Create** → **Project**
5. Choose **Import from YAML/JSON**
6. Use compose file from `~/code/isaackehle/iac/portainer/old/compose.yaml`
7. Set working directory to `/volume1/docker/stacks/portainer/old`

### Via SSH (Alternative)

```shell
ssh isaac@voyager.tail303fda.ts.net

# Create directory
mkdir -p /volume1/docker/stacks/portainer/old

# Copy compose.yaml from your Mac
scp ~/code/isaackehle/iac/portainer/old/compose.yaml \
  isaac@voyager.tail303fda.ts.net:/volume1/docker/stacks/portainer/old/

# Create .env file
cat > /volume1/docker/stacks/portainer/old/.env << 'EOF'
TS_AUTHKEY=tskey-auth-kvViEukri721CNTRL-6WuqT3p75ZZE92qTaV2dYZ2TxeaEENmZe
TS_CERT_DOMAIN=portainer.tail303fda.ts.net
TS_HOSTNAME_PORTAINER=portainer
EOF

# Deploy
cd /volume1/docker/stacks/portainer/old
docker compose -f compose.yaml up -d
```

### Step 2: Verify Portainer is Running

```shell
# Check containers
ssh isaac@voyager.tail303fda.ts.net "docker ps | grep portainer"

# Check Tailscale status
ssh isaac@voyager.tail303fda.ts.net "tailscale status"

# Test Portainer access
curl -skL http://voyager.tail303fda.ts.net:9000
```

## Step 3: Deploy MCP Server via Portainer UI

1. Log into Portainer at `http://voyager.tail303fda.ts.net:9000`

2. Select your Docker environment (Synology NAS)

3. Click **Stacks** → **Add stack**

4. Choose **Web editor**

5. Copy contents of `docker-compose.yml` from this directory

6. Set **Working directory** to `/volume1/docker/stacks/synology-mcp`

7. Click **Load from file** and select `.env` (create it first)

8. Click **Deploy the stack**

## Step 4: Verify Deployment

Via SSH:

```shell
ssh isaac@voyager.tail303fda.ts.net

# Check container status
cd /volume1/docker/stacks/synology-mcp
docker compose ps

# View logs
docker compose logs synology-mcp

# Check if container is running
docker ps | grep synology-mcp
```

## Environment Variables

Required variables in `.env`:

| Variable | Description | Required |
|----------|-------------|----------|
| `SYNOLOGY_HOST` | Synology hostname (Tailscale or local IP) | Yes |
| `SYNOLOGY_PORT` | DSM port (5000 or 5001) | Yes |
| `SYNOLOGY_SSL` | Use HTTPS (true/false) | Yes |
| `SYNOLOGY_USERNAME` | DSM username | Yes |
| `SYNOLOGY_PASSWORD` | DSM password | Yes |
| `SYNOLOGY_OTP_CODE` | 2FA OTP code (if enabled) | Optional |

## Testing the MCP Server

Test the connection via the MCP inspector:

```shell
npx @modelcontextprotocol/inspector npx -y @modelcontextprotocol/servers/synology
```

Or test the Web API directly:

```shell
curl -skL https://voyager.tail303fda.ts.net:5001/webapi/entry.cgi?api=SYNO.API.Info&method=query&version=1
```

## Updates

To update the MCP server:

```shell
ssh isaac@voyager.tail303fda.ts.net
cd /volume1/docker/stacks/synology-mcp
docker compose pull
docker compose up -d
```

## Troubleshooting

### Web API returns error 101

The Synology Web API HTTP endpoint may be disabled. Enable it via SSH:

```shell
sudo /usr/syno/bin/synowebapi --enable-lib SYNO.API.Info.lib SYNO.API.Auth.lib SYNO.Entry.Request.lib
```

See `~/sync/plans/004_synology-web-api-enable.md` for more details.

### Certificate errors

If you see certificate errors, ensure you're using the Tailscale certificate:

1. Generate:

   ```shell
   sudo /var/packages/Tailscale*/target/bin/tailscale cert \
     --cert-file=/tmp/voyager.crt \
     --key-file=/tmp/voyager.key \
     voyager.tail303fda.ts.net
   ```

2. Copy to: `/usr/syno/etc/certificate/_archive/<ID>/`

3. Restart nginx:

   ```shell
   sudo /usr/bin/nginx -s reload
   ```

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
