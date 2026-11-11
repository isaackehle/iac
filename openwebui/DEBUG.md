# Debug Commands

Quick reference for troubleshooting the OpenWebUI stack.

## Container Access

```shell
docker exec -it openwebui-ts sh
docker exec -it openwebui sh
docker exec -it openwebui-config sh
```

## Tailscale Serve Configuration

```shell
# Inside the sidecar:
cat /config/serve.json
tailscale serve status
```

## Container Logs

```shell
docker logs openwebui
docker logs openwebui-ts
docker logs openwebui-config
docker logs -f openwebui
```

## Tailscale Connectivity

```shell
docker exec openwebui-ts tailscale status
docker exec openwebui-ts tailscale ip
docker exec openwebui-ts tailscale serve status
```

## OpenWebUI-Specific Commands

```shell
# Check if OpenWebUI is responding inside the container
docker exec openwebui curl -sf http://localhost:8080/health

# View Ollama engine config
docker exec openwebui-config cat /scripts/configure-ollama.sh
```

## Access

- **Via Tailscale:** `https://openwebui.${TS_TAILNET_DOMAIN}`

## Restart Services

```shell
docker compose -f /volume1/docker/stacks/openwebui/docker-compose.yml restart
docker compose -f /volume1/docker/stacks/openwebui/docker-compose.yml restart openwebui
docker compose -f /volume1/docker/stacks/openwebui/docker-compose.yml restart openwebui-ts
```

## Config Files

| Purpose                | Host Path                                               |
| ---------------------- | ------------------------------------------------------- |
| OpenWebUI data         | `/volume1/docker/stacks/openwebui/data`                 |
| Tailscale serve config | `/volume1/docker/stacks/openwebui/ts-config/serve.json` |
| Tailscale state        | `/volume1/docker/stacks/openwebui/ts-state`             |

## Troubleshooting

### openwebui-tailscale: "connection refused" (proxy returns 000)

**Symptom**: `https://openwebui.tail303fda.ts.net/` returns HTTP 000 (connection refused/timed out).

**Root cause**: The `tailscale` service in `docker-compose.yml` was missing `network_mode: host`. Without it, the Tailscale sidecar runs in its own Docker
network namespace and cannot reach 127.0.0.1:8080 on the host (it tries to reach port 8080 within the sidecar container itself, not on the host).

**Fix**: Add `network_mode: host` to the `tailscale` service in `docker-compose.yml`.

> **Superseded 2026-11-10 — do not re-add host mode.** `primary` borrows the sidecar's
> namespace, so `127.0.0.1:8080` is reachable without it. Host mode put OpenWebUI in the
> NAS's own namespace, where it had no route to the fleet LiteLLM gateways on `100.x`
> (curl from the container returned `000`). The sidecar is back on its pinned bridge and
> LiteLLM is reached through `TS_OUTBOUND_HTTP_PROXY_LISTEN` (see `docker-compose.yml`).

**Steps**:

```bash
# 1. Edit docker-compose.yml — add network_mode: host to the tailscale service
# 2. Redeploy:
scripts/deploy.sh all openwebui nas
# 3. Verify:
curl -sk -o /dev/null -w "HTTP %{http_code}\n" https://openwebui.tail303fda.ts.net/
```

**Note**: The openwebui container takes ~90 seconds to initialize (health: starting → healthy). Do not assume failure during this window.

---

### Portainer stack conflict (recurring)

**Symptom**: Deploy fails with `Conflict. The container name "/<id>_openwebui" is already in use by container`.

**Root cause**: A Portainer-managed stack was deployed via the Portainer UI, creating containers with conflicting names.

**Fix**: Remove conflicting containers and redeploy via the deploy script:

```bash
ssh nas '/volume1/@appstore/ContainerManager/usr/bin/docker rm -f openwebui openwebui-tailscale'
scripts/deploy.sh all openwebui nas
```

**Prevention**: Do not deploy the openwebui stack via the Portainer UI. Use `scripts/deploy.sh all openwebui nas` only.

---

### Container name corrections

The existing debug commands reference `openwebui-ts` which does not exist. The actual container names are:

- `openwebui` (primary — serves on port 8080)
- `openwebui-tailscale` (sidecar — Tailscale proxy)
- `openwebui-config` (one-shot config runner)
