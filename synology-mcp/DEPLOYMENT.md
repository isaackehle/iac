# Synology MCP Server Deployment Guide

## Overview

This guide shows how to deploy the Synology MCP server via Portainer or directly on the Synology NAS.

## Current Status

- ✅ MCP server configuration created at `~/code/isaackehle/iac/synology-mcp/`
- ✅ Tailscale certificate generated for `voyager.tail303fda.ts.net`
- ✅ Web API command-line tool working (but HTTP endpoint returns error 101)
- ❌ Docker/Container Manager not installed on Synology
- ❌ Portainer not deployed

## Deployment Options

### Option 1: Deploy Docker on Synology First (Recommended)

1. **Install Container Manager Package**
   - Open Package Center on Synology
   - Search for "Container Manager" (formerly Docker)
   - Install the package
   - This will install Docker CLI and enable Docker commands

2. **Deploy MCP Server via CLI**
   ```bash
   # SSH into Synology
   ssh isaac@voyager.tail303fda.ts.net
   
   # Create stack directory
   mkdir -p /volume1/docker/stacks/synology-mcp/config
   
   # Copy files from your Mac
   scp ~/code/isaackehle/iac/synology-mcp/docker-compose.yml isaac@voyager.tail303fda.ts.net:/volume1/docker/stacks/synology-mcp/
   scp ~/code/isaackehle/iac/synology-mcp/.env isaac@voyager.tail303fda.ts.net:/volume1/docker/stacks/synology-mcp/
   
   # Deploy
   cd /volume1/docker/stacks/synology-mcp
   docker compose up -d
   
   # Verify
   docker compose ps
   docker compose logs synology-mcp
   ```

### Option 2: Deploy Portainer First, Then MCP Server

1. **Deploy Portainer on Synology**
   ```bash
   # After installing Container Manager
   mkdir -p /volume1/docker/stacks/portainer/config
   cd /volume1/docker/stacks/portainer
   
   # Use the existing portainer stack from ~/code/isaackehle/iac/portainer/
   # Copy docker-compose.yml and .env
   docker compose up -d
   ```

2. **Access Portainer**
   - Navigate to `http://voyager.tail303fda.ts.net:9000`
   - Complete initial setup
   - Deploy MCP server via Portainer UI

### Option 3: Use SSH-Based MCP Server (No Docker Required)

Since the Web API HTTP endpoint returns error 101, we can use an SSH-based approach:

1. **Create SSH-based MCP server**
   - Uses SSH to execute `synowebapi` commands directly
   - No Docker required
   - More reliable for DSM 7.3.2

2. **Implementation**
   - Create a custom MCP server that connects via SSH
   - Executes Web API commands through the synowebapi binary
   - Bypasses the HTTP endpoint issue

## Next Steps

1. **Install Container Manager on Synology** (required for Docker deployment)
2. **Choose deployment option** (CLI, Portainer, or SSH-based)
3. **Deploy the MCP server**
4. **Verify connectivity**

## Troubleshooting

### Web API Error 101

The HTTP endpoint returns error 101 even though the command-line tool works. This is a DSM 7.3.2 limitation.

**Solution**: Use Option 3 (SSH-based MCP server) or restart DSM web service to load Web API modules.

### Certificate Issues

If you see certificate errors when connecting to `https://voyager.tail303fda.ts.net:5001`:

1. Ensure Tailscale certificate is installed
2. Certificate files are in `/usr/syno/etc/certificate/_archive/<ID>/`
3. Restart nginx: `sudo /usr/bin/nginx -s reload`

## Files Created

- `~/code/isaackehle/iac/synology-mcp/docker-compose.yml` - Docker Compose configuration
- `~/code/isaackehle/iac/synology-mcp/.env` - Environment variables with credentials
- `~/code/isaackehle/iac/synology-mcp/.env.example` - Template for .env
- `~/code/isaackehle/iac/synology-mcp/PORTAINER.md` - Deployment documentation
- `~/code/isaackehle/iac/scripts/deploy-synology-mcp.sh` - Deployment script
