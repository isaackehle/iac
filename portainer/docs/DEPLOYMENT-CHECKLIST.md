# Portainer Deployment Checklist

## ✅ Completed

### 1. Secure Secrets Directory

- [x] Created `/volume1/docker/portainer-secrets/` (700, root:root)
- [x] Moved `cert.pem` and `key.pem` from `stacks/portainer/certs/`
- [x] Moved `private-key.pem` from `stacks/portainer/chisel/`
- [x] Set file permissions to 600 (root:root)

### 2. Cleaned Up Duplicates

- [x] Removed duplicate certs from `data/certs/`
- [x] Removed duplicate chisel key from `data/chisel/`

### 3. Updated IAC Config

- [x] Updated `~/code/isaackehle/iac/portainer/old/compose.yaml`
- [x] Added secure volume mounts:
  - `/volume1/docker/portainer-secrets/certs:/certs:ro`
  - `/volume1/docker/portainer-secrets/chisel:/chisel:ro`
- [x] Verified YAML syntax

## 📋 Ready for Deployment

### Step 1: Deploy via Container Manager UI

1. **Open Container Manager**
   - DSM → Container Manager → **Project** tab

2. **Create New Project**
   - Click **Create** → **Project**
   - Choose **Import from YAML/JSON**

3. **Paste YAML Content**
   - Copy from `~/code/isaackehle/iac/portainer/old/compose.yaml`
   - Paste into the YAML editor

4. **Configure Environment**
   - Click **Next**
   - Select **Use existing .env file**
   - Browse to: `/volume1/docker/stacks/portainer/.env`

5. **Deploy**
   - Click **Apply**
   - Wait for both containers to start

### Step 2: Verify Deployment

```shell
# Check container status
sudo /var/packages/ContainerManager/target/tool/docker ps | grep portainer

# Check Tailscale status
sudo /var/packages/ContainerManager/target/tool/docker exec ts-portainer tailscale status

# Access Portainer
# http://voyager.tail303fda.ts.net:9000
```

## 📁 Final Directory Structure

```text
/volume1/docker/
├── portainer-secrets/        ← SECURE (700, root:root)
│   ├── cert.pem              ← 600, root:root
│   ├── key.pem               ← 600, root:root
│   └── private-key.pem       ← 600, root:root
│
/volume1/docker/stacks/portainer/
├── ts-config/                ← Tailscale config
│   ├── serve.json
│   └── ts-config/
├── ts-state/                 ← Tailscale state
│   └── ts-state/
│
/volume1/docker/portainer/    ← Portainer data (unchanged)
└── compose/7/                ← IAC repo (unchanged)
    └── portainer/
        └── docker-compose.yml
```

## 🔍 Verification Commands

```shell
# Check secrets directory permissions
ls -la /volume1/docker/portainer-secrets/
# Expected: drwx------ root root

# Check file permissions
ls -la /volume1/docker/portainer-secrets/cert.pem
# Expected: -rw------- root root

# Verify containers can access
sudo /var/packages/ContainerManager/target/tool/docker exec ts-portainer ls -la /certs/
sudo /var/packages/ContainerManager/target/tool/docker exec ts-portainer ls -la /chisel/

# Check Tailscale connectivity
sudo /var/packages/ContainerManager/target/tool/docker exec ts-portainer tailscale status
```

## 🚨 Troubleshooting

### Portainer Won't Start

1. Check logs: `sudo /var/packages/ContainerManager/target/tool/docker logs ts-portainer`
2. Verify secrets directory permissions
3. Check if Tailscale auth key is correct in `.env`

### Tailscale Not Connecting

1. Verify `TS_AUTHKEY` in `.env` is correct
2. Check Tailscale device status: `tailscale status`
3. Verify network access: `ping -c 3 discovery.tailscale.com`

### Permission Denied Errors

1. Ensure `/volume1/docker/portainer-secrets/` is 700, root:root
2. Ensure files are 600, root:root
3. Containers run as root, so they should have access

## 📝 Files Reference

- **Compose YAML**: `~/code/isaackehle/iac/portainer/old/compose.yaml`
- **Environment**: `/volume1/docker/stacks/portainer/.env`
- **Deployment Guide**: `~/code/isaackehle/iac/portainer/CONTAINER-MANAGER-DEPLOY.md`
- **Security Guide**: `~/code/isaackehle/iac/portainer/CHISEL-SECURITY.md`
- **Structure Guide**: `~/code/isaackehle/iac/portainer/DIRECTORY-STRUCTURE.md`
