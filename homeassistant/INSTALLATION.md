# Home Assistant — Portainer Stack Deployment

> **Recommended:** `scripts/deploy.sh all homeassistant <ssh-host>` from the repo root handles directory setup, `.env` generation, file placement, and bringing the stack up in one step — see root `README.md`/`QUICKSTART.md`. The manual steps below are the equivalent broken out.

## Architecture Note

Home Assistant uses **Pattern A (host-level `tailscale serve`)**, **NOT** a Tailscale sidecar.

Home Assistant requires `network_mode: host` for device discovery — mDNS, Chromecast, HomeKit, and most local-network integrations do not work from inside a bridge network. A sidecar using `network_mode: service:homeassistant` would land in the **host** network namespace, running a second `tailscaled` alongside the NAS's own daemon. Both would compete to manage tailnet state on the same netns.

So this stack uses the NAS host's own `tailscaled` instead, same as `affine`, `frigate`, and `postgresql`. The mapping lives in `scripts/lib.sh` under `STACK_SERVE_PORTS` and is applied by `scripts/serve-all.sh` — there is **deliberately no serve.json, no ts-state, and no ts-config here**.

See AGENTS.md "Two competing Tailscale deployment patterns" and docs/006_docker_compose_standards.md correctness rule 3.

## Directory Setup (on Synology NAS)

```shell
STACK_PATH="/volume1/docker/stacks/homeassistant"

mkdir -p $STACK_PATH/config
```

## Deploy via Portainer

1. Go to **Stacks → Add stack**
2. Choose **Repository** as the build method
3. Set:
   - **Repository URL:** `https://github.com/isaackehle/iac.git`
   - **Repository reference:** `refs/heads/main`
   - **Compose path:** `homeassistant/docker-compose.yml`
4. Under **Environment variables**, fill in:
   - `TZ` — timezone (e.g., `America/New_York`)
   - `TS_AUTHKEY` — Tailscale auth key (optional, for future sidecar integration)
   - `TS_CERT_DOMAIN` — Tailscale MagicDNS domain (auto-derived as `homeassistant.${TS_TAILNET_DOMAIN}`)
5. Click **Deploy the stack**

---

## Deploy via SSH (Recommended for GitOps)

> **Recommended:** `scripts/deploy.sh all homeassistant <ssh-host>` from the repo root handles everything in one step.

### Prerequisites

- SSH access to the NAS (e.g., `nas` alias in `~/.ssh/config`)
- The `scripts/deploy.sh` and `scripts/gen-env.sh` tools available on your laptop
- The central secrets file `iac-secrets.env` with `TZ` and `TS_AUTHKEY` set

### One-Line Deployment

```shell
cd ~/code/isaackehle/iac
scripts/deploy.sh all homeassistant nas
```

This single command does:

1. Generates `homeassistant/env.txt` from `iac-secrets.env`
2. Creates `/volume1/docker/stacks/homeassistant/config` on the NAS
3. Copies `docker-compose.yml` and `env.txt` via SCP
4. Runs `docker compose up -d` on the NAS
5. Applies the host-level Tailscale serve mapping for port 8123

### Step-by-Step (if you need more control)

```shell
# 1. Generate env.txt locally
scripts/gen-env.sh homeassistant

# 2. Create directories on the NAS
ssh nas "mkdir -p /volume1/docker/stacks/homeassistant/config"

# 3. Push files to the NAS
scp -O homeassistant/docker-compose.yml nas:/volume1/docker/stacks/homeassistant/
scp -O homeassistant/env.txt nas:/volume1/docker/stacks/homeassistant/

# 4. Start the stack
ssh nas "cd /volume1/docker/stacks/homeassistant && docker compose up -d"

# 5. Apply Tailscale serve mapping
ssh nas "sudo tailscale serve --bg --https=8123 http://127.0.0.1:8123"
```

### Verify Deployment

```shell
# Check container is running
ssh nas "docker ps | grep homeassistant"

# Check logs
ssh nas "docker logs --tail 50 homeassistant"

# Verify Home Assistant is accessible
curl -v https://homeassistant.tail303fda.ts.net
```

---

## Apply Tailscale Serve Mapping

After deploying the stack, you must apply the host-level Tailscale serve mapping:

```shell
# From your laptop:
scripts/serve-all.sh <ssh-host>

# Or apply just the homeassistant mapping:
ssh <ssh-host> "sudo tailscale serve --bg --https=8123 http://127.0.0.1:8123"
```

## What the Stack Contains

| Container | Image | Role |
|-----------|-------|------|
| `homeassistant` | `ghcr.io/home-assistant/home-assistant:stable` | Home Assistant Core — smart home automation platform |

The container runs with `network_mode: host` — it binds directly to the NAS host's network interfaces, not a Docker network. This is required for Home Assistant's device discovery to work.

## First-Run Home Assistant Setup

1. Wait for the stack to start (check `docker ps` for the container)
2. From a device on your tailnet, visit `https://homeassistant.${TS_TAILNET_DOMAIN}`
3. Complete the Home Assistant setup wizard:
   - Create your account
   - Name your home
   - Add integrations (lights, sensors, cameras, etc.)
4. Verify the setup:

   ```shell
   docker logs homeassistant | grep "Setup completed"
   ```

## Persistent Data

| Host Path | Container Path | Contents |
|-----------|----------------|----------|
| `$STACK_PATH/config` | `/config` | Home Assistant configuration, add-ons, automations, integrations |

**Critical:** The `config` directory contains your entire Home Assistant setup — all automations, integrations, users, and preferences.

## Access

| URL/Endpoint | Description |
|--------------|-------------|
| `https://homeassistant.${TS_TAILNET_DOMAIN}` | Home Assistant Web UI (tailnet-only, via host-level serve) |
| `http://homeassistant.${TS_TAILNET_DOMAIN}:8123` | Home Assistant API (tailnet-only) |
| `<NAS-Tailscale-IP>:8123` | Direct Tailscale IP access |
| `<NAS-LAN-IP>:8123` | LAN access (if NAS is on same network) |

## Common Home Assistant Operations

### View Logs

```shell
docker logs homeassistant
```

### Restart Home Assistant

```shell
docker restart homeassistant
```

### Check Integration Status

```shell
docker exec homeassistant ha core info  # Requires Home Assistant CLI installed
```

### Backup Configuration

```shell
# From the NAS shell:
docker exec homeassistant tar czf /volume1/docker/stacks/homeassistant/backup.tar.gz /config

# Or copy the config directory directly:
cp -r /volume1/docker/stacks/homeassistant/config /volume1/backups/homeassistant-config-$(date +%Y%m%d)
```

## Backups

Include `$STACK_PATH/config` in your Synology backup task (Hyper Backup, Syncthing, etc.). This directory contains:

- `configuration.yaml` — main configuration file
- `automations.yaml` — automation rules
- `scripts/` — automation scripts
- `www/` — static files (custom frontend, images)
- `custom_components/` — custom integrations
- `.storage/` — integration state, credentials, secrets

**Critical:** Back up this directory regularly — it's your entire smart home configuration.

## Troubleshooting

### Container Won't Start

1. Check logs:

   ```shell
   docker logs homeassistant
   ```

2. Verify the `config` directory exists and has correct permissions
3. Check if port 8123 is already in use:

   ```shell
   ss -tlnp | grep 8123
   ```

### Can't Access Web UI

1. Verify the Tailscale serve mapping is applied:

   ```shell
   ssh <ssh-host> "sudo tailscale serve status"
   ```

2. Check the container is running:

   ```shell
   docker ps | grep homeassistant
   ```

3. Test from the NAS shell:

   ```shell
   curl http://127.0.0.1:8123
   ```

### Device Discovery Not Working

1. Verify the container is running with `network_mode: host`:

   ```shell
   docker inspect homeassistant | grep NetworkMode
   # Should show: "NetworkMode": "host"
   ```

2. Check that required services are running (MQTT, Zeroconf, etc.)
3. Verify your devices are on the same network as the NAS

### Configuration Errors

1. Check the logs for errors:

   ```shell
   docker logs homeassistant | grep -i error
   ```

2. Verify `configuration.yaml` is valid:

   ```shell
   docker exec homeassistant python -m homeassistant.util.yaml load /config/configuration.yaml
   ```

3. Roll back recent changes if the issue started after a configuration update

## References

- [Home Assistant Documentation](https://www.home-assistant.io/docs/)
- [Home Assistant Docker Image](https://hub.docker.com/r/homeassistant/home-assistant)
- [Home Assistant Configuration](https://www.home-assistant.io/docs/configuration/)
