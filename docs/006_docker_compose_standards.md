# Docker Compose File Standards

This document defines the expected organization and ordering of docker-compose.yml files across the IAC repo.

## File Location

Each stack lives in its own directory under the IAC repo root:

```text
iac/<stack-name>/
├── docker-compose.yml
├── .env.example
├── DEBUG.md
├── INSTALLATION.md
└── serve.json.tmpl (if applicable)
```

## Service Ordering

Services should be ordered by **dependency flow**:

1. **Main application container** (the primary service)
2. **Sidecar containers** (supporting services like Tailscale)
3. **Auxiliary services** (databases, caches, etc. - if any)

### Example: Portainer (with Tailscale sidecar)

```yaml
services:
  # Main application
  portainer:
    image: portainer/portainer-ce:latest
    container_name: portainer
    ...

  # Sidecar (attached to main app's network)
  ts-portainer:
    image: tailscale/tailscale:latest
    container_name: ts-portainer
    ...
```

### Example: Pihole (with Caddy sidecar)

```yaml
services:
  # Main application
  pihole:
    image: pihole/pihole:latest
    container_name: pihole
    ...

  # Sidecar (Caddy for HTTPS/Tailscale serve)
  caddy:
    image: caddy:latest
    container_name: pihole-caddy
    ...
```

## Property Ordering Within Services

Properties should be ordered by **logical grouping** and **frequency of change**:

```yaml
services:
  <service-name>:
    # 1. Identity (rarely changes)
    image: <image>
    container_name: <name>

    # 2. Lifecycle (occasionally changes)
    restart: <policy>
    depends_on:
      - <dependency>

    # 3. Network (depends on other services)
    network_mode: <mode>
    ports:
      - <mapping>
    networks:
      - <network>

    # 4. Storage (changes when data location changes)
    volumes:
      - <mount1>
      - <mount2>

    # 5. Environment (changes frequently with secrets)
    environment:
      - <VAR1>=<value>
      - <VAR2>=<value>

    # 6. Runtime (rarely changes)
    cap_add:
      - <capability>
    devices:
      - <device>
    security_opt:
      - <option>
```

## Volume Mount Ordering

Volumes should be ordered by **importance** and **access pattern**:

1. **Secret mounts** (read-only, critical for security)
2. **State/data mounts** (read-write, persistent data)
3. **Config mounts** (read-only, configuration files)
4. **Temporary mounts** (ephemeral data)

### Example: Portainer volumes

```yaml
volumes:
  # 1. Secrets (critical, read-only)
  - /volume1/docker/portainer-secrets/certs:/certs:ro
  - /volume1/docker/portainer-secrets/chisel:/chisel:ro

  # 2. State (persistent data)
  - /volume1/docker/stacks/portainer/data:/data

  # 3. Tailscale state (persistent but managed by sidecar)
  - /volume1/docker/stacks/portainer/ts-state:/var/lib/tailscale
  - /volume1/docker/stacks/portainer/ts-config:/config
```

## Network Configuration

- **Primary service** defines the network or uses `network_mode: service:<sidecar>`
- **Sidecar** typically defines the network if it's a proxy (Tailscale, Caddy)
- **Dependencies** use `depends_on` to ensure startup order

### Example: Tailscale sidecar pattern

```yaml
services:
  main-app:
    network_mode: service:ts-sidecar
    depends_on:
      - ts-sidecar

  ts-sidecar:
    # Tailscale configuration
    network_mode: bridge
    # ...
```

## Naming Conventions

### Container Names

- **Main application**: `<stack-name>` (e.g., `portainer`, `pihole`)
- **Sidecars**: `<stack-name>-<purpose>` (e.g., `ts-portainer`, `caddy-pihole`)

### Directory Names

- **Stack directory**: `<stack-name>` (e.g., `portainer/`, `pihole/`)
- **Data directory**: `/volume1/docker/stacks/portainer/data/`
- **IAC reference**: `/volume1/docker/stacks/portainer/iac/`

## Example: Complete Portainer Compose

```yaml
version: "3.8"

services:
  # Main application
  portainer:
    image: portainer/portainer-ce:latest
    container_name: portainer
    restart: always
    security_opt:
      - no-new-privileges:true
    network_mode: service:ts-portainer
    depends_on:
      - ts-portainer
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - /volume1/docker/stacks/portainer/data:/data

  # Tailscale sidecar
  ts-portainer:
    image: tailscale/tailscale:latest
    container_name: ts-portainer
    restart: unless-stopped
    environment:
      - TS_HOSTNAME=${TS_HOSTNAME_PORTAINER:-portainer}
      - TS_AUTHKEY=${TS_AUTHKEY}
      - TS_STATE_DIR=/var/lib/tailscale
      - TS_AUTH_ONCE=true
      - TS_SERVE_CONFIG=/config/serve.json
    volumes:
      - /volume1/docker/portainer-secrets/certs:/certs:ro
      - /volume1/docker/portainer-secrets/chisel:/chisel:ro
      - /volume1/docker/stacks/portainer/ts-state:/var/lib/tailscale
      - /volume1/docker/stacks/portainer/ts-config:/config
    devices:
      - /dev/net/tun:/dev/net/tun
    cap_add:
      - NET_ADMIN
      - SYS_MODULE
      - NET_RAW
    ports:
      - "19443:9443"
      - "9000:9000"
      - "8000:8000"
    networks:
      - portainer_net

networks:
  portainer_net:
    driver: bridge

volumes:
  ts-portainer-proxy-data:
```

## Verification Checklist

Before committing a new or updated compose file:

- [ ] YAML syntax is valid
- [ ] Services are ordered by dependency (main first, sidecars second)
- [ ] Properties are ordered by logical grouping
- [ ] Volumes are ordered by importance (secrets, state, config)
- [ ] Container names follow naming conventions
- [ ] Network configuration is correct
- [ ] Environment variables use `${VAR:-default}` pattern for optional values
- [ ] Restart policies are appropriate for each service
- [ ] Security options are set (no-new-privileges, etc.)

## Migration Guide

When updating existing compose files to match these standards:

1. **Reorder services**: Move main app to top, sidecars below
2. **Reorder properties**: Follow the property ordering guide
3. **Reorder volumes**: Move secrets first, then state, then config
4. **Update container names**: Ensure naming convention compliance
5. **Test**: Verify the file deploys correctly

## Script Organization

All deployment and maintenance scripts should live in `iac/scripts/`, not in individual stack directories.

### Best Practices

1. **Centralize scripts**: Put all scripts in `iac/scripts/` to avoid duplication
2. **Replace, don't add**: When updating a script, overwrite the existing file rather than creating a new version
3. **Name clearly**: Use descriptive names that indicate purpose (e.g., `deploy-portainer.sh`, `rebuild.sh`)
4. **Document usage**: Include usage examples in the script comments

### Example: Rebuild Script

**Wrong**: Creating `portainer/rebuild.sh` in the stack directory

```text
iac/portainer/rebuild.sh  ❌ (duplication, hard to find)
```

**Right**: Updating `iac/scripts/rebuild.sh`

```text
iac/scripts/rebuild.sh  ✅ (centralized, single source of truth)
```

### When to Create New Scripts

Only create a new script in `iac/scripts/` when:

- It serves multiple stacks or the entire fleet
- It's a reusable utility (e.g., validation, deployment helpers)
- The existing script cannot be reasonably extended

For stack-specific one-off operations, prefer editing the compose file directly or using the existing scripts.

## Markdown Linting

All markdown files in the IAC repo are linted with `rumdl` and auto-formatted on commit via pre-commit hooks.

### Configuration

- **Config file:** `.rumdl.toml`
- **Pre-commit hook:** `.pre-commit-config.yaml`
- **Line length:** 160 characters
- **Auto-fix:** Enabled via pre-commit

### Common Rules

- **MD013** - Line length (160 chars, excludes code blocks)
- **MD040** - Code blocks must have language tags
- **MD032** - Lists must be preceded by blank line
- **MD031** - Blank line before fenced code blocks

### Running Linters

```bash
# Auto-fix all issues
rumdl fmt .

# Check without fixing
rumdl check .

# Run via pre-commit
pre-commit run --all-files
```

### See Also

- Full documentation: `docs/007_markdown_linting.md`

## Notes

- These standards emerged from the portainer deployment pattern
- They are designed to be **readable**, **maintainable**, and **consistent**
- The goal is to make compose files **self-documenting** through structure
- When in doubt, follow the pattern that makes the file **easiest to understand at a glance**
