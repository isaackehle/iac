# Tailscale Interface Validation

## Overview

Portainer is configured to expose itself via Tailscale with HTTPS support. This document describes how to validate both access methods.

## Access Methods

### Method 1: HTTP via Tailscale IP (Default)

**URL:** `http://voyager.tail303fda.ts.net:9000`

**Use Case:**

- Quick access without TLS
- Testing and debugging
- Internal network access

**Steps:**

1. Ensure Tailscale is connected: `tailscale status`
2. Navigate to: `http://voyager.tail303fda.ts.net:9000`
3. Portainer should be accessible

### Method 2: HTTPS via Tailscale Hostname (Recommended)

**URL:** `https://portainer.tail303fda.ts.net`

**Use Case:**

- Production access
- Secure communication
- External access (via Tailscale)

**Requirements:**

- Tailscale `serve` configured with TLS certificates
- Portainer container running with Tailscale sidecar
- `TS_SERVE_CONFIG` pointing to serve.json

**Steps:**

1. Ensure Tailscale is connected: `tailscale status`
2. Navigate to: `https://portainer.tail303fda.ts.net`
3. Accept the self-signed certificate (or use Let's Encrypt if configured)
4. Portainer should be accessible

## Validation Checklist

After deploying Portainer, validate both access methods:

### 1. Verify Containers Running

```shell
# Check container status
sudo /var/packages/ContainerManager/target/tool/docker ps | grep portainer

# Expected output:
# ts-portainer      tailscale/tailscale:latest    "up"
# portainer         portainer/portainer-ce:latest "up"
```

### 2. Verify Tailscale Status

```shell
# Check Tailscale device status
sudo /var/packages/ContainerManager/target/tool/docker exec ts-portainer tailscale status

# Expected output:
# USER portainer (100.x.x.x)    up      tail303fda.ts.net
```

### 3. Validate HTTP Access

```shell
# Test HTTP endpoint
curl -sk http://voyager.tail303fda.ts.net:9000

# Expected: HTTP 200 response with Portainer HTML
```

### 4. Validate HTTPS Access

```shell
# Test HTTPS endpoint (ignore certificate warning)
curl -sk https://portainer.tail303fda.ts.net

# Expected: HTTP 200 response with Portainer HTML
```

### 5. Verify Tailscale Serve Config

```shell
# Check serve.json content
sudo /var/packages/ContainerManager/target/tool/docker exec ts-portainer cat /config/serve.json

# Expected:
# {
#   "default": {
#     "https": true,
#     "port": 9000
#   }
# }
```

## Troubleshooting

### Portainer Not Accessible via HTTP

**Symptoms:** `curl http://voyager.tail303fda.ts.net:9000` hangs or fails

**Checks:**

1. Is Portainer container running? `docker ps | grep portainer`
2. Is port 9000 exposed? `docker port portainer`
3. Is Tailscale connected? `tailscale status`

**Fix:**

```shell
# Restart Portainer stack
sudo /var/packages/ContainerManager/target/tool/docker compose -f /volume1/docker/stacks/portainer/docker-compose.yml up -d
```

### Portainer Not Accessible via HTTPS

**Symptoms:** `curl https://portainer.tail303fda.ts.net` fails

**Checks:**

1. Is Tailscale sidecar running? `docker ps | grep ts-portainer`
2. Is Tailscale connected? `docker exec ts-portainer tailscale status`
3. Is serve.json configured? `docker exec ts-portainer cat /config/serve.json`

**Fix:**

```shell
# Verify serve.json
cat /volume1/docker/stacks/portainer/ts-config/serve.json

# Should contain:
# {
#   "default": {
#     "https": true,
#     "port": 9000
#   }
# }

# Restart Tailscale sidecar
sudo /var/packages/ContainerManager/target/tool/docker compose restart ts-portainer
```

### Certificate Warnings

**Symptoms:** Browser shows certificate warning for `https://portainer.tail303fda.ts.net`

**Explanation:** This is expected - Tailscale generates self-signed certificates for `serve` endpoints.

**Options:**

1. **Accept the certificate** (quick, for testing)
2. **Use a custom domain with Let's Encrypt** (production)
3. **Add the certificate to your trust store** (enterprise)

### Tailscale Device Not Online

**Symptoms:** `tailscale status` shows portainer device as offline

**Checks:**

1. Is the sidecar container running? `docker ps | grep ts-portainer`
2. Is the auth key valid? Check `.env` file
3. Is there network connectivity? `ping discovery.tailscale.com`

**Fix:**

```shell
# Check Tailscale logs
sudo /var/packages/ContainerManager/target/tool/docker logs ts-portainer

# Regenerate auth key if needed
# Visit: https://login.tailscale.com/admin/keys
```

## Expected Behavior

### HTTP Access (`http://voyager.tail303fda.ts.net:9000`)

- ✅ Direct connection to Portainer container
- ✅ No TLS encryption
- ✅ Fast, no certificate overhead
- ⚠️ Not recommended for production

### HTTPS Access (`https://portainer.tail303fda.ts.net`)

- ✅ Encrypted connection via Tailscale
- ✅ Self-signed certificate (expected)
- ✅ Uses Tailscale's TLS termination
- ✅ Recommended for production

## Security Notes

1. **Private Network:** Both access methods are only available via Tailscale
2. **Authentication:** Portainer has its own admin authentication
3. **TLS:** HTTPS via Tailscale provides encryption in transit
4. **Firewall:** No ports need to be open on the NAS firewall (Tailscale handles this)

## Next Steps

After validation:

1. Access Portainer UI and complete initial setup
2. Create admin user
3. Deploy Synology MCP server stack
4. Configure backups and monitoring
