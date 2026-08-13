# Synology MCP — Portainer Stack Deployment

> **Recommended:** `scripts/deploy.sh all synology-mcp <ssh-host>` from the repo root handles directory setup, `.env` generation, file placement, and bringing the stack up in one step — see root `README.md`/`QUICKSTART.md`. The manual steps below are the equivalent broken out.

## Overview

The Synology MCP (Model Context Protocol) server provides AI agents with programmatic access to Synology NAS resources via Docker. It connects to the NAS DSM (DiskStation Manager) API to perform file operations, system management, and other administrative tasks.

## Directory Setup (on Synology NAS)

```shell
STACK_PATH="/volume1/docker/stacks/synology-mcp"

mkdir -p $STACK_PATH
```

## Deploy via Portainer

1. Go to **Stacks → Add stack**
2. Choose **Repository** as the build method
3. Set:
   - **Repository URL:** `https://github.com/isaackehle/iac.git`
   - **Repository reference:** `refs/heads/main`
   - **Compose path:** `synology-mcp/docker-compose.yml`
4. Under **Environment variables**, fill in:
   - `SYNOLOGY_HOST` — Tailscale MagicDNS hostname of the Synology NAS (e.g., `synology.tail303fda.ts.net`)
   - `SYNOLOGY_PORT` — HTTPS port for Synology DSM (typically `5001`)
   - `SYNOLOGY_SSL` — Whether to use SSL (`true`)
   - `SYNOLOGY_USERNAME` — DSM username for MCP authentication
   - `SYNOLOGY_PASSWORD` — DSM password (stored in central secrets file)
   - `SYNOLOGY_OTP_CODE` — 2FA OTP code if 2FA is enabled (stored in central secrets file)
5. Click **Deploy the stack**

---

## Deploy via SSH (Recommended for GitOps)

> **Recommended:** `scripts/deploy.sh all synology-mcp <ssh-host>` from the repo root handles everything in one step.

### Prerequisites

- SSH access to the NAS (e.g., `nas` alias in `~/.ssh/config`)
- The `scripts/deploy.sh` and `scripts/gen-env.sh` tools available on your laptop
- The central secrets file `iac-secrets.env` with `SYNOLOGY_HOST`, `SYNOLOGY_PORT`, `SYNOLOGY_SSL`, `SYNOLOGY_USERNAME`, `SYNOLOGY_PASSWORD`, and `SYNOLOGY_OTP_CODE`

### One-Line Deployment

```shell
cd ~/code/isaackehle/iac
scripts/deploy.sh all synology-mcp nas
```

This single command does:

1. Generates `synology-mcp/.env` from `iac-secrets.env`
2. Creates `/volume1/docker/stacks/synology-mcp` on the NAS
3. Copies `docker-compose.yml` and `.env` via SCP
4. Runs `docker compose up -d` on the NAS

### Step-by-Step (if you need more control)

```shell
# 1. Generate .env locally
scripts/gen-env.sh synology-mcp

# 2. Create directories on the NAS
ssh nas "mkdir -p /volume1/docker/stacks/synology-mcp"

# 3. Push files to the NAS
scp -O synology-mcp/docker-compose.yml nas:/volume1/docker/stacks/synology-mcp/
scp -O synology-mcp/.env nas:/volume1/docker/stacks/synology-mcp/

# 4. Start the stack
ssh nas "cd /volume1/docker/stacks/synology-mcp && docker compose up -d"
```

### Verify Deployment

```shell
# Check container is running
ssh nas "docker ps | grep synology-mcp"

# Check logs
ssh nas "docker logs --tail 50 synology-mcp"

# Test connectivity to NAS
ssh nas "docker exec synology-mcp curl -k https://synology.tail303fda.ts.net:5001"
```

---

## What the Stack Contains

| Container | Image | Role |
|-----------|-------|------|
| `synology-mcp` | `ghcr.io/modelcontextprotocol/servers/synology:latest` | MCP server — provides AI agents with programmatic access to Synology NAS |

The container runs on a bridge network (`synology_mcp_net`) and connects to the Synology NAS via its Tailscale hostname.

## First-Run Synology MCP Setup

1. Wait for the container to start:

   ```shell
   docker ps | grep synology-mcp
   docker logs synology-mcp
   ```

2. Verify connectivity to the NAS:

   ```shell
   docker exec synology-mcp curl -k https://synology.tail303fda.ts.net:5001
   ```

3. Check MCP server logs for successful initialization:

   ```shell
   docker logs synology-mcp | grep -i "ready\|started"
   ```

## Access

The Synology MCP server is not directly accessible via HTTP/HTTPS — it's an MCP server that connects to other tools (like Hermes Agent, Claude Desktop, etc.) via stdio or SSE.

### From Hermes Agent

Configure your Hermes setup to use the Synology MCP server:

```yaml
mcpServers:
  synology:
    command: "docker"
    args:
      - "exec"
      - "synology-mcp"
      - "mcp-server-synology"
```

### From Claude Desktop

Add to your `claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "synology": {
      "command": "docker",
      "args": ["exec", "synology-mcp", "mcp-server-synology"]
    }
  }
}
```

## Environment Variables Reference

| Variable | Description | Example |
|----------|-------------|---------|
| `SYNOLOGY_HOST` | Tailscale MagicDNS hostname of the Synology NAS | `synology.tail303fda.ts.net` |
| `SYNOLOGY_PORT` | HTTPS port for Synology DSM | `5001` |
| `SYNOLOGY_SSL` | Whether to use SSL | `true` |
| `SYNOLOGY_USERNAME` | DSM username for authentication | `admin` |
| `SYNOLOGY_PASSWORD` | DSM password (from secrets file) | `***` |
| `SYNOLOGY_OTP_CODE` | 2FA OTP code if enabled (from secrets file) | `***` |

## Backups

The Synology MCP server is stateless — it doesn't store any data locally. All configuration is passed via environment variables at runtime.

## Troubleshooting

### Container Won't Start

1. Check logs:

   ```shell
   docker logs synology-mcp
   ```

2. Verify all required environment variables are set
3. Check network connectivity to the NAS:

   ```shell
   docker exec synology-mcp ping synology.tail303fda.ts.net
   ```

### Can't Connect to NAS

1. Verify the `SYNOLOGY_HOST` is correct and reachable via Tailscale
2. Check the NAS is online and DSM is running
3. Verify the username/password are correct
4. If 2FA is enabled, ensure `SYNOLOGY_OTP_CODE` is set correctly

### MCP Server Not Responding

1. Check the container is running:

   ```shell
   docker ps | grep synology-mcp
   ```

2. Verify the MCP server process is running inside the container:

   ```shell
   docker exec synology-mcp ps aux | grep mcp
   ```

3. Check logs for errors:

   ```shell
   docker logs synology-mcp --tail 50
   ```

### Permission Denied Errors

1. Verify the DSM username has appropriate permissions
2. Check that the user has access to the resources being accessed
3. Ensure the password hasn't expired or been changed

## References

- [Model Context Protocol Documentation](https://modelcontextprotocol.io/)
- [Synology MCP Server GitHub](https://github.com/modelcontextprotocol/servers)
- [Synology DSM API Documentation](https://www.synology.com/en-global/support/documentation/DownloadCenter)
