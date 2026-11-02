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
