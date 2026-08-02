# Portainer Directory Consolidation Plan

## Current State Analysis

**Top-level (stacks/portainer/):**

- `certs/` - Tailscale certs (cert.pem, key.pem)
- `chisel/` - Chisel private key
- `data/` - Portainer data + IAC repo
- `ts-config/` - Tailscale config
- `ts-state/` - Tailscale state

**Inside data/compose/:**

- `10/` - IAC repo (full stack)
- `7/` - IAC repo (full stack, duplicate)

**Duplicate sensitive files:**

- `data/certs/` - Duplicate of top-level certs
- `data/chisel/` - Duplicate of top-level chisel key

## Goal

1. **Keep IAC repo in `data/compose/7/`** (not moving it)
2. **Consolidate sensitive files** to secure location
3. **Update compose.yaml** to mount from secure location
4. **Remove duplicates**

## Step 1: Create Secure Secrets Directory

```shell
# Create secure directory structure
sudo mkdir -p /volume1/docker/portainer-secrets/{certs,chisel,portainer-keys}
sudo chmod 700 /volume1/docker/portainer-secrets
sudo chown root:root /volume1/docker/portainer-secrets
```

## Step 2: Move Sensitive Files

```shell
# Move top-level certs (primary source)
sudo mv /volume1/docker/stacks/portainer/certs/* /volume1/docker/portainer-secrets/certs/

# Move chisel key
sudo mv /volume1/docker/stacks/portainer/chisel/private-key.pem /volume1/docker/portainer-secrets/chisel/

# Move portainer keys from data/ (if they exist)
sudo mv /volume1/docker/stacks/portainer/data/portainer.key /volume1/docker/portainer-secrets/portainer-keys/ 2>/dev/null || true
sudo mv /volume1/docker/stacks/portainer/data/portainer.pub /volume1/docker/portainer-secrets/portainer-keys/ 2>/dev/null || true

# Remove duplicate certs/chisel from data/
sudo rm -rf /volume1/docker/stacks/portainer/data/certs/*
sudo rm -rf /volume1/docker/stacks/portainer/data/chisel/*
```

## Step 3: Set Secure Permissions

```shell
# Set file permissions
sudo chmod 600 /volume1/docker/portainer-secrets/certs/*
sudo chmod 600 /volume1/docker/portainer-secrets/chisel/*
sudo chmod 600 /volume1/docker/portainer-secrets/portainer-keys/* 2>/dev/null || true

# Set ownership
sudo chown root:root /volume1/docker/portainer-secrets/certs/*
sudo chown root:root /volume1/docker/portainer-secrets/chisel/*
sudo chown root:root /volume1/docker/portainer-secrets/portainer-keys/* 2>/dev/null || true
```

## Step 4: Update compose.yaml

The IAC compose.yaml at `~/code/isaackehle/iac/portainer/old/compose.yaml` needs to be updated to mount from the new secure location:

```yaml
services:
  ts-portainer:
    volumes:
      # Old (insecure):
      # - /volume1/docker/portainer/ts-state:/var/lib/tailscale
      # - /volume1/docker/stacks/portainer/ts-config:/config

      # New (secure):
      - /volume1/docker/portainer-secrets/certs:/certs:ro
      - /volume1/docker/portainer-secrets/chisel:/chisel:ro
      - /volume1/docker/stacks/portainer/ts-config:/config
      - /volume1/docker/stacks/portainer/ts-state:/var/lib/tailscale

  portainer:
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - /volume1/docker/portainer:/data
```

**Note:** The IAC repo in `data/compose/7/` is preserved and unchanged.

## Step 5: Verify

```shell
# Check permissions
ls -la /volume1/docker/portainer-secrets/
# Should show: drwx------ root root

# Verify container can access
sudo /var/packages/ContainerManager/target/tool/docker exec ts-portainer ls -la /certs/
sudo /var/packages/ContainerManager/target/tool/docker exec ts-portainer ls -la /chisel/

# Check IAC repo is still intact
ls -la /volume1/docker/stacks/portainer/data/compose/7/portainer/
```

## Benefits

1. **Security**: Sensitive files in 700 directory, 600 files, root-owned
2. **Clarity**: Clear separation between secrets and config
3. **IAC preserved**: `data/compose/7/` remains unchanged
4. **No duplicates**: Single source of truth for each file
5. **Portainer data intact**: `data/` directory structure preserved

## Alternative: If You Want IAC in stacks/portainer

If you prefer to keep the IAC repo directly in `stacks/portainer/` instead of nested in `data/`:

```shell
# Move IAC repo to top level
sudo mv /volume1/docker/stacks/portainer/data/compose /volume1/docker/stacks/portainer/iac
```

Then update compose.yaml to reference `/volume1/docker/stacks/portainer/iac/7/portainer/docker-compose.yml`

But this is optional - the current nested structure works fine.
