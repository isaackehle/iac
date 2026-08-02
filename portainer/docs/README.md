# Portainer Documentation

## Overview

This folder contains documentation for deploying and managing Portainer on Synology NAS via Container Manager.

## Core Files

- **`old/compose.yaml`** - Portainer + Tailscale sidecar Docker Compose configuration
- **`.env.example`** - Environment variables template
- **`docker-compose.yml`** - Legacy/simple Portainer configuration (for reference)

## Documentation

### Deployment

- **`CONTAINER-MANAGER-DEPLOY.md`** - Step-by-step deployment guide via Container Manager UI
- **`DEPLOYMENT-CHECKLIST.md`** - Verification checklist for deployment
- **`DEPLOY-GUIDE.md`** - Comprehensive deployment guide

### Security

- **`CHISEL-SECURITY.md`** - Security considerations for chisel private key
- **`DIRECTORY-STRUCTURE.md`** - Directory structure and security best practices

### Migration & Recovery

- **`CONSOLIDATION-PLAN.md`** - Plan for consolidating disk content
- **`DIRECTORY-STRUCTURE.md`** - Recommended directory structure
- **`RECOVERY.md`** - Recovery procedures for Portainer issues

### Configuration

- **`UPDATED-COMPOSE.md`** - Changes made to compose.yaml for secure structure

## Quick Start

1. **Deploy Portainer:**
   - See `CONTAINER-MANAGER-DEPLOY.md`

2. **Deploy MCP Server:**
   - See `~/code/isaackehle/iac/synology-mcp/DEPLOYMENT.md`

## Scripts

- **`~/code/isaackehle/iac/scripts/deploy-portainer.sh`** - Automated deployment script

## Related

- **IAC Repo:** `~/code/isaackehle/iac/`
- **Synology MCP:** `~/code/isaackehle/iac/synology-mcp/`
- **Deployment Plan:** `~/sync/plans/005_portainer_iac_migration.md`
