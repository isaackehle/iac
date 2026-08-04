# Portainer API Deployment

Deploy stacks to Synology NAS via Portainer API with automatic GitOps pull from GitHub.

## What This Does

Instead of using SSH/scp to push files to the NAS:

1. Creates a **GitOps stack** in Portainer
2. Portainer pulls `docker-compose.yml` directly from GitHub
3. Portainer starts the stack automatically
4. Updates are automatic when you push to GitHub

## Setup

### 1. Create Portainer API Key

Run the helper script:

```bash
./scripts/portainer-api-key.sh
```

This opens Portainer in your browser. Then:

1. Navigate to your username (top right) → **API keys**
2. Click **Create API key**
3. Name: `iac-deploy`
4. Expiry: `365 days`
5. Copy the generated key (starts with `pt-...`)

Set environment variables:

```bash
export PORTAINER_URL="https://portainer.tail303fda.ts.net"
export PORTAINER_API_KEY="pt-your-api-key-here"
```

### 2. Deploy a Stack

```bash
./scripts/deploy-to-portainer.sh langfuse voyager
```

This will:

1. Generate `.env` from `iac-secrets.env`
2. Create a GitOps stack in Portainer
3. Inject environment variables
4. Start the stack

### 3. Verify Deployment

```bash
curl -s -H "X-Api-Key: $PORTAINER_API_KEY" \
  "$PORTAINER_URL/api/stacks?name=langfuse" | jq .
```

## How GitOps Works

The script creates a stack with this configuration:

```json
{
  "GitConfig": {
    "URL": "https://github.com/isaackehle/iac.git",
    "SubFolder": "langfuse",
    "Branch": "main",
    "Autoload": true
  }
}
```

This means:

- Portainer watches the `langfuse/` folder in your repo
- Pulls `docker-compose.yml` automatically (every 15 minutes by default)
- Starts the stack when it detects changes
- No manual file pushes needed

## Updating Stacks

### Option 1: GitOps (Automatic)

Just push changes to GitHub:

```bash
cd ~/code/isaackehle/iac
# Make changes
git add langfuse/
git commit -m "feat(langfuse): update config"
git push
```

Portainer will detect and redeploy automatically (within 15 minutes).

### Option 2: Manual Trigger

In Portainer UI:

- Navigate to the stack
- Click **Pull latest**
- Click **Restart**

## Files Created

1. **`scripts/deploy-to-portainer.sh`** - Main deployment script
2. **`scripts/portainer-api-key.sh`** - Helper to open Portainer and get API key
3. **`scripts/README-PORTAINER-API.md`** - Detailed documentation
4. **`PORTAINER-DEPLOYMENT.md`** - This file

## Pitfalls

### 1. API Key Permissions

Ensure the API key has **Admin** or **Stack** permissions.

### 2. GitOps Polling Interval

Portainer polls GitHub every 15 minutes by default. Change in:

- Portainer UI → Settings → Docker → Git polling interval

### 3. Environment Variables

The script injects `.env` variables directly into the stack API call, so they're available at runtime.

### 4. Sidecar Stacks

Sidecar stacks (like langfuse) must include all dependencies in one `docker-compose.yml`:

- `langfuse` + `worker` + `tailscale-sidecar` + `clickhouse` + `redis` + `minio`

## Troubleshooting

### Stack not starting

1. Check Portainer logs:

   ```bash
   curl -s -H "X-Api-Key: $PORTAINER_API_KEY" \
     "$PORTAINER_URL/api/stacks?name=langfuse" | jq '.[0].Env'
   ```

2. Check container logs:

   ```bash
   ssh voyager "docker logs ts-langfuse --tail 50"
   ```

3. Verify secrets are set:

   ```bash
   grep -E '(LANGFUSE_DB_PASSWORD|CLICKHOUSE_PASSWORD)' langfuse/.env
   ```

### GitOps not pulling

1. Check Portainer's Git config:

   ```bash
   curl -s -H "X-Api-Key: $PORTAINER_API_KEY" \
     "$PORTAINER_URL/api/stacks?name=langfuse" | jq '.[0].GitConfig'
   ```

2. Test GitHub access:

   ```bash
   ssh voyager "curl -sI https://raw.githubusercontent.com/isaackehle/iac/main/langfuse/docker-compose.yml"
   ```

### API key issues

If you get "Unauthorized" errors:

1. Verify API key format: `pt-...`
2. Check key hasn't expired
3. Ensure key has correct permissions
4. Try regenerating the key

## Alternative: SSH Deploy

If Portainer API is unavailable:

```bash
cd ~/code/isaackehle/iac
./scripts/gen-env.sh langfuse
./scripts/deploy.sh all langfuse voyager
```

This uses `scp -O` (legacy SCP) which works reliably with Synology DSM.

## Next Steps

- Deploy remaining stacks via Portainer API
- Set up GitOps polling for automatic updates
- Configure alerts for failed deployments
- Back up Portainer database (`/volume1/docker/stacks/portainer/data/`)
