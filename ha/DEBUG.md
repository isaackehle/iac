# ha — troubleshooting

## HA Tailscale Proxy

This stack runs a Tailscale proxy for Home Assistant, exposing it on the tailnet at `ha.tail303fda.ts.net`.

### Common issues

#### HA proxy reports "EndpointDown"

**Symptom**: Health checks report `EndpointDown` for `https://ha.tail303fda.ts.net/`.

**Diagnosis**: The proxy is actually working — curl returns `400: Bad Request` from the Tailscale proxy itself (not a connection failure). The HA box is alive and serving content.

**Root cause**: The health check was failing because the proxy returns 400 for plain HTTP requests to an HTTPS endpoint. This is **not a failure** — it's expected behavior from the Tailscale proxy.

**Verify**:
```bash
# Check HA box is alive
ssh ha 'uptime'

# Check HA is serving content
ssh ha 'curl -sk https://127.0.0.1:8123/'

# Check proxy responds (400 from plain HTTP to HTTPS is expected)
curl -sk https://ha.tail303fda.ts.net/
```

#### HA box goes offline

**Symptom**: Proxy returns connection refused or timeout.

**Root cause**: The HA box (Raspberry Pi) goes offline periodically. The docker-compose.yml notes: *"Its own Tailscale add-on node ('homeassistant') has been unreliable (offline since 2026-09-24)."*

**Fix**: Check the HA box directly:
```bash
ssh ha 'curl -sk https://127.0.0.1:8123/api/'
```

If HA is offline, check the Pi's power and network connectivity.

### Boot tasks

The HA proxy forwards to `{{HA_LAN_IP}}:8123`. Ensure `HA_LAN_IP` in `.env` points to your HA box's LAN IP.

### Maintenance

- The `ts-state/` volume stores Tailscale state - don't delete it
- The `ts-config/` directory contains `serve.json` for proxy routing
- If the tailnet hostname stops resolving, run `scripts/deploy.sh push ha` to refresh the proxy configuration