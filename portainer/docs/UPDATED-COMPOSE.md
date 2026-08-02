# Updated Portainer Compose.yaml

## Changes Made

Updated `~/code/isaackehle/iac/portainer/old/compose.yaml` to use secure secrets directory.

## New Volume Mounts

### Before (Insecure)

```yaml
services:
  ts-portainer:
    volumes:
      - /volume1/docker/portainer/ts-state:/var/lib/tailscale
      - /volume1/docker/stacks/portainer/ts-config:/config
```

### After (Secure)

```yaml
services:
  ts-portainer:
    volumes:
      - /volume1/docker/portainer-secrets/certs:/certs:ro
      - /volume1/docker/portainer-secrets/chisel:/chisel:ro
      - /volume1/docker/stacks/portainer/ts-config:/config
      - /volume1/docker/stacks/portainer/ts-state:/var/lib/tailscale
```

## Key Changes

1. **Added secure cert mount**: `/volume1/docker/portainer-secrets/certs:/certs:ro`
2. **Added secure chisel mount**: `/volume1/docker/portainer-secrets/chisel:/chisel:ro`
3. **Reordered volumes** for clarity (secrets first, then config/state)

## Required Directory Structure

```text
/volume1/docker/
├── portainer-secrets/        ← SECURE (700, root:root)
│   ├── certs/
│   │   ├── cert.pem
│   │   └── key.pem
│   └── chisel/
│       └── private-key.pem
│
/volume1/docker/stacks/portainer/
├── ts-config/                ← Tailscale config
│   ├── serve.json
│   └── ts-config/
└── ts-state/                 ← Tailscale state
    └── ts-state/

/volume1/docker/portainer/    ← Portainer data (unchanged)
└── compose/7/                ← IAC repo (unchanged)
    └── portainer/
        └── docker-compose.yml
```

## Migration Steps

```shell
# 1. Create secure directory
sudo mkdir -p /volume1/docker/portainer-secrets/{certs,chisel}
sudo chmod 700 /volume1/docker/portainer-secrets
sudo chown root:root /volume1/docker/portainer-secrets

# 2. Move sensitive files
sudo mv /volume1/docker/stacks/portainer/certs/* /volume1/docker/portainer-secrets/certs/
sudo mv /volume1/docker/stacks/portainer/chisel/private-key.pem /volume1/docker/portainer-secrets/chisel/

# 3. Set secure permissions
sudo chmod 600 /volume1/docker/portainer-secrets/certs/*
sudo chmod 600 /volume1/docker/portainer-secrets/chisel/*
sudo chown root:root /volume1/docker/portainer-secrets/certs/*
sudo chown root:root /volume1/docker/portainer-secrets/chisel/*

# 4. Remove duplicates
sudo rm -rf /volume1/docker/stacks/portainer/data/certs/*
sudo rm -rf /volume1/docker/stacks/portainer/data/chisel/*
```

## Verification

```shell
# Check permissions
ls -la /volume1/docker/portainer-secrets/
# drwx------ root root

# Verify files
ls -la /volume1/docker/portainer-secrets/certs/
ls -la /volume1/docker/portainer-secrets/chisel/

# Test container access
sudo /var/packages/ContainerManager/target/tool/docker exec ts-portainer ls -la /certs/
sudo /var/packages/ContainerManager/target/tool/docker exec ts-portainer ls -la /chisel/
```

## Notes

- The `/certs` mount is for Tailscale TLS certificates
- The `/chisel` mount is for the chisel private key
- Both are mounted read-only (`:ro`) for security
- The portainer service volume remains unchanged: `/volume1/docker/portainer:/data`
