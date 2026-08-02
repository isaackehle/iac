# Portainer .env Fix

## Problem
The original docker-compose.yml was missing the `env_file` directive, which meant Portainer couldn't load the `.env` file automatically.

## Solution
Added `env_file` directive to the `portainer` service:

```yaml
services:
  portainer:
    # ... other config ...
    
    # ── Environment ───────────────────────────────────────────
    env_file:
      - /volume1/docker/stacks/portainer/.env
```

## Deployment Status
✅ Committed to GitHub (commit 6b8d725)
✅ Portainer will pull updated compose file on next refresh

## How to Apply
The Portainer stack uses GitOps/Repository deployment mode, so Portainer automatically pulls from GitHub. To apply the change:

1. **Automatic**: Wait for Portainer's scheduled refresh (if configured)
2. **Manual**: In Portainer UI:
   - Go to **Stacks** → **portainer**
   - Click **Update**
   - Click **Re-pull image and redeploy**
   - Click **Deploy the stack**

## Verification
After update, verify the env_file is being used:

```bash
# SSH to voyager
ssh voyager

# Check if .env is loaded
docker exec portainer env | grep -E "TS_|PORTAINER_"
```
