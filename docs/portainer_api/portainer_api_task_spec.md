# Hermes Task Spec: Syncthing + Tailscale Deploy Automation

## Objective

Build or update scripts that deploy a Syncthing stack on Synology via Docker Compose, including Tailscale Serve configuration and validation.

## Inputs

- `PROJECT_DIR=/volume1/docker/stacks/syncthing`
- `COMPOSE_FILE=docker_compose.yaml`
- `ENV_FILE=.env`
- `SERVE_TEMPLATE=templates/serve.json.tpl`
- `SERVE_FILE=serve.json`
- `TAILNET_HOSTNAME=syncthing.YOUR-TAILNET.ts.net`
- `TZ`
- `SYNC_PUID`
- `SYNC_PGID`
- `TS_AUTHKEY`
- `TS_CERT_DOMAIN`

## Required behavior

- Back up current compose, env, and serve config before changes.
- Add or preserve `STGUIADDRESS=0.0.0.0:8384` in the Syncthing container.
- Render `serve.json` from a template and replace `${TS_CERT_DOMAIN}` with the resolved literal hostname before startup.
- Optionally render the compose file if the deployment needs baked-in values.
- Bring the stack down cleanly before redeploy.
- Pull latest images.
- Start the stack again.
- Validate Syncthing health and Tailscale Serve access.
- Fail loudly if the GUI is unreachable or the serve config is invalid.

## Acceptance criteria

- Syncthing starts successfully.
- Syncthing GUI is reachable on `127.0.0.1:8384` inside the container network.
- Tailscale Serve exposes the GUI over the tailnet hostname.
- Logs do not show startup or serve config errors.
- The deployment can be repeated safely.

## Validation steps

- `docker ps`
- `docker inspect syncthing`
- `curl -f http://127.0.0.1:8384/`
- `docker logs syncthing`
- `docker logs ts-syncthing`

## Notes

- Do not assume Tailscale will expand environment variables inside JSON.
- Generate `serve.json` from a template or write the resolved hostname directly.
- Keep the stack source of truth in the compose files, not the UI.
- Separate deploy-time templating from runtime container environment.
