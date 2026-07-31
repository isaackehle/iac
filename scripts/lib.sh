#!/usr/bin/env bash
# scripts/lib.sh — shared config for the deploy tooling in this repo.
# Sourced by gen-env.sh / deploy.sh, not executed directly.
#
# This file is the single source of truth for "what directories does each
# stack need on the NAS" and "where does each stack live on the NAS" — it
# replaces the old per-stack init.sh / apply-serve.sh scripts.

ALL_STACKS=(
  affine frigate homeassistant mosquitto n8n nextcloud
  openwebui pihole plex portainer postgresql syncthing
)

# Remote directory each stack is deployed into on the NAS. Standard is
# /volume1/docker/stacks/<stack>; a few stacks were deployed before that
# convention existed and still hold real data at their old path — do not
# "fix" these without manually migrating data on the NAS first.
declare -A STACK_REMOTE_DIR=(
  [affine]="/volume1/docker/stacks/affine"
  [frigate]="/volume1/docker/stacks/frigate"
  [homeassistant]="/volume1/docker/stacks/homeassistant"
  [mosquitto]="/volume1/docker/stacks/mosquitto"
  [n8n]="/volume1/docker/stacks/n8n"
  [nextcloud]="/volume1/docker/stacks/nextcloud"
  [openwebui]="/volume1/docker/stacks/openwebui"
  [pihole]="/volume1/docker/stacks/pihole"
  [plex]="/volume1/docker/stacks/plex"
  [portainer]="/volume1/docker/stacks/portainer"
  [postgresql]="/volume1/docker/stacks/postgresql"
  [syncthing]="/volume1/docker/stacks/syncthing"
)

# Directories to `mkdir -p` (relative to STACK_REMOTE_DIR[$stack]) before
# pushing files. Space-separated, supports brace-free plain paths only.
declare -A STACK_DIRS=(
  [affine]="data/storage data/config data/postgres"
  [frigate]="config storage"
  [homeassistant]="ts-state ts-config"
  [mosquitto]="config data certs"
  [n8n]="config files ts-state ts-config"
  [nextcloud]="app data postgres ts-state ts-config"
  [openwebui]="config ts-state ts-config data"
  [pihole]="etc-pihole ts-state ts-config"
  [plex]="config ts-state ts-config"
  [portainer]="config data ts-state ts-config"
  [postgresql]=""   # legacy stack, dirs already exist on the NAS
  [syncthing]="config sync data ts-state ts-config"
)

# Extra files to copy beyond the compose file and generated .env, as
# "local_path:remote_relative_path" pairs (space-separated). Sidecar stacks
# drop serve.json into ts-config/ so the whole /config mount is a plain
# directory — no single-file mounts (which break if the file is missing
# and are cwd-sensitive when relative).
declare -A STACK_EXTRA_FILES=(
  [frigate]="frigate-config.yml:config/config.yml"
  [homeassistant]="serve.json:ts-config/serve.json"
  [mosquitto]="config/mosquitto.conf:config/mosquitto.conf"
  [n8n]="serve.json:ts-config/serve.json"
  [nextcloud]="serve.json:ts-config/serve.json"
  [openwebui]="serve.json:ts-config/serve.json"
  [pihole]="serve.json:ts-config/serve.json"
  [plex]="serve.json:ts-config/serve.json"
  [portainer]="serve.json:ts-config/serve.json"
  [syncthing]="serve.json:ts-config/serve.json"
)

# uid:gid chown overrides for specific subdirectories, as "dir:uid:gid" pairs
# (space-separated). Anything not listed here is chowned to the SSH
# session's own user via `id -u`/`id -g`.
declare -A STACK_CHOWN_OVERRIDES=(
  [nextcloud]="app:33:33 data:33:33"
  [n8n]="config:1000:1000"
)

# Pattern A / hybrid stacks: host-level `tailscale serve` mappings, as
# "host_port:backend_url" pairs (space-separated). These run against the
# NAS host's own tailscaled, not a sidecar container.
declare -A STACK_SERVE_PORTS=(
  [affine]="3010:http://127.0.0.1:3010"
  [frigate]="8971:http://127.0.0.1:8971"
  [pihole]="8080:http://127.0.0.1:8080 8443:https+insecure://127.0.0.1:8443"
  [postgresql]="2660:http://127.0.0.1:2660"
)

# Default location of the central secrets file. Override with
# IAC_SECRETS_FILE=/some/other/path. Lives at the repo root, gitignored —
# see iac-secrets.env.example for the format and AGENTS.md for the rationale.
IAC_SECRETS_FILE="${IAC_SECRETS_FILE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/iac-secrets.env}"

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
    echo "ERROR: unknown stack '$stack' — expected one of: ${ALL_STACKS[*]}" >&2
    exit 1
  fi
}

# get_secret_value KEY — look up KEY in $IAC_SECRETS_FILE, empty if unset/missing.
get_secret_value() {
  local key="$1"
  [[ -f "$IAC_SECRETS_FILE" ]] || return 0
  grep -m1 -E "^${key}=" "$IAC_SECRETS_FILE" | cut -d= -f2- || true
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
