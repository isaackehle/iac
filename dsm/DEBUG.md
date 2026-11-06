# dsm — troubleshooting

## DSM Tailscale Sidecar

This stack runs a Tailscale sidecar container for DSM itself, giving it a tailnet hostname.

### Common issues

#### Tailscale service won't start

```bash
cd dsm
docker compose -f docker-compose.yml logs dsm-tailscale
```

#### State directory issues

```bash
cd dsm
ls -la state/
```

#### Serve.json mount issues

```bash
cd dsm
cat serve.json
```

#### DSM unreachable from tailnet

Check `scripts/gen-env.sh dsm` to ensure `TS_AUTHKEY` is set, then:

```bash
# Check if DSM is running on the host
# DSM default web port: 5080 (configurable)
# From the NAS:
sudo tailscale ip dsm
```

### Boot tasks

If DSM's native `tailscale serve` is also configured:

```bash
# On DSM's boot:
sudo tailscale serve --bg http://127.0.0.1:5080
```

### Maintenance

- The `state/` volume stores Tailscale state - don't delete it
- The `serve.json` file is mounted read-only from the NAS
- If the tailnet hostname stops resolving, run `scripts/deploy.sh push dsm` to refresh the sidecar configuration

### Known Issues & Fixes

#### Container stuck in "Created" state (2026-11-06)

**Symptom**: `docker ps` shows `dsm-tailscale` as `Created` (not `Running`). Health check reports `ContainerDown`.

**Root cause**: The stack directory on the NAS was empty — `docker-compose.yml` and `serve.json` were missing. The deploy script pushed `serve.json` to `ts-config/serve.json` (correct), but the docker-compose.yml was mounting `./serve.json:/config/serve.json:ro`, expecting the file in the stack root.

**Fix**: Changed the volume mount from `./serve.json:/config/serve.json:ro` to `./ts-config:/config` (matching how other stacks like `ha` handle serve.json). Redeploy with `scripts/deploy.sh all dsm nas`.

**Verify**:
```bash
# Check container status on NAS
ssh nas '/volume1/@appstore/ContainerManager/usr/bin/docker ps --filter "name=dsm-tailscale"'

# Verify endpoint responds (400 from plain HTTP to HTTPS is expected)
curl -sk https://dsm.tail303fda.ts.net/
```

#### Stack directory missing on NAS

**Symptom**: `ls /volume1/docker/stacks/dsm/` shows only `state/` and `ts-config/` directories.

**Fix**: Ensure the stack directory exists and deploy:
```bash
# On NAS:
mkdir -p /volume1/docker/stacks/dsm
# Then deploy from iac repo:
scripts/deploy.sh all dsm nas
```
