# Deploy Synology MCP Server via Container Manager

> **⚠️ Important:** Stacks deployed via Container Manager are marked as **"Limited"** in Portainer and **cannot** be deployed via the Portainer API.
>
> If you need to use Portainer API deployment (GitOps), you must first remove the Container Manager project and redeploy using SSH:
>
> ```bash
> # Remove Container Manager project first
> ssh isaac@nas.tail303fda.ts.net "docker compose -f /volume1/docker/stacks/synology-mcp/docker-compose.yml down"
> 
> # Then deploy via SSH
> cd ~/code/isaackehle/iac
> ./scripts/gen-env.sh synology-mcp
> ./scripts/deploy.sh all synology-mcp nas
> ```

Deploy the Synology MCP server using Synology's Container Manager UI.

## Prerequisites

- Container Manager package installed on Synology
- Tailscale network configured on Synology (`nas.tail303fda.ts.net`)
- Web API enabled on Synology (see `~/sync/plans/004_synology-web-api-enable.md`)
- Credentials in 1Password: `dev-synology`

## Step 1: Prepare Local Files

On your Mac, ensure you have these files ready:

```shell
cd ~/code/isaackehle/iac/synology-mcp
ls -la docker-compose.yml .env .env.example
```

## Step 2: Create Stack Directory on Synology

Via SSH:

```shell
ssh isaac@nas.tail303fda.ts.net
mkdir -p /volume1/docker/stacks/synology-mcp/config
exit
```

## Step 3: Copy Files to Synology

```shell
cd ~/code/isaackehle/iac/synology-mcp

# Copy docker-compose.yml
scp docker-compose.yml isaac@nas.tail303fda.ts.net:/volume1/docker/stacks/synology-mcp/

# Copy .env (create it first if needed)
cp .env.example .env
# Edit .env with your credentials
nano .env
scp .env isaac@nas.tail303fda.ts.net:/volume1/docker/stacks/synology-mcp/

# Copy config directory contents
scp -r config/ isaac@nas.tail303fda.ts.net:/volume1/docker/stacks/synology-mcp/config/
```

## Step 4: Deploy via Container Manager UI

1. Open DSM web interface:
   - `http://nas.tail303fda.ts.net:5000` or
   - `http://192.168.68.78:5000`

2. Login with your credentials

3. Open **Container Manager** from the main menu

4. Go to **Project** tab

5. Click **Create** → **Project**

6. Choose **Import from YAML/JSON**

7. Copy contents of `docker-compose.yml` from this directory

8. Set the working directory to `/volume1/docker/stacks/synology-mcp`

9. Click **Next**

10. Click **Apply** to deploy the project

11. Wait for the containers to start

12. Check status in the **Project** tab

## Step 5: Verify Deployment

Via SSH:

```shell
ssh isaac@nas.tail303fda.ts.net

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
curl -skL https://nas.tail303fda.ts.net:5001/webapi/entry.cgi?api=SYNO.API.Info&method=query&version=1
```

## Updates

To update the MCP server:

```shell
ssh isaac@nas.tail303fda.ts.net
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
     --cert-file=/tmp/nas.crt \
     --key-file=/tmp/nas.key \
     nas.tail303fda.ts.net
   ```

2. Copy to: `/usr/syno/etc/certificate/_archive/<ID>/`

3. Restart nginx:

   ```shell
   sudo /usr/bin/nginx -s reload
   ```

### Container won't start

1. Check logs: `docker compose logs synology-mcp`
2. Verify Docker socket is accessible
3. Check disk space: `df -h`
4. Verify environment variables are correct
