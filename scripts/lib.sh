#!/opt/homebrew/bin/bash
# scripts/lib.sh — shared config for the deploy tooling in this repo.
# Sourced by gen-env.sh / deploy.sh, not executed directly.
#
# This file is the single source of truth for "what directories does each
# stack need on the NAS" and "where does each stack live on the NAS" — it
# replaces the old per-stack init.sh / apply-serve.sh scripts.

ALL_STACKS=(
  affine frigate ha langfuse mosquitto n8n nextcloud
  openwebui pihole plex portainer postgresql syncthing mcp
)

# Remote directory each stack is deployed into on the NAS. Standard is
# /volume1/docker/stacks/<stack>; a few stacks were deployed before that
# convention existed and still hold real data at their old path — do not
# "fix" these without manually migrating data on the NAS first.
declare -A STACK_REMOTE_DIR=(
  [affine]="/volume1/docker/stacks/affine"
  [frigate]="/volume1/docker/stacks/frigate"
  [ha]="/volume1/docker/stacks/ha"
  [langfuse]="/volume1/docker/stacks/langfuse"
  [mosquitto]="/volume1/docker/stacks/mosquitto"
  [n8n]="/volume1/docker/stacks/n8n"
  [nextcloud]="/volume1/docker/stacks/nextcloud"
  [openwebui]="/volume1/docker/stacks/openwebui"
  [pihole]="/volume1/docker/stacks/pihole"
  [plex]="/volume1/docker/stacks/plex"
  [portainer]="/volume1/docker/stacks/portainer"
  [postgresql]="/volume1/docker/stacks/postgresql"
  [syncthing]="/volume1/docker/stacks/syncthing"
  [mcp]="/volume1/docker/stacks/mcp"   # was synology-mcp (2026-09-26)
)

# Directories to `mkdir -p` (relative to STACK_REMOTE_DIR[$stack]) before
# pushing files. Space-separated, supports brace-free plain paths only.
declare -A STACK_DIRS=(
  [affine]="data/storage data/config data/postgres ts-state ts-config"
  [frigate]="config storage ts-state ts-config"
  [ha]="ts-state ts-config"   # Tailscale front door for HA (HA_LAN_IP in iac-secrets.env), no app container
  [langfuse]="ts-state ts-config clickhouse-data clickhouse-logs minio-data redis-data"
  [mosquitto]="config data certs ts-state ts-config"
  [mcp]="ts-state ts-config"
  [n8n]="config files ts-state ts-config"
  [nextcloud]="app data postgres ts-state ts-config"
  [openwebui]="config ts-state ts-config data"
  [pihole]="etc-pihole ts-state ts-config"
  [plex]="config ts-state ts-config"
  [portainer]="data ts-state ts-config"
  [postgresql]="ts-state ts-config"   # converted to Pattern B (sidecar) on 2026-08-04
  [syncthing]="config sync data ts-state ts-config"
)

# Extra files to copy beyond the compose file and generated .env, as
# "local_path:remote_relative_path" pairs (space-separated). Sidecar stacks
# drop serve.json into ts-config/ so the whole /config mount is a plain
# directory — no single-file mounts (which break if the file is missing
# and are cwd-sensitive when relative).
declare -A STACK_EXTRA_FILES=(
  [affine]="serve.json:ts-config/serve.json"
  [frigate]="frigate-config.yml:config/config.yml serve.json:ts-config/serve.json"
  [ha]="serve.json:ts-config/serve.json"
  [langfuse]="serve.json:ts-config/serve.json"
  [mosquitto]="config/mosquitto.conf:config/mosquitto.conf serve.json:ts-config/serve.json"
  [mcp]="serve.json:ts-config/serve.json"
  [n8n]="serve.json:ts-config/serve.json"
  [nextcloud]="serve.json:ts-config/serve.json"
  [openwebui]="serve.json:ts-config/serve.json configure-litellm.sh:configure-litellm.sh"
  [pihole]="serve.json:ts-config/serve.json"
  [plex]="serve.json:ts-config/serve.json"
  [portainer]="serve.json:ts-config/serve.json"
  [postgresql]="serve.json:ts-config/serve.json"
  [syncthing]="serve.json:ts-config/serve.json"
)

# uid:gid chown overrides for specific subdirectories, as "dir:uid:gid" pairs
# (space-separated). Anything not listed here is chowned to the SSH
# session's own user via `id -u`/`id -g`.
declare -A STACK_CHOWN_OVERRIDES=(
  [nextcloud]="app:33:33 data:33:33"
  [n8n]="config:1000:1000"
  # clickhouse-server runs as user 101:101 inside the container (see
  # `user: "101:101"` in langfuse/docker-compose.yml) — its mounted
  # volumes need to match or it can't write to them on first start.
  [langfuse]="clickhouse-data:101:101 clickhouse-logs:101:101"
)

# Pattern A: host-level `tailscale serve` mappings, as "host_port:backend_url"
# pairs (space-separated), applied to the NAS host's own tailscaled by
# `scripts/deploy.sh serve` and `scripts/serve-all.sh`.
#
# No stack uses this any more: every stack serves through its own Tailscale
# node (docs/tailscale_patterns.md). The NAS's serve config was cleared on
# 2026-09-26 (`tailscale serve reset`) after affine/frigate moved to sidecars
# and homeassistant left the repo (Home Assistant runs on its own machine,
# fronted by the `ha` stack). Only add an entry for a stack that needs host
# networking.
declare -A STACK_SERVE_PORTS=(
)

# Default location of the central secrets file. Override with
# IAC_SECRETS_FILE=/some/other/path. Lives at the repo root, gitignored —
# see iac-secrets.env.example for the format and AGENTS.md for the rationale.
IAC_SECRETS_FILE="${IAC_SECRETS_FILE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/iac-secrets.env}"

# Personal settings that must never be committed (e.g. DSM ports changed on the
# Security Advisor's advice) can live in ~/.env instead: get_secret_value falls
# back to it for keys that aren't in IAC_SECRETS_FILE. Override with
# IAC_USER_ENV_FILE=/path, or IAC_USER_ENV_FILE= to disable.
IAC_USER_ENV_FILE="${IAC_USER_ENV_FILE-$HOME/.env}"

compose_file_for() {
  local stack="$1"
  if [[ -f "$stack/docker-compose.yml" ]]; then
    echo "docker-compose.yml"
  elif [[ -f "$stack/docker-compose.yaml" ]]; then
    echo "docker-compose.yaml"
  else
    echo "ERROR: no docker-compose.yml(.yaml) found in $stack" >&2
    return 1
  fi
}

require_stack() {
  local stack="$1"
  if [[ -z "$stack" || ! -d "$stack" ]]; then
    # Use a simple list instead of array expansion to avoid bash 3.2 issues
    local known_stacks="affine frigate ha langfuse mosquitto n8n nextcloud openwebui pihole plex portainer postgresql syncthing mcp"
    echo "ERROR: unknown stack '$stack' — expected one of: $known_stacks" >&2
    exit 1
  fi
}

# get_secret_value KEY — look up KEY in $IAC_SECRETS_FILE, empty if unset/missing.
# Values that are op:// references (official 1Password protocol) are resolved
# via `op read`; plain values pass through unchanged. This lets secrets move
# from the plaintext file into the 1Password secrets vault one at a time —
# convert a value to KEY=op://<vault>/<item>/<field> and the official CLI
# resolves it, with the file remaining the single source of truth for the
# key list.
get_secret_value() {
  local key="$1"
  local value=""
  if [[ -f "$IAC_SECRETS_FILE" ]]; then
    value="$(grep -m1 -E "^${key}=" "$IAC_SECRETS_FILE" | cut -d= -f2- || true)"
  fi
  # Fallback: ~/.env (optionally "export KEY=..."; surrounding quotes stripped).
  if [[ -z "$value" && -n "$IAC_USER_ENV_FILE" && -f "$IAC_USER_ENV_FILE" ]]; then
    value="$(grep -m1 -E "^(export[[:space:]]+)?${key}=" "$IAC_USER_ENV_FILE" | cut -d= -f2- || true)"
    value="${value%\"}"; value="${value#\"}"; value="${value%\'}"; value="${value#\'}"
  fi
  [[ -n "$value" ]] || return 0

  if [[ "$value" == op://* ]]; then
    # Unset OP_SERVICE_ACCOUNT tokens before calling op read — they cause
    # 403s on user vaults. See 1password-cli skill for details.
    local saved_sa="${OP_SERVICE_ACCOUNT:-}"
    local saved_sa_token="${OP_SERVICE_ACCOUNT_TOKEN:-}"
    local saved_token="${OP_TOKEN:-}"
    unset OP_SERVICE_ACCOUNT OP_SERVICE_ACCOUNT_TOKEN OP_TOKEN
    local resolved
    resolved="$(op read "$value" 2>/dev/null)" || {
      echo "WARN: op read failed for $key ($value) — treating as unset" >&2
      # Restore env vars before returning
      [[ -n "$saved_sa" ]] && export OP_SERVICE_ACCOUNT="$saved_sa"
      [[ -n "$saved_sa_token" ]] && export OP_SERVICE_ACCOUNT_TOKEN="$saved_sa_token"
      [[ -n "$saved_token" ]] && export OP_TOKEN="$saved_token"
      return 0
    }
    # Restore env vars
    [[ -n "$saved_sa" ]] && export OP_SERVICE_ACCOUNT="$saved_sa"
    [[ -n "$saved_sa_token" ]] && export OP_SERVICE_ACCOUNT_TOKEN="$saved_sa_token"
    [[ -n "$saved_token" ]] && export OP_TOKEN="$saved_token"
    echo "$resolved"
    return 0
  fi

  echo "$value"
}

# render_templates STACK — render every <stack>/*.tmpl file into its
# non-.tmpl counterpart (e.g. serve.json.tmpl -> serve.json), substituting
# {{KEY}} tokens with values from the central secrets file. The rendered
# output is stack-specific and gitignored, same treatment as generated
# .env files — the .tmpl source is what's committed.
#
# Use this for values that Tailscale's own `${TS_CERT_DOMAIN}` runtime
# templating can't cover (e.g. a serve.json backend pointing at a
# *different* tailnet node's hostname, not this node's own domain).
render_templates() {
  local stack="$1"
  local tmpl
  for tmpl in "$stack"/*.tmpl; do
    [[ -e "$tmpl" ]] || continue
    local out="${tmpl%.tmpl}"
    local content
    content="$(cat "$tmpl")"

    local token
    while [[ "$content" =~ \{\{([A-Za-z_][A-Za-z0-9_]*)\}\} ]]; do
      token="${BASH_REMATCH[1]}"
      local value
      value="$(get_secret_value "$token")"
      
      # TS_CERT_DOMAIN auto-derivation: if not explicitly set in secrets,
      # derive from TS_TAILNET_DOMAIN as <stack>.<tailnet>
      if [[ -z "$value" && "$token" == "TS_CERT_DOMAIN" ]]; then
        local tailnet
        tailnet="$(get_secret_value "TS_TAILNET_DOMAIN")"
        [[ -n "$tailnet" ]] && value="${stack}.${tailnet}"
      fi
      
      if [[ -z "$value" ]]; then
        echo "    ⚠ $tmpl: {{$token}} has no value in $IAC_SECRETS_FILE, leaving as-is"
        break
      fi
      content="${content//\{\{$token\}\}/$value}"
    done

    printf '%s\n' "$content" >"$out"
    echo "==> $stack: rendered $tmpl -> $out"
  done
}
