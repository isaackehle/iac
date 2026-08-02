# Synology Container Manager SSH Update Runbook

## Purpose

Use SSH to stop blocking processes, update the compose definition, and redeploy a Synology Container Manager Project.

## Scope

This runbook applies to:

- Synology Container Manager Projects (managed via DSM UI Projects tab)
- Projects with a dedicated working directory on the NAS
- Situations where the DSM UI deployment is failing due to running processes

## Prerequisites

- SSH access to the Synology NAS
- Docker/Container Manager installed and working
- Knowledge of the project directory path
- The docker-compose.yml file (local copy)
- Any .env file location
- Understanding of whether the app needs downtime or can be restarted in place

## Assumptions

- The project has a dedicated working directory on the NAS, e.g. `/volume1/docker/stacks/portainer/`
- The compose file is `docker-compose.yml` in the data subdirectory: `/volume1/docker/stacks/portainer/data/<project-name>/`
- The `.env` file is at the root of the project directory: `/volume1/docker/stacks/portainer/.env`
- Any bind mounts already exist on the NAS file system
- SSH access is available

## Procedure

### 1. Identify the Problem

```shell
# SSH into the NAS
ssh isaac@voyager.tail303fda.ts.net

# Check what's running related to the project
ps aux | grep -i <project-name> | grep -v grep

# Check if containers are running
sudo /var/packages/ContainerManager/target/tool/ddsmctl ps 2>&1 | head -30
```

### 2. Stop Blocking Processes

```shell
# Stop any container processes
sudo pkill -f <project-name>

# Or stop specific processes
sudo kill -9 <PID>

# Verify they're stopped
ps aux | grep -i <project-name> | grep -v grep
```

### 3. Backup Current Configuration

```shell
# Navigate to project directory
cd /volume1/docker/stacks/portainer/data/portainer/

# Create timestamped backup
BACKUP_DIR="./backup-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"

# Backup compose file
cp docker-compose.yml "$BACKUP_DIR/"

# Backup .env if present (it's at the root level)
[ -f /volume1/docker/stacks/portainer/.env ] && cp /volume1/docker/stacks/portainer/.env "$BACKUP_DIR/"

# Verify backup
ls -la "$BACKUP_DIR/"
```

### 4. Update Compose File

```shell
# Option A: Edit locally and push via SSH (Recommended - safer than editing on NAS)

# Push updated compose file
cat ~/code/isaackehle/iac/portainer/docker-compose.yml | \
  ssh isaac@voyager.tail303fda.ts.net \
  "cat > /volume1/docker/stacks/portainer/data/portainer/docker-compose.yml"

# Option B: Edit directly on NAS
# ssh isaac@voyager.tail303fda.ts.net
# nano /volume1/docker/stacks/portainer/data/portainer/docker-compose.yml
```

### 5. Update .env File (if needed)

```shell
# Push updated .env file (it's at the root level)
cat ~/code/isaackehle/iac/portainer/.env | \
  ssh isaac@voyager.tail303fda.ts.net \
  "cat > /volume1/docker/stacks/portainer/.env"

# Or edit directly on NAS
# ssh isaac@voyager.tail303fda.ts.net
# nano /volume1/docker/stacks/portainer/.env
```

### 6. Deploy via Container Manager

**Note:** Container Manager Projects are managed via the DSM UI, not docker compose commands.

```shell
# Method 1: Via Portainer (if running)
# 1. Navigate to http://voyager.tail303fda.ts.net:9000
# 2. Go to Stacks → Add stack
# 3. Select "Web editor"
# 4. Copy content from docker-compose.yml
# 5. Load variables from .env file
# 6. Deploy

# Method 2: Via Container Manager UI
# 1. Open Container Manager from DSM
# 2. Go to Projects tab
# 3. Click "Create" → "Project"
# 4. Choose "Import from YAML/JSON"
# 5. Paste docker-compose.yml content
# 6. Configure environment variables
# 7. Apply
```

### 7. Verify Deployment

```shell
# Check project status
sudo /var/packages/ContainerManager/target/tool/ddsmctl ps 2>&1 | grep portainer

# Check logs
docker logs ts-portainer
docker logs portainer

# Verify Tailscale
tailscale status
```

## Validation

- [ ] Containers are running and healthy
- [ ] Logs do not show repeated startup errors
- [ ] The service responds normally
- [ ] The compose file and .env file are in the expected state
- [ ] Tailscale device is online

## Rollback

If the update fails:

```shell
# Stop the new containers
sudo pkill -f <project-name>

# Restore the backup
cp "$BACKUP_DIR/docker-compose.yml" docker-compose.yml
[ -f "$BACKUP_DIR/.env" ] && cp "$BACKUP_DIR/.env" .env

# Redeploy via Container Manager UI
# (Same steps as above, using restored files)
```

## Troubleshooting

### Deployment Fails with "Container Already Exists"

```shell
# Remove the existing container
docker rm -f ts-portainer portainer

# Redeploy
# (Via Container Manager UI)
```

### Tailscale Not Connecting

```shell
# Check Tailscale logs
docker logs ts-portainer | grep tailscale

# Restart Tailscale
docker restart ts-portainer

# Check auth key
cat /volume1/docker/stacks/portainer/.env | grep TS_AUTHKEY
```

### Port Already in Use

```shell
# Check what's using the port
netstat -an | grep 9000

# Kill the process
sudo kill -9 <PID>
```

## Notes for Hermes

- Preserve Synology's project directory structure if it is a Container Manager Project
- Treat manual SSH changes carefully, because the DSM UI may become the source of truth again if someone later uses project actions there
- If the goal is just image refresh, the UI supports that too; SSH is mainly for scripted or repair workflows
- The `.env` file lives at the root of the project directory, not in subdirectories
- The `data/` subdirectory is controlled by Portainer itself - only the `docker-compose.yml` at the root needs to be updated
