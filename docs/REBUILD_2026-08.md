# Rebuild Guide

This document explains how to rebuild pihole and syncthing stacks from the IAC repo.

## Directory Structure

```shell
/ volume1/docker/stacks/portainer/
├── data/                    # Active stacks (only pihole + syncthing)
│   ├── pihole/
│   │   ├── docker-compose.yml
│   │   ├── .env
│   │   ├── serve.json
│   │   └── serve.json.tmpl
│   └── syncthing/
│       ├── docker-compose.yml
│       ├── .env
│       ├── serve.json
│       └── serve.json.tmpl
├── iac/                     # Reference IAC repo (all stacks)
│   ├── pihole/
│   ├── syncthing/
│   └── ... (all other stacks)
├── database/                # Portainer's database
├── keys/                    # Portainer's keys
├── ts-config/               # Tailscale config
└── ts-state/                # Tailscale state
```

## Quick Rebuild

### From Mac (recommended)

1. Navigate to the portainer directory:

   ```shell
   cd ~/code/isaackehle/iac/portainer/
   ```

2. Run the rebuild script:

   ```shell
   # Rebuild pihole only
   ./rebuild.sh pihole

   # Rebuild syncthing only
   ./rebuild.sh syncthing

   # Rebuild both
   ./rebuild.sh all
   ```

### From NAS (alternative)

If you're already on the NAS:

1. Navigate to the data directory:

   ```shell
   cd /volume1/docker/stacks/portainer/data/
   ```

2. Deploy manually:

   ```shell
   # For pihole
   sudo docker compose -f pihole/docker-compose.yml up -d

   # For syncthing
   sudo docker compose -f syncthing/docker-compose.yml up -d
   ```

## What the Rebuild Script Does

The `rebuild.sh` script performs these steps:

1. **Generate .env** - Creates the environment file from your secrets
2. **Create directories** - Sets up the stack directory on the NAS
3. **Push files** - Copies docker-compose.yml, .env, and serve.json to the NAS
4. **Apply deployment** - Shows you how to deploy via Portainer or docker compose

## Manual Rebuild Steps

If you prefer to do it manually:

### 1. Generate .env locally

```shell
cd ~/code/isaackehle/iac/portainer/
bash scripts/gen-env.sh pihole
bash scripts/gen-env.sh syncthing
```

### 2. Copy files to NAS

```shell
# Pihole
scp pihole/docker-compose.yml voyager:/volume1/docker/stacks/portainer/data/pihole/
scp pihole/.env voyager:/volume1/docker/stacks/portainer/data/pihole/
scp pihole/serve.json voyager:/volume1/docker/stacks/portainer/data/pihole/

# Syncthing
scp syncthing/docker-compose.yml voyager:/volume1/docker/stacks/portainer/data/syncthing/
scp syncthing/.env voyager:/volume1/docker/stacks/portainer/data/syncthing/
scp syncthing/serve.json voyager:/volume1/docker/stacks/portainer/data/syncthing/
```

### 3. Deploy via Portainer

1. Open Portainer UI (<https://portainer.tail303fda.ts.net/>)
2. Go to Stacks/Containers
3. Click "Add stack"
4. Select "Web Editor"
5. Copy the contents of `docker-compose.yml`
6. Click "Load variables from .env file" and select the `.env` file
7. Click "Deploy the container"

### 4. Deploy via docker compose (alternative)

```shell
# SSH to NAS
ssh voyager

# Deploy pihole
sudo docker compose -f /volume1/docker/stacks/portainer/data/pihole/docker-compose.yml up -d

# Deploy syncthing
sudo docker compose -f /volume1/docker/stacks/portainer/data/syncthing/docker-compose.yml up -d
```

## Troubleshooting

### Portainer can't start

1. Check logs:

   ```shell
   sudo docker logs <container-name>
   ```

2. Verify .env is correct:

   ```shell
   cat /volume1/docker/stacks/portainer/data/pihole/.env
   ```

3. Check if ports are in use:

   ```shell
   sudo netstat -an | grep <port>
   ```

### Tailscale serve not working

1. Verify serve.json is correct:

   ```shell
   cat /volume1/docker/stacks/portainer/data/pihole/serve.json
   ```

2. Check Tailscale status:

   ```shell
   sudo tailscale status
   ```

### Permissions issues

```shell
sudo chown -R root:root /volume1/docker/stacks/portainer/data/<stack>/
sudo chmod 755 /volume1/docker/stacks/portainer/data/<stack>/
```

## Notes

- The `iac/` directory contains the full IAC repo for reference
- The `data/` directory only contains the active stacks (pihole + syncthing)
- All secrets are stored in `iac-secrets.env` on your Mac (never on NAS)
- The rebuild script uses your local secrets to generate `.env`
