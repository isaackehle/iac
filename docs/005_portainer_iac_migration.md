# Portainer IAC Migration Plan - Updated

## Current State

**On Disk (NAS - voyager):**

- ✅ `/volume1/docker/stacks/portainer/` - IAC-style directory with `.env`, `data/`, `ts-config/`, `ts-state/`
- ✅ `/volume1/docker/portainer-secrets/` - Secure directory (700, root:root) with:
  - `cert.pem`, `key.pem` - Tailscale certificates
  - `private-key.pem` - Chisel private key
- ✅ `/volume1/docker/portainer/` - Portainer data directory (unchanged)
- ✅ Duplicate files cleaned up from `data/certs/` and `data/chisel/`
- ⚠️ Portainer container exists but is **exited** (needs deployment)

**In IAC Repo:**

- ✅ `~/code/isaackehle/iac/portainer/old/compose.yaml` - Updated with secure volume mounts
- ✅ `~/code/isaackehle/iac/portainer/.env` - Environment file with Tailscale auth key
- ✅ `~/code/isaackehle/iac/portainer/INSTALLATION.md` - Container Manager deployment guide (renamed from PORTAINER.md)
- ✅ `~/code/isaackehle/iac/portainer/DEPLOYMENT-CHECKLIST.md` - Verification checklist

**IAC Repo Structure on NAS:**

- `/volume1/docker/stacks/portainer/data/compose/7/` - IAC repo (preserved, unchanged)
- `/volume1/docker/stacks/portainer/data/compose/10/` - IAC repo (duplicate, can be cleaned up later)

## Task 1: Consolidate Disk Content ✅ COMPLETED

✅ Created secure `/volume1/docker/portainer-secrets/` directory (700, root:root)
✅ Moved sensitive files (certs, chisel key) to secure location
✅ Set file permissions to 600 (root:root)
✅ Removed duplicate files from `data/certs/` and `data/chisel/`
✅ Updated compose.yaml with secure volume mounts

### Verification

```shell
# Check secrets directory
ls -la /volume1/docker/portainer-secrets/
# Expected: drwx------ root root

# Check file permissions
ls -la /volume1/docker/portainer-secrets/cert.pem
# Expected: -rw------- root root

# Verify IAC repo intact
ls -la /volume1/docker/stacks/portainer/data/compose/7/portainer/
```

## Task 2: Deploy Portainer via Container Manager UI

### Step 1: Get YAML File

**Option A: Copy from Mac to NAS**

```shell
scp ~/code/isaackehle/iac/portainer/old/compose.yaml isaac@voyager.tail303fda.ts.net:/volume1/docker/stacks/portainer/docker-compose.yml
```

**Option B: Paste directly in Container Manager UI**

1. Open Container Manager → Project → Create → Import from YAML/JSON
2. Copy entire content from `~/code/isaackehle/iac/portainer/old/compose.yaml`
3. Paste into YAML editor

### Step 2: Deploy

1. **Create Project**
   - Container Manager → Project tab
   - Click **Create** → **Project**
   - Choose **Import from YAML/JSON**

2. **Paste YAML Content**
   - Copy from `~/code/isaackehle/iac/portainer/old/compose.yaml`
   - Paste into YAML editor

3. **Configure Environment**
   - Click **Next**
   - Select **Use existing .env file**
   - Browse to: `/volume1/docker/stacks/portainer/.env`

4. **Deploy**
   - Click **Apply**
   - Wait for both `ts-portainer` and `portainer` containers to start

### Step 3: Verify Deployment

```shell
# Check container status
sudo /var/packages/ContainerManager/target/tool/docker ps | grep portainer

# Check Tailscale status
sudo /var/packages/ContainerManager/target/tool/docker exec ts-portainer tailscale status

# Access Portainer
# http://voyager.tail303fda.ts.net:9000
```

## Task 3: Deploy Synology MCP Server

### Option A: Via Portainer UI (Recommended)

1. **Open Portainer**
   - Navigate to `http://voyager.tail303fda.ts.net:9000`
   - Complete initial setup if needed

2. **Create Stack**
   - Go to **Stacks** → **Add stack**
   - Choose **Web editor**

3. **Configure Stack**
   - Copy content from `~/code/isaackehle/iac/synology-mcp/docker-compose.yml`
   - Set working directory: `/volume1/docker/stacks/synology-mcp`
   - Click **Load from file** and select `~/code/isaackehle/iac/synology-mcp/.env`
   - Click **Deploy the stack**

4. **Verify MCP Server**
   - Check container logs: `docker compose logs synology-mcp`
   - Test Web API connectivity

### Option B: SSH-Based MCP Server (Alternative)

If Web API HTTP endpoint returns error 101:

- Create custom MCP server that connects via SSH
- Executes `synowebapi` commands directly
- Bypasses HTTP endpoint issue

See `~/code/isaackehle/iac/synology-mcp/INSTALLATION.md` for details.

## Task 4: Rename Documentation ✅ COMPLETED

✅ Renamed all `PORTAINER.md` files to `INSTALLATION.md` across IAC repo

**Files renamed:**

- `portainer/PORTAINER.md` → `portainer/INSTALLATION.md` (new content, Container Manager focused)
- `syncthing/PORTAINER.md` → `syncthing/INSTALLATION.md`
- `nextcloud/PORTAINER.md` → `nextcloud/INSTALLATION.md`
- `synology-mcp/PORTAINER.md` → `synology-mcp/INSTALLATION.md`
- `n8n/PORTAINER.md` → `n8n/INSTALLATION.md`
- `plex/PORTAINER.md` → `plex/INSTALLATION.md`
- `pihole/PORTAINER.md` → `pihole/INSTALLATION.md`

**Rationale:** The old `PORTAINER.md` files described deploying stacks *via* Portainer UI, but Portainer itself must be deployed via Container Manager (since it
doesn't exist yet). The new `INSTALLATION.md` files reflect the actual deployment method.

## Verification Checklist

- [x] Secure secrets directory created (`/volume1/docker/portainer-secrets/`)
- [x] Sensitive files moved and secured (600, root:root)
- [x] Duplicate files removed from `data/certs/` and `data/chisel/`
- [x] compose.yaml updated with secure volume mounts
- [x] PORTAINER.md files renamed to INSTALLATION.md
- [ ] Portainer container is **running** (not exited)
- [ ] Tailscale device `portainer` is **online**
- [ ] Can access Portainer at `http://voyager.tail303fda.ts.net:9000`
- [ ] MCP server stack is deployed
- [ ] MCP server container is **running**
- [ ] MCP server can connect to Synology (no error 101)

## Files Reference

**IAC Repo:**

- Portainer compose: `~/code/isaackehle/iac/portainer/old/compose.yaml`
- Portainer .env: `~/code/isaackehle/iac/portainer/.env`
- Portainer install guide: `~/code/isaackehle/iac/portainer/INSTALLATION.md`
- MCP server compose: `~/code/isaackehle/iac/synology-mcp/docker-compose.yml`
- MCP credentials: `~/code/isaackehle/iac/synology-mcp/.env`
- MCP install guide: `~/code/isaackehle/iac/synology-mcp/INSTALLATION.md`

**NAS Files:**

- Portainer .env: `/volume1/docker/stacks/portainer/.env`
- Portainer compose: `/volume1/docker/stacks/portainer/docker-compose.yml` (after deployment)
- Portainer data: `/volume1/docker/portainer/`
- Secure secrets: `/volume1/docker/portainer-secrets/`
- IAC repo (on NAS): `/volume1/docker/stacks/portainer/data/compose/7/`

**Documentation:**

- Container Manager deployment: `~/code/isaackehle/iac/portainer/INSTALLATION.md` (formerly PORTAINER.md)
- Deployment checklist: `~/code/isaackehle/iac/portainer/DEPLOYMENT-CHECKLIST.md`
- Security guide: `~/code/isaackehle/iac/portainer/CHISEL-SECURITY.md`
- Structure guide: `~/code/isaackehle/iac/portainer/DIRECTORY-STRUCTURE.md`
- Updated compose guide: `~/code/isaackehle/iac/portainer/UPDATED-COMPOSE.md`

## Next Steps

1. **Deploy Portainer** via Container Manager UI (see Task 2 above)
2. **Verify Portainer** is running and accessible
3. **Deploy MCP server** via Portainer UI (see Task 3 above)
4. **Test MCP connectivity** to Synology Web API

## Notes

- The IAC repo structure in `data/compose/7/` is preserved and unchanged
- Secure secrets directory uses 700 permissions for maximum security
- Containers run as root, so they can access the secrets directory
- Tailscale certificate integration is ready once Portainer is deployed
- Web API HTTP endpoint error 101 is a DSM 7.3.2 limitation; MCP server will work via Docker MCP
