# Portainer — Portainer Server Stack Deployment

> Recommended: `scripts/deploy.sh all portainer <ssh-host>` from the repo
> root handles directory setup, `.env` generation, file placement, and
> bringing the stack up in one step — see root `README.md`/`QUICKSTART.md`.
> The manual steps below are the equivalent broken out. Note: this is the
> one stack where you're bootstrapping Portainer itself, so the very first
> deploy has to happen before Portainer exists to deploy *from*.

Deploy the Portainer server itself via Portainer (deploying Portainer with Portainer).

## Prerequisites

- Portainer connected to your Docker environment (local or remote host)
- Tailscale network configured on target machine
- SSH access or File Station access to Synology NAS

## Directory Setup (on Synology NAS)

```shell
STACK_PATH="/volume1/docker/stacks/portainer"

mkdir -p $STACK_PATH/{config,data}
chown -R 1043:100 $STACK_PATH/config # Portainer container runs as uid 1043
chown -R 1043:100 $STACK_PATH/data
```

Copy `docker-compose.yml` and `.env.example` into `$STACK_PATH`. Rename `.env.example` to `.env` and populate the values.

## Environment Variables (from .env.example)

| Variable | Description | Example |
|----------|-------------|---------|
| `TS_AUTHKEY` | Tailscale auth key for sidecar container | `tskey-...` |
| `TS_CERT_DOMAIN` | Custom domain for HTTPS routing via Tailscale serve | `portainer.${TS_TAILNET_DOMAIN}` |
| `TS_HOSTNAME_PORTAINER` | Tailscale hostname (must match portainer service name) | `portainer` |

## Deployment Steps

### 1. Deploy via Portainer UI

1. Log into Portainer
2. Select your Docker environment
3. Click **Stacks** → **Add stack**
4. Choose **Web editor**
5. Copy contents of `docker-compose.yml` from this directory
6. Set **Working directory** to `/volume1/docker/stacks/portainer` (where compose file lives)
7. Select the `.env` file path: `/volume1/docker/stacks/portainer/.env`
8. Click **Deploy the stack**

### 2. Initial Access

After deployment, Portainer will be accessible at:
- **Container IP**: `http://<container-ip>:9000` (first-time setup only)
- **Tailscale serve**: After first run completes and Tailscale sidecar is ready, access via custom domain if configured

### 3. Initial Configuration

On first launch, you'll be prompted to:
1. Create admin user (username/password)
2. Connect Portainer to external environments (optional)

## Serving via Tailscale

After initial setup, `serve.json` routes traffic through Tailscale's HTTP proxy:

```json
{
  "Web": {
    "${TS_CERT_DOMAIN}:443": {
      "Handlers": {
        "/": {
          "Proxy": "http://127.0.0.1:9000"
        }
      }
    }
  }
}
```

Copy the rendered `serve.json` (from `serve.json.tmpl` via
`scripts/gen-env.sh portainer`) into `$STACK_PATH/ts-config/` — the sidecar
mounts the whole `ts-config` directory at `/config`. Tailscale will
automatically serve the container at your custom domain.

## Verification

Check container status:

```shell
docker compose -f /volume1/docker/stacks/portainer/docker-compose.yml ps
```

View logs:

```shell
docker compose -f /volume1/docker/stacks/portainer/docker-compose.yml logs portainer
```

## Updates

To update the stack, edit `docker-compose.yml` in Portainer's web editor and click **Update**. Alternatively, use CLI:

```shell
cd /volume1/docker/stacks/portainer
docker compose pull
docker compose up -d
```
