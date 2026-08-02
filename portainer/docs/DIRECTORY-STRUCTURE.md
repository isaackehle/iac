# Portainer Directory Structure Migration

## Current Structure

```text
/volume1/docker/stacks/portainer/
├── certs/                    ← SENSITIVE (cert.pem, key.pem)
│   ├── cert.pem
│   └── key.pem
├── chisel/                   ← SENSITIVE (private-key.pem)
│   └── private-key.pem
├── data/                     ← Portainer data + IAC repo
│   ├── bin/
│   ├── certs/                ← Duplicate certs
│   ├── chisel/               ← Duplicate chisel key
│   ├── compose/              ← IAC repo structure
│   ├── config/
│   ├── data/
│   ├── portainer.db
│   ├── portainer.key
│   ├── portainer.pub
│   ├── tls/
│   ├── ts-config/
│   └── ts-state/
├── ts-config/                ← Tailscale config
│   ├── serve.json
│   └── ts-config/
└── ts-state/                 ← Tailscale state
    └── ts-state/
```

## Problem

- `stacks/portainer/` is world-writable (`drwxrwxrwx+`)
- Sensitive files (certs, chisel key) are in the same directory
- Duplicate files in multiple locations

## Recommended Structure

```text
/volume1/docker/
├── portainer-secrets/        ← SECURE (700, root:root)
│   ├── certs/
│   │   ├── cert.pem
│   │   └── key.pem
│   ├── chisel/
│   │   └── private-key.pem
│   └── portainer-keys/
│       ├── portainer.key
│       └── portainer.pub
│
/volume1/docker/stacks/portainer/
├── ts-config/                ← Tailscale config (755)
│   ├── serve.json
│   └── ts-config/
└── ts-state/                 ← Tailscale state (700)
    └── ts-state/

/volume1/docker/portainer/    ← Portainer data (unchanged)
├── data/
│   ├── portainer.db
│   └── ...
└── compose/7/                ← IAC repo (unchanged)
    └── portainer/
        └── docker-compose.yml
```

## Migration Steps

```shell
# 1. Create secure secrets directory
sudo mkdir -p /volume1/docker/portainer-secrets/certs
sudo mkdir -p /volume1/docker/portainer-secrets/chisel
sudo mkdir -p /volume1/docker/portainer-secrets/portainer-keys
sudo chmod 700 /volume1/docker/portainer-secrets
sudo chown root:root /volume1/docker/portainer-secrets

# 2. Move sensitive files
sudo mv /volume1/docker/stacks/portainer/certs/* /volume1/docker/portainer-secrets/certs/
sudo mv /volume1/docker/stacks/portainer/chisel/private-key.pem /volume1/docker/portainer-secrets/chisel/
sudo mv /volume1/docker/stacks/portainer/data/portainer.key /volume1/docker/portainer-secrets/portainer-keys/ 2>/dev/null || true
sudo mv /volume1/docker/stacks/portainer/data/portainer.pub /volume1/docker/portainer-secrets/portainer-keys/ 2>/dev/null || true

# 3. Set secure permissions
sudo chmod 600 /volume1/docker/portainer-secrets/certs/*
sudo chmod 600 /volume1/docker/portainer-secrets/chisel/*
sudo chmod 600 /volume1/docker/portainer-secrets/portainer-keys/*
sudo chown root:root /volume1/docker/portainer-secrets/certs/*
sudo chown root:root /volume1/docker/portainer-secrets/chisel/*
sudo chown root:root /volume1/docker/portainer-secrets/portainer-keys/*

# 4. Update compose.yaml to mount from new location
# See compose.yaml update below
```

## Updated compose.yaml Volumes

```yaml
services:
  ts-portainer:
    volumes:
      - /volume1/docker/portainer-secrets/certs:/certs:ro
      - /volume1/docker/portainer-secrets/chisel:/chisel:ro
      - /volume1/docker/stacks/portainer/ts-config:/config
      - /volume1/docker/stacks/portainer/ts-state:/var/lib/tailscale

  portainer:
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - /volume1/docker/portainer:/data
```

## Verification

```shell
# Check permissions
ls -la /volume1/docker/portainer-secrets/
# Should show: drwx------ root root

# Check file permissions
ls -la /volume1/docker/portainer-secrets/certs/
# Should show: -rw------- root root

# Verify container can still access
sudo /var/packages/ContainerManager/target/tool/docker exec ts-portainer ls -la /certs/
sudo /var/packages/ContainerManager/target/tool/docker exec ts-portainer ls -la /chisel/
```

## Benefits

1. **Security**: Sensitive files in 700 directory, 600 files
2. **Clarity**: Clear separation between secrets and config
3. **No duplicates**: Single source of truth for each file
4. **IAC repo preserved**: `data/compose/` remains unchanged
