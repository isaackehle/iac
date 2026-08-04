# Portainer UI Basics

This guide covers common tasks using the Portainer web interface at `https://portainer.tail303fda.ts.net`.

## Accessing Portainer

Open `https://portainer.tail303fda.ts.net` in your browser. If you haven't created an admin account yet:

1. Portainer will prompt you to create the first admin user
2. If you see "the Portainer instance timed out for security purposes", restart the stack:

   ```shell
   cd /volume1/docker/stacks/portainer
   docker restart portainer
   docker logs --tail 20 portainer | grep setup_token
   ```

3. Use the setup token to create your admin account within 5 minutes

---

## Deploying a Stack (Container)

### From Compose File (Recommended)

1. Navigate to **Stacks** in the left sidebar
2. Click **Add stack**
3. Choose **Web editor** (paste compose YAML) or **Upload compose file**
4. Enter a name for the stack (e.g., `langfuse`)
5. Paste the contents of your `docker-compose.yml`
6. Click **Deploy stack**
7. Portainer will prompt you to associate an environment file — browse to `/volume1/docker/stacks/<stack>/env.txt`

### From Existing Stack Directory

If you've already pushed files to the NAS:

1. Navigate to **Stacks**
2. Click **Add stack**
3. Choose **Git repository** (if using GitOps) or **Web editor**
4. For GitOps: point to your GitHub repo and Portainer will auto-pull updates
5. For manual: paste the compose YAML and associate with existing `env.txt`

---

## Viewing Running Containers

1. Navigate to **Containers** in the left sidebar
2. See all running containers across all stacks
3. Click a container to view:
   - **Logs** — real-time log output
   - **Inspect** — full container configuration
   - **Stats** — CPU/memory/network usage
   - **Exec** — run commands inside the container

---

## Viewing Stack Status

1. Navigate to **Stacks**
2. Each stack shows:
   - Status (running/stopped/healthy)
   - Number of containers
   - Last deployed time
3. Click a stack to see:
   - All containers in that stack
   - Environment variables
   - Links to associated networks and volumes

---

## Viewing Logs

### From Container List

1. Go to **Containers**
2. Click the **Logs** button on any container
3. Use the filter to search logs
4. Auto-refresh is enabled by default

### From Stack View

1. Go to **Stacks**
2. Click a stack name
3. Click **Logs** to see all container logs for that stack

---

## Restarting a Stack

1. Navigate to **Stacks**
2. Click the stack you want to restart
3. Click **Stop** (top right)
4. Wait for all containers to stop
5. Click **Start**

**Never restart individual containers** in a sidecar-pattern stack — always restart the entire stack to avoid stale namespace issues.

---

## Updating a Stack

### Manual Update

1. Pull the latest image:
   - Go to **Stacks** → click your stack
   - Click **Update** → **Pull image**
2. Restart the stack:
   - Click **Stop**, then **Start**

### GitOps Auto-Update

If configured with a Git repository:

1. Push your changes to GitHub
2. In Portainer, go to **Stacks** → click your stack
3. Click **Update** — Portainer will pull the latest from your repo
4. Set up **Watch** to auto-update on push (Settings → Stack → Watch repository)

---

## Managing Volumes

1. Navigate to **Volumes** in the left sidebar
2. See all persistent volumes across stacks
3. Click a volume to:
   - View mounted containers
   - View contents (if accessible)
   - Inspect mount points

### Common Volume Paths

- `/volume1/docker/stacks/portainer/data/` — Portainer's own data
- `/volume1/docker/stacks/<stack>/data/` — Stack-specific persistent data
- `/volume1/docker/stacks/<stack>/ts-state/` — Tailscale state (do not delete unless troubleshooting)

---

## Managing Networks

1. Navigate to **Networks** in the left sidebar
2. See all Docker networks
3. Sidecar-pattern stacks use:
   - Bridge networks (e.g., `langfuse_langfuse-net`) for sibling containers
   - Shared namespace (`network_mode: service:ts-<stack>`) for the sidecar

**Do not delete networks manually** — they're managed by Docker Compose.

---

## Troubleshooting Common Issues

### Container Won't Start

1. Check **Logs** for error messages
2. Verify environment variables are set correctly
3. Check if required ports are already in use
4. Verify the `.env` file exists and has correct values

### Portainer Timed Out

```shell
cd /volume1/docker/stacks/portainer
docker restart portainer
docker logs --tail 20 portainer | grep setup_token
```

### Sidecar Stack Not Accessible

1. Check all containers are running with matching uptimes:

   ```shell
   docker ps --format '{{.Names}}\t{{.RunningSince}}'
   ```

2. If `ts-<stack>` has been running much longer than others, restart the entire stack:

   ```shell
   cd /volume1/docker/stacks/<stack>
   docker compose down
   docker compose up -d
   ```

3. Verify Tailscale serve config:

   ```shell
   docker exec ts-<stack> tailscale serve status
   ```

### Container Logs Empty

1. Check if container is actually running: `docker ps`
2. Check if container crashed: `docker ps -a | grep <container>`
3. View full logs: `docker logs --tail 100 <container>`

---

## Best Practices

1. **Always use `docker compose down && up -d`** for sidecar stacks — never restart the sidecar alone
2. **Associate env.txt files** when deploying stacks — Portainer won't inject environment variables otherwise
3. **Test from a tailnet node** — don't test `.ts.net` URLs from the NAS itself (DNS resolution differs)
4. **Backup Portainer's data volume** — `/volume1/docker/stacks/portainer/data/` contains `portainer.db`
5. **Use GitOps for production stacks** — auto-deploy from GitHub on push
6. **Monitor container uptimes** — mismatched uptimes indicate a stale namespace issue

---

## Quick Reference Commands

```shell
# View all containers
docker ps -a

# View logs for a specific container
docker logs --tail 50 <container-name>

# Restart a stack properly
cd /volume1/docker/stacks/<stack>
docker compose down
docker compose up -d

# Check Tailscale serve status
docker exec ts-<stack> tailscale serve status

# Test backend from inside sidecar namespace
docker exec ts-<stack> wget -qO- http://127.0.0.1:9000/api/status
```

---

## Related Documentation

- `INSTALLATION.md` — detailed setup instructions
- `DEBUG.md` — troubleshooting guide
- `OUTAGE-2026-08-03.md` — outage post-mortem and lessons learned
- Root `README.md` — overall repo documentation
