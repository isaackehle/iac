# Syncthing + Tailscale Stack Deploy Runbook

## Purpose

Deploy or redeploy a Syncthing stack on Synology using Docker Compose, with Tailscale Serve exposing the Syncthing GUI securely over the tailnet.

## Files

- `docker_compose.yaml`
- `.env`
- `templates/serve.json.tpl`
- `serve.json`
- `templates/docker_compose.yaml.tpl` (optional)

## Assumptions

- Project root is `/volume1/docker/stacks/syncthing`
- Syncthing GUI listens on port `8384`
- Tailscale shares the Syncthing network namespace
- The Tailnet hostname is available as a known value or generated before deployment

## Preflight

- [ ] Confirm SSH access to the NAS.
- [ ] Confirm Docker is installed and working.
- [ ] Confirm the project directory exists:

  ```shell
  /volume1/docker/stacks/syncthing
  ```

- [ ] Confirm the `.env` file contains:
  - `TZ`
  - `SYNC_PUID`
  - `SYNC_PGID`
  - `TS_AUTHKEY`
  - `TS_CERT_DOMAIN`
- [ ] Confirm the `serve.json` file will be rendered with the resolved Tailnet hostname.
- [ ] Confirm no one is editing the same stack in Portainer or the DSM UI.

## Backup

- [ ] SSH into the NAS.
- [ ] Change into the project directory:

  ```shell
  cd /volume1/docker/stacks/syncthing
  ```

- [ ] Create a timestamped backup directory:

  ```shell
  BACKUP_DIR="./backup-$(date +%Y%m%d-%H%M%S)"
  mkdir -p "$BACKUP_DIR"
  ```

- [ ] Back up the compose file:

  ```shell
  cp docker_compose.yaml "$BACKUP_DIR/"
  ```

- [ ] Back up the env file:

  ```shell
  cp .env "$BACKUP_DIR/"
  ```

- [ ] Back up the Tailscale Serve config if already present:

  ```shell
  [ -f serve.json ] && cp serve.json "$BACKUP_DIR/"
  ```

## Templating script

- [ ] Render `serve.json` from a template, substituting `TS_CERT_DOMAIN` into a literal hostname at deploy time:

  ```shell
  #!/usr/bin/env bash
  set -euo pipefail

  PROJECT_DIR="/volume1/docker/stacks/syncthing"
  TEMPLATE_DIR="${PROJECT_DIR}/templates"
  OUTPUT_DIR="${PROJECT_DIR}"

  export TZ="${TZ:?TZ is required}"
  export SYNC_PUID="${SYNC_PUID:?SYNC_PUID is required}"
  export SYNC_PGID="${SYNC_PGID:?SYNC_PGID is required}"
  export TS_AUTHKEY="${TS_AUTHKEY:?TS_AUTHKEY is required}"
  export TS_CERT_DOMAIN="${TS_CERT_DOMAIN:?TS_CERT_DOMAIN is required}"

  mkdir -p "${OUTPUT_DIR}"

  envsubst '${TS_CERT_DOMAIN}' \
    < "${TEMPLATE_DIR}/serve.json.tpl" \
    > "${OUTPUT_DIR}/serve.json"
  ```

- [ ] If you choose to render the compose file too, use `envsubst` only for values you intend to bake into the final file:

  ```shell
  envsubst '${TZ} ${SYNC_PUID} ${SYNC_PGID} ${TS_AUTHKEY} ${TS_CERT_DOMAIN}' \
    < "${TEMPLATE_DIR}/docker_compose.yaml.tpl" \
    > "${OUTPUT_DIR}/docker_compose.yaml"
  ```

## Update files

- [ ] Add or confirm `STGUIADDRESS` in the Syncthing container:

  ```yaml
  environment:
    - TZ=${TZ}
    - PUID=${SYNC_PUID}
    - PGID=${SYNC_PGID}
    - STGUIADDRESS=0.0.0.0:8384
  ```

- [ ] Ensure Syncthing healthcheck remains:

  ```yaml
  healthcheck:
    test: curl -f http://localhost:8384/ || exit 1
  ```

- [ ] Ensure the rendered `serve.json` uses the resolved tailnet hostname as a literal key:

  ```json
  {
    "TCP": {
      "443": {
        "HTTPS": true
      }
    },
    "Web": {
      "syncthing.YOUR-TAILNET.ts.net:443": {
        "Handlers": {
          "/": {
            "Proxy": "http://127.0.0.1:8384"
          }
        }
      }
    }
  }
  ```

## Deploy

- [ ] Stop the stack:

  ```shell
  docker compose -f docker_compose.yaml down
  ```

- [ ] Render `serve.json` before bringing the stack up.
- [ ] Pull latest images:

  ```shell
  docker compose -f docker_compose.yaml pull
  ```

- [ ] Start the stack:

  ```shell
  docker compose -f docker_compose.yaml up -d
  ```

## Validate

- [ ] Confirm containers are running:

  ```shell
  docker ps
  ```

- [ ] Confirm Syncthing is healthy:

  ```shell
  docker inspect syncthing --format '{{json .State.Health}}'
  ```

- [ ] Confirm Syncthing responds on port 8384:

  ```shell
  curl -f http://127.0.0.1:8384/
  ```

- [ ] Review logs:

  ```shell
  docker logs syncthing --tail=100
  docker logs syncthing-tailscale --tail=100
  ```

- [ ] Confirm Tailscale Serve is active and the tailnet URL resolves.

## Rollback

- [ ] Stop the stack:

  ```shell
  docker compose -f docker_compose.yaml down
  ```

- [ ] Restore the backup files:

  ```shell
  cp "$BACKUP_DIR/docker_compose.yaml" .
  cp "$BACKUP_DIR/.env" .
  [ -f "$BACKUP_DIR/serve.json" ] && cp "$BACKUP_DIR/serve.json" .
  ```

- [ ] Bring the previous version back up:

  ```shell
  docker compose -f docker_compose.yaml up -d
  ```

## Hermes notes

- [ ] Treat `STGUIADDRESS` as a required deployment variable for predictable GUI binding.
- [ ] Generate `serve.json` with the actual tailnet hostname before deploy.
- [ ] Validate both the local GUI and the Tailscale-exposed GUI after restart.
- [ ] Do not rely on container-image defaults for GUI binding when using Serve.
- [ ] Keep deploy-time templating separate from runtime container environment variables.
