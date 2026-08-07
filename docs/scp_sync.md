# SCP Sync Commands

This document provides the commands to sync `.env` files between your local machine and the Synology NAS.

## Quick Start

**Recommended**: Use the `sync-env.sh` helper script:

```bash
# Generate .env for a stack
cd ~/code/isaackehle/iac
bash scripts/gen-env.sh portainer

# Push to NAS
./scripts/sync-env.sh push portainer

# Pull from NAS
./scripts/sync-env.sh pull portainer

# List all managed stacks
./scripts/sync-env.sh list

# Push all .env files
./scripts/sync-env.sh push-all

# Pull all .env files
./scripts/sync-env.sh pull-all
```

## Overview

The IAC repo uses `.env` files for stack configuration, but these are gitignored to prevent secrets from being committed. Instead:

- **Local**: Edit `iac-secrets.env` (or create `iac-secrets.env.local`)
- **NAS**: Run `scripts/gen-env.sh <stack>` to generate `.env` in the stack directory
- **Sync**: Use `scp` to push generated `.env` files to the NAS

## SSH Configuration

Add this to `~/.ssh/config` for easier SSH access:

```ssh
Host nas
    HostName nas.tail303fda.ts.net
    User isaac
    IdentityFile ~/.ssh/id_ed25519
    AddKeysToAgent yes
```

Now you can use `ssh nas` instead of the full hostname.

## Push `.env` to NAS

Generate the `.env` file locally, then push it:

```bash
# Generate .env for a stack
cd ~/code/isaackehle/iac
bash scripts/gen-env.sh portainer

# Push to NAS (replace portainer with your stack name)
scp -O ~/code/isaackehle/iac/portainer/.env isaac@nas.tail303fda.ts.net:/volume1/docker/stacks/portainer/.env
```

## Pull `.env` from NAS

```bash
# Pull from NAS (replace portainer with your stack name)
scp -O isaac@nas.tail303fda.ts.net:/volume1/docker/stacks/portainer/.env ~/code/isaackehle/iac/portainer/.env
```

## All Stack Commands

### Using sync-env.sh (Recommended)

```bash
# Push a single stack
./scripts/sync-env.sh push portainer

# Pull a single stack
./scripts/sync-env.sh pull portainer

# Push all stacks
./scripts/sync-env.sh push-all

# Pull all stacks
./scripts/sync-env.sh pull-all
```

### Manual SCP Commands

If you prefer manual SCP commands:

```bash
# Push to NAS
scp -O ~/code/isaackehle/iac/homeassistant/.env isaac@nas.tail303fda.ts.net:/volume1/docker/stacks/homeassistant/.env
scp -O ~/code/isaackehle/iac/langfuse/.env isaac@nas.tail303fda.ts.net:/volume1/docker/stacks/langfuse/.env
scp -O ~/code/isaackehle/iac/n8n/.env isaac@nas.tail303fda.ts.net:/volume1/docker/stacks/n8n/.env
scp -O ~/code/isaackehle/iac/nextcloud/.env isaac@nas.tail303fda.ts.net:/volume1/docker/stacks/nextcloud/.env
scp -O ~/code/isaackehle/iac/openwebui/.env isaac@nas.tail303fda.ts.net:/volume1/docker/stacks/openwebui/.env
scp -O ~/code/isaackehle/iac/pihole/.env isaac@nas.tail303fda.ts.net:/volume1/docker/stacks/pihole/.env
scp -O ~/code/isaackehle/iac/plex/.env isaac@nas.tail303fda.ts.net:/volume1/docker/stacks/plex/.env
scp -O ~/code/isaackehle/iac/portainer/.env isaac@nas.tail303fda.ts.net:/volume1/docker/stacks/portainer/.env
scp -O ~/code/isaackehle/iac/postgresql/.env isaac@nas.tail303fda.ts.net:/volume1/docker/stacks/postgresql/.env
scp -O ~/code/isaackehle/iac/syncthing/.env isaac@nas.tail303fda.ts.net:/volume1/docker/stacks/syncthing/.env
scp -O ~/code/isaackehle/iac/synology-mcp/.env isaac@nas.tail303fda.ts.net:/volume1/docker/stacks/synology-mcp/.env
scp -O ~/code/isaackehle/iac/affine/.env isaac@nas.tail303fda.ts.net:/volume1/docker/stacks/affine/.env
scp -O ~/code/isaackehle/iac/frigate/.env isaac@nas.tail303fda.ts.net:/volume1/docker/stacks/frigate/.env
scp -O ~/code/isaackehle/iac/mosquitto/.env isaac@nas.tail303fda.ts.net:/volume1/docker/stacks/mosquitto/.env

# Pull from NAS (same pattern, reverse source/destination)
scp -O isaac@nas.tail303fda.ts.net:/volume1/docker/stacks/homeassistant/.env ~/code/isaackehle/iac/homeassistant/.env
scp -O isaac@nas.tail303fda.ts.net:/volume1/docker/stacks/langfuse/.env ~/code/isaackehle/iac/langfuse/.env
scp -O isaac@nas.tail303fda.ts.net:/volume1/docker/stacks/n8n/.env ~/code/isaackehle/iac/n8n/.env
scp -O isaac@nas.tail303fda.ts.net:/volume1/docker/stacks/nextcloud/.env ~/code/isaackehle/iac/nextcloud/.env
scp -O isaac@nas.tail303fda.ts.net:/volume1/docker/stacks/openwebui/.env ~/code/isaackehle/iac/openwebui/.env
scp -O isaac@nas.tail303fda.ts.net:/volume1/docker/stacks/pihole/.env ~/code/isaackehle/iac/pihole/.env
scp -O isaac@nas.tail303fda.ts.net:/volume1/docker/stacks/plex/.env ~/code/isaackehle/iac/plex/.env
scp -O isaac@nas.tail303fda.ts.net:/volume1/docker/stacks/portainer/.env ~/code/isaackehle/iac/portainer/.env
scp -O isaac@nas.tail303fda.ts.net:/volume1/docker/stacks/postgresql/.env ~/code/isaackehle/iac/postgresql/.env
scp -O isaac@nas.tail303fda.ts.net:/volume1/docker/stacks/syncthing/.env ~/code/isaackehle/iac/syncthing/.env
scp -O isaac@nas.tail303fda.ts.net:/volume1/docker/stacks/synology-mcp/.env ~/code/isaackehle/iac/synology-mcp/.env
scp -O isaac@nas.tail303fda.ts.net:/volume1/docker/stacks/affine/.env ~/code/isaackehle/iac/affine/.env
scp -O isaac@nas.tail303fda.ts.net:/volume1/docker/stacks/frigate/.env ~/code/isaackehle/iac/frigate/.env
scp -O isaac@nas.tail303fda.ts.net:/volume1/docker/stacks/mosquitto/.env ~/code/isaackehle/iac/mosquitto/.env
```

## Alternative: Use SSH Alias

If you configured the SSH alias above, you can use:

```bash
# Push to NAS
scp -O ~/code/isaackehle/iac/portainer/.env nas:/volume1/docker/stacks/portainer/.env

# Pull from NAS
scp -O nas:/volume1/docker/stacks/portainer/.env ~/code/isaackehle/iac/portainer/.env
```

## Workflow

1. **Edit secrets**: Modify `iac-secrets.env` or `iac-secrets.env.local`
2. **Generate .env**: Run `bash scripts/gen-env.sh <stack>`
3. **Push to NAS**: Run the `scp -O` command for that stack
4. **Deploy**: Run `bash scripts/deploy.sh <stack>` on the NAS

## Notes

- The `-O` flag enables SCP protocol v2 (more secure)
- `.env` files are gitignored - they never get committed to the repo
- Generated `.env` files contain variable-substituted values from `iac-secrets.env`
- Always verify the `.env` file on the NAS matches your intended configuration
