# Docker Compose File Standards

This document defines the expected organization and ordering of docker-compose.yml files across the IAC repo.

> Most of this document is about **style** — ordering, naming, grouping. The
> [Correctness Rules](#correctness-rules) section is different: those are rules
> where getting it wrong means the stack does not start, or starts and silently
> does the wrong thing. They came out of a real eight-hour outage
> (`portainer/OUTAGE-2026-08-03.md`) and a subsequent audit of all 15 compose
> files. Style is negotiable; correctness is not.

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
2. **Caddy sidecar** (if applicable - reverse proxy with HTTPS)
3. **Tailscale sidecar** (network tunnel)
4. **Auxiliary services** (databases, caches, etc. - if any)

### Example: Portainer (with Caddy and Tailscale sidecars)

```yaml
services:
  # Main application
  service.primary:
    image: portainer/portainer-ce:latest
    container_name: portainer
    ...

  # Caddy sidecar (reverse proxy with HTTPS)
  service.caddy:
    image: caddy:latest
    container_name: portainer-caddy
    ...

  # Tailscale sidecar (network tunnel)
  service.tailscale:
    image: tailscale/tailscale:latest
    container_name: portainer-tailscale
    ...
```

### Example: Pihole (with Caddy and Tailscale sidecars)

```yaml
services:
  # Main application
  service.primary:
    image: pihole/pihole:latest
    container_name: pihole
    ...

  # Caddy sidecar (reverse proxy with HTTPS)
  service.caddy:
    image: caddy:latest
    container_name: pihole-caddy
    ...

  # Tailscale sidecar (network tunnel)
  service.tailscale:
    image: tailscale/tailscale:latest
    container_name: pihole-tailscale
    ...
```

### Example: Home Assistant (Tailscale only)

```yaml
services:
  # Main application — owns the namespace
  service.primary:
    image: ghcr.io/home-assistant/home-assistant:stable
    container_name: homeassistant
    # no depends_on — see Correctness Rule 1
    ...

  # Tailscale sidecar (network tunnel) — borrows it
  service.tailscale:
    image: tailscale/tailscale:latest
    container_name: homeassistant-tailscale
    network_mode: service:service.primary
    depends_on:
      - service.primary
    ...
```

> Home Assistant currently runs `network_mode: host`, which is incompatible
> with this pattern (Correctness Rule 3). The stack needs a decision before it
> can work as written — don't copy it as a template.

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
  service.primary:
    network_mode: service:service.tailscale
    depends_on:
      - service.tailscale

  service.tailscale:
    # Tailscale configuration — owns the namespace, depends on nothing
    # ...
```

---

## Correctness Rules

These are not style preferences. Each one below has broken a stack in this repo.

### 1. `depends_on` direction follows namespace ownership — never both ways

Exactly one service owns the network namespace. Everything using
`network_mode: service:<owner>` **borrows** it. The borrower depends on the
owner. **The owner must never depend on a borrower** — that's a cycle, and
Compose refuses to start the stack with `cycle found in dependencies`.

```yaml
# CORRECT — sidecar owns the namespace, app and caddy borrow it
services:
  primary:
    network_mode: service:tailscale
    depends_on: [tailscale]
  caddy:
    network_mode: service:tailscale
    depends_on: [tailscale, primary]
  tailscale:
    # no depends_on
```

```yaml
# CORRECT — app owns the namespace (pihole pattern), sidecars borrow it
services:
  primary:
    # no depends_on
  caddy:
    network_mode: service:primary
    depends_on: [primary]
  tailscale:
    network_mode: service:primary
    depends_on: [primary]
```

```yaml
# WRONG — cycle. This was homeassistant, and the stack could not start.
services:
  primary:
    depends_on: [tailscale]
  tailscale:
    network_mode: service:primary
    depends_on: [primary]
```

Which service owns the namespace differs per stack — portainer's sidecar owns
it, pihole's app owns it. Both are fine. Read `network_mode` first, then point
every `depends_on` toward the owner.

### 2. `depends_on` takes **service names**, not container names

`depends_on` and `network_mode: service:` both resolve against the keys under
`services:` — never `container_name`. `depends_on: [portainer-tailscale]` is an error;
the service is `tailscale`. This bites specifically because the two
deliberately differ under our naming convention.

### 3. `network_mode: host` is incompatible with the sidecar pattern

A sidecar that borrows a host-networked container's namespace ends up on the
**host** network — so `tailscaled` runs alongside the NAS's own `tailscaled`,
two daemons in one netns, both trying to manage tailnet state. Pick one: host
networking for device discovery, or a sidecar. Not both.

### 4. Every service that mounts `ts-config` needs `TS_SERVE_CONFIG`

`scripts/lib.sh` pushes `serve.json` into `ts-config/` for every stack listed in
`STACK_EXTRA_FILES`. If the sidecar doesn't set
`TS_SERVE_CONFIG=/config/serve.json` *and* mount `ts-config:/config`, that file
is written and silently never read. If a stack is in `STACK_EXTRA_FILES`, its
compose file must consume it — or remove it from `lib.sh`.

Keep `lib.sh` and the compose file in sync generally: if `STACK_DIRS` provisions
`clickhouse-data`, there had better be a ClickHouse service.

### 5. Published port must match the port the process actually listens on

`"2665:5454"` on a Postgres container published to a port nothing listens on —
Postgres listens on 5432. The mapping is `host:container`, and the container
side is not a free choice. Verify against the image's documented port.

### 6. No literal secrets, and no redactions, in compose files

Every secret comes from `${VAR}` resolved out of the stack's `.env`. A literal
`***` where a password belongs (a pasted redaction) is a silent auth failure,
not a placeholder — it was committed in affine's `DATABASE_URL` and stayed
there. If you're tempted to redact a value while editing, that value shouldn't
have been in the file.

### 7. Prefer `condition: service_healthy` over bare `depends_on` for stateful deps

Bare `depends_on` waits for the container to *start*, not to be *ready*. A
database accepts connections seconds after it starts. Give databases and caches
a `healthcheck`, then depend on it properly:

```yaml
depends_on:
  config:
    condition: service_healthy
```

Use `condition: service_completed_successfully` for one-shot migration jobs
(see affine). Bare list form is fine only for genuinely order-insensitive deps.

### 8. Absolute volume paths

Use `/volume1/docker/stacks/<stack>/...`, not `./...`. Relative paths resolve
against whatever directory Compose was invoked from, which differs between CLI,
Container Manager, and Portainer — so the same file mounts different things
depending on who ran it.

### 9. No `version:` key

Obsolete under Compose v2 and warns on every `up`. `name:` stays.

### 10. Declare nothing you don't use

Top-level `volumes:` and `networks:` entries that no service references are dead
config that outlives its reason and confuses the next reader.

### Operational rule: never restart a sidecar alone

Not a file rule, but it belongs with them. `network_mode: service:X` binds the
namespace at **container creation**. `docker restart <sidecar>` leaves every
borrower pointed at a namespace that no longer exists — the app looks up, the
sidecar logs `connection refused` to its own backend, and nothing works.
Mismatched uptimes in `docker ps` are the tell.

```shell
docker compose down && docker compose up -d   # always both, always together
```

### Validating

Before committing any compose change, this catches rules 1, 2, and most of 4:

```shell
docker compose -f <stack>/docker-compose.yml config -q
```

To check every stack at once for cycles and namespace/dependency mismatches, see
the audit loop in `scripts/` — or minimally, confirm each file parses and that
every `depends_on` / `network_mode: service:` target appears under `services:`.

## Naming Conventions

### Service Names

Service names (the keys under `services:`) must follow the standardized pattern:

- **Main application**: `primary` (the primary service)
- **Migration/job service**: `migration` (one-shot setup tasks, if applicable)
- **Caddy sidecar**: `caddy` (if applicable - reverse proxy with HTTPS)
- **Tailscale sidecar**: `tailscale` (network tunnel)
- **Auxiliary services**: `config` (database), `cache` (Redis),
  `storage` (blob store), `admin` (admin UI),
  `browserless` (browser automation), `worker` (async worker), etc.

Container names (`container_name:`) remain unchanged — they keep the descriptive `<stack-name>` format.

### Container Names

Container names (`container_name:`) should be unique and descriptive:

- **Main application**: `<stack-name>` (e.g., `portainer`, `pihole`)
- **Caddy sidecar**: `<stack-name>-caddy` (e.g., `portainer-caddy`, `pihole-caddy`)
- **Tailscale sidecar**: `<stack-name>-tailscale` (e.g., `portainer-tailscale`, `pihole-tailscale`)
- **Auxiliary services**: `<stack-name>-<service>` (e.g., `nextcloud-db`, `nextcloud-redis`)

### Example: Standardized Naming

```yaml
services:
  # Main application
  primary:
    image: portainer/portainer-ce:latest
    container_name: portainer

  # Caddy sidecar
  caddy:
    image: caddy:latest
    container_name: portainer-caddy

  # Tailscale sidecar
  tailscale:
    image: tailscale/tailscale:latest
    container_name: portainer-tailscale
```

## Example: Complete Portainer Compose

```yaml
name: portainer

services:
  # Main application
  primary:
    image: portainer/portainer-ce:latest
    container_name: portainer
    restart: always
    security_opt:
      - no-new-privileges:true
    network_mode: service:tailscale
    depends_on:
      - tailscale
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - /volume1/docker/stacks/portainer/data:/data

  # Caddy sidecar (reverse proxy with HTTPS)
  caddy:
    image: caddy:latest
    container_name: portainer-caddy
    restart: unless-stopped
    depends_on:
      - tailscale
      - primary
    network_mode: service:tailscale
    volumes:
      - /volume1/docker/stacks/portainer/caddy-config:/etc/caddy:ro

  # Tailscale sidecar (network tunnel)
  tailscale:
    image: tailscale/tailscale:latest
    container_name: portainer-tailscale
    restart: unless-stopped
    environment:
      - TS_HOSTNAME=${TS_HOSTNAME:-portainer}
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
```

## Verification Checklist

Before committing a new or updated compose file:

**Correctness — a "no" here means it's broken:**

- [ ] `docker compose config -q` passes
- [ ] Exactly one service owns the namespace; every borrower `depends_on` it, and the owner depends on none of them (no cycles)
- [ ] Every `depends_on` / `network_mode: service:` target is a **service name**, not a `container_name`
- [ ] Published ports match the port the containerized process actually listens on
- [ ] No literal secrets and no redactions (`***`) — all secrets via `${VAR}`
- [ ] Stateful dependencies have a `healthcheck` and are depended on with `condition: service_healthy`
- [ ] Volume paths are absolute
- [ ] No `version:` key
- [ ] Stack's entry in `scripts/lib.sh` matches what the compose file actually consumes
- [ ] Every top-level `networks:` / `volumes:` entry is referenced by a service

**Style:**

- [ ] Services are ordered: main app → caddy → tailscale → auxiliary
- [ ] Service names use standardized pattern (`caddy`, `tailscale`)
- [ ] Properties are ordered by logical grouping
- [ ] Volumes are ordered by importance (secrets, state, config)
- [ ] Container names follow naming conventions (`caddy-<stack>`, `<stack>-tailscale`)
- [ ] Environment variables use `${VAR:-default}` pattern for optional values
- [ ] Restart policies are appropriate for each service
- [ ] Security options are set (no-new-privileges, etc.)

## Migration Guide

When updating existing compose files to match these standards:

1. **Reorder services**: Main app → caddy → tailscale → auxiliary
2. **Rename services**: Use standardized names (`primary`, `tailscale`, `caddy`, etc.)
3. **Reorder properties**: Follow the property ordering guide
4. **Reorder volumes**: Move secrets first, then state, then config
5. **Update container names**: Ensure naming convention compliance (`caddy-<stack>`, `<stack>-tailscale`)
6. **Test**: Verify the file deploys correctly

### Example: Migration from Old to New Pattern

**Before:**

```yaml
services:
  portainer:
    ...
  portainer-tailscale:
    ...
```

**After:**

```yaml
services:
  primary:
    ...
  tailscale:
    ...
```

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

```shell
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
