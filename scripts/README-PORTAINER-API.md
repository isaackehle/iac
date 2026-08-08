# Portainer API Deployment

Deploy stacks to Synology NAS via Portainer API with automatic GitOps pull from GitHub.

## Overview

Instead of using SSH/scp to push files to the NAS, this approach:

1. Creates a **GitOps stack** in Portainer
2. Portainer pulls `docker-compose.yml` directly from GitHub
3. Portainer starts the stack automatically
4. Updates are automatic when you push to GitHub

## Setup

### 1. Create Portainer API Key

```bash
./scripts/portainer-api-key.sh
```

This opens Portainer in your browser. Navigate to:

- Your username (top right) → **API keys**
- Click **Create API key**
- Name: `iac-deploy`
- Expiry: `365 days`
- Copy the generated key (starts with `pt-...`)

Set the environment variables:

```bash
export PORTAINER_URL="https://portainer.tail303fda.ts.net"
export PORTAINER_API_KEY="pt-your-api-key-here"
```

### 2. Deploy a Stack

```bash
./scripts/deploy-to-portainer.sh langfuse nas
```

This will:

1. Generate `.env` from `iac-secrets.env`
2. Create a GitOps stack in Portainer
3. Configure Portainer to pull from GitHub
4. Start the stack

### 3. Verify Deployment

Check Portainer UI or run:

```bash
curl -s -H "X-Api-Key: $PORTAINER_API_KEY" \
  "$PORTAINER_URL/api/stacks?name=langfuse" | jq .
```

## How It Works

### GitOps Configuration

The script creates a stack with this GitOps configuration:

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
- Pulls `docker-compose.yml` automatically (default every 15 minutes)
- Starts the stack when it detects changes
- No manual file pushes needed

### Environment Variables

Portainer handles environment variables via the `.env` file:

- The script generates `.env` locally from `iac-secrets.env`
- Portainer reads it when creating the stack
- Secrets are injected into containers at runtime

## Updating Stacks

### Option 1: GitOps (Automatic)

Just push changes to GitHub:

```bash
cd ~/code/isaackehle/iac
# Make changes to langfuse/docker-compose.yml
git add langfuse/
git commit -m "feat(langfuse): update config"
git push
```

Portainer will detect the change and redeploy automatically (within 15 minutes).

### Option 2: Manual Trigger

In Portainer UI:

- Navigate to the stack
- Click **Pull latest**
- Click **Restart**

Or via API:

```bash
stack_id=$(curl -s -H "X-Api-Key: $PORTAINER_API_KEY" \
  "$PORTAINER_URL/api/stacks?name=langfuse" | jq -r '.[0].Id')

curl -s -X POST -H "X-Api-Key: $PORTAINER_API_KEY" \
  "$PORTAINER_URL/api/stacks/$stack_id/pull"
```

## Pitfalls

### 1. API Key Permissions

Ensure the API key has sufficient permissions:

- **Admin** role: Full access to all stacks
- **Stack** role: Can manage stacks only

### 2. GitOps Polling Interval

Portainer polls GitHub every 15 minutes by default. To change:

- Portainer UI → Settings → Docker → Git polling interval
- Or create stack with custom `PollingInterval` in GitConfig

### 3. Environment Variable Injection

Portainer's GitOps mode doesn't automatically inject `.env` files. You have two options:

**Option A: Use Portainer's environment variable UI**

- After creating the stack, edit it in Portainer UI
- Add environment variables manually

**Option B: Hardcode in docker-compose.yml**

- Use `${VAR}` syntax in `docker-compose.yml`
- Set variables in Portainer's stack environment

**Option C: Use Portainer's env_file feature**

- Upload `.env` file to GitHub in the stack folder
- Reference it in `docker-compose.yml`: `env_file: .env`

### 4. Sidecar Stacks

Sidecar stacks (like langfuse) have special requirements:

- All services must be in the same stack
- `network_mode: service:tailscale` requires all containers in same Compose file
- Ensure `docker-compose.yml` includes all dependencies (clickhouse, redis, minio, etc.)

### 5. Port Conflicts

Published ports must not conflict with existing stacks:

- Check: `ssh nas "docker ps --format '{{.Ports}}'"`
- Common conflicts: 9000 (Portainer), 8444 (Caddy), 443 (HTTPS)

## Alternative: SSH Deploy

If Portainer API is unavailable, use SSH:

```bash
cd ~/code/isaackehle/iac
./scripts/gen-env.sh langfuse
./scripts/deploy.sh all langfuse nas
```

This uses `scp -O` (legacy SCP) which works reliably with Synology DSM.

## Troubleshooting

### Stack not starting

1. Check Portainer logs:

```bash
curl -s -H "X-Api-Key: $PORTA...KEY" \
  "$PORTAINER_URL/api/stacks?name=langfuse" | jq '.[0].Env'
```

2. Check container logs on NAS:

```bash
ssh nas "docker logs langfuse-tailscale --tail 50"
```

3. Verify secrets are set:

```bash
grep -E '(LANGFUSE_DB_PASSWORD|CLICKHOUSE_PASSWORD)' langfuse/.env
```

### GitOps not pulling

1. Check Portainer's Git config:

```bash
curl -s -H "X-Api-Key: $PORTA...KEY" \
  "$PORTAINER_URL/api/stacks?name=langfuse" | jq '.[0].GitConfig'
```

2. Test GitHub access from NAS:

```bash
ssh nas "curl -sI https://raw.githubusercontent.com/isaackehle/iac/main/langfuse/docker-compose.yml"
```

3. Check Portainer's polling logs:

```bash
ssh nas "docker logs portainer --tail 100 | grep -i git"
```

### API key issues

If you get "Unauthorized" errors:

1. Verify API key format: `pt-...`
2. Check key hasn't expired
3. Ensure key has correct permissions
4. Try regenerating the key

## Next Steps

- Deploy remaining stacks via Portainer API
- Set up GitOps polling for automatic updates
- Configure alerts for failed deployments
- Back up Portainer database (`/volume1/docker/stacks/portainer/data/`)
