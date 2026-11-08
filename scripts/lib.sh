#!/opt/homebrew/bin/bash
# scripts/lib.sh — shared config for the deploy tooling in this repo.
# Sourced by gen-env.sh / deploy.sh, not executed directly.
#
# This file is the single source of truth for "what directories does each
# stack need on the NAS" and "where does each stack live on the NAS" — it
# replaces the old per-stack init.sh / apply-serve.sh scripts.

# The tables below are associative arrays (declare -A), which need bash 4+.
# macOS's /bin/bash is 3.2, and a caller with `#!/usr/bin/env bash` gets it
# when Homebrew's bash is not first in PATH; it then fails with
# "actualbudget: unbound variable". Re-run the caller under a newer bash.
if (( BASH_VERSINFO[0] < 4 )); then
  for _bash in /opt/homebrew/bin/bash /usr/local/bin/bash; do
    [[ -x "$_bash" ]] && exec "$_bash" "$0" "$@"
  done
  echo "ERROR: $0 needs bash 4+ (brew install bash); this is bash $BASH_VERSION" >&2
  exit 1
fi

# All known stacks (including disabled ones). For the list of stacks that
# should actually be operated on, use `enabled_stacks` below, which reads
# scripts/stacks.yaml and skips disabled / _template stacks.
ALL_STACKS=(
  actualbudget affine dsm esphome frigate ha langfuse mosquitto n8n nextcloud
  openwebui pihole plex portainer postgresql syncthing mcp observability
)

STACKS_YAML="${STACKS_YAML:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/scripts/stacks.yaml}"
STACKS_LOCAL_YAML="${STACKS_LOCAL_YAML:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/scripts/stacks-local.yaml}"

# parse_stacks_yaml FILE — print "stackname:TYPE" pairs from a stacks YAML
# file, one per line.  Exits 1 if the file is missing.
parse_stacks_yaml() {
  local file="$1"
  [[ -f "$file" ]] || return 1
  local in_stacks=false current_stack="" cur_type=""
  while IFS= read -r line; do
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    [[ -z "${line// /}" ]] && continue
    if [[ "$line" == "stacks:" ]]; then
      in_stacks=true
      continue
    fi
    if $in_stacks && [[ "$line" =~ ^[a-zA-Z] ]] && [[ "$line" != " "* ]]; then
      in_stacks=false
      continue
    fi
    if $in_stacks && [[ "$line" =~ ^[[:space:]]{2}[a-zA-Z_][a-zA-Z0-9_]*:[[:space:]]*$ ]]; then
      if [[ -n "$current_stack" && -n "$cur_type" ]]; then
        echo "${current_stack}:${cur_type}"
      fi
      current_stack="${line%%:*}"
      current_stack="${current_stack// /}"
      cur_type=""
      continue
    fi
    if [[ "$line" =~ ^[[:space:]]+type:[[:space:]]+(container_manager|portainer|disabled) ]]; then
      cur_type="${BASH_REMATCH[1]}"
    fi
  done < "$file"
  # Don't forget the last stack
  if [[ -n "$current_stack" && -n "$cur_type" ]]; then
    echo "${current_stack}:${cur_type}"
  fi
}

# enabled_stacks — print stack names whose effective type is NOT "disabled"
# and is NOT "_template".  One name per line.
#
# Merges two sources: stacks-local.yaml (private, gitignored) takes
# precedence over stacks.yaml (public, defaults).  Falls back to
# ALL_STACKS when both files are missing (warns on stderr).
enabled_stacks() {
  if [[ ! -f "$STACKS_YAML" && ! -f "$STACKS_LOCAL_YAML" ]]; then
    echo "WARN: neither $STACKS_YAML nor $STACKS_LOCAL_YAML found; falling back to ALL_STACKS" >&2
    printf '%s\n' "${ALL_STACKS[@]}"
    return
  fi

  # Build a map: stackname → effective type (local overrides default).
  declare -A type_map=()

  # Load defaults from stacks.yaml.
  while IFS=: read -r name typ; do
    type_map["$name"]="$typ"
  done < <(parse_stacks_yaml "$STACKS_YAML" 2>/dev/null)

  # Overlay local overrides (stacks-local.yaml).
  if [[ -f "$STACKS_LOCAL_YAML" ]]; then
    while IFS=: read -r name typ; do
      type_map["$name"]="$typ"
    done < <(parse_stacks_yaml "$STACKS_LOCAL_YAML" 2>/dev/null)
  fi

  # Print stacks whose effective type is not "disabled" and not "_template".
  for name in "${!type_map[@]}"; do
    if [[ "${type_map[$name]}" != "disabled" && "$name" != "_template" ]]; then
      echo "$name"
    fi
  done | sort
}

# stack_type STACK — print the effective type (container_manager |
# portainer | disabled), merging local override over stacks.yaml defaults.
# Returns 0 on success, 1 if the stack is missing from both files.
stack_type() {
  local stack="$1"

  # Check local override first.
  if [[ -f "$STACKS_LOCAL_YAML" ]]; then
    while IFS=: read -r name typ; do
      if [[ "$name" == "$stack" ]]; then
        echo "$typ"
        return 0
      fi
    done < <(parse_stacks_yaml "$STACKS_LOCAL_YAML" 2>/dev/null)
  fi

  # Fall back to stacks.yaml.
  if [[ -f "$STACKS_YAML" ]]; then
    while IFS=: read -r name typ; do
      if [[ "$name" == "$stack" ]]; then
        echo "$typ"
        return 0
      fi
    done < <(parse_stacks_yaml "$STACKS_YAML" 2>/dev/null)
  fi

  return 1
}

# Remote directory each stack is deployed into on the NAS. Standard is
# /volume1/docker/stacks/<stack>; a few stacks were deployed before that
# convention existed and still hold real data at their old path — do not
# "fix" these without manually migrating data on the NAS first.
declare -A STACK_REMOTE_DIR=(
  [actualbudget]="/volume1/docker/stacks/actualbudget"
  [affine]="/volume1/docker/stacks/affine"
  [dsm]="/volume1/docker/stacks/dsm"
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
  [mcp]="/volume1/docker/stacks/mcp"    # was synology-mcp (2026-09-26)
  [esphome]="/volume1/docker/stacks/esphome"
  [observability]="/volume1/docker/stacks/observability"
)

# Directories to `mkdir -p` (relative to STACK_REMOTE_DIR[$stack]) before
# pushing files. Space-separated, supports brace-free plain paths only.
declare -A STACK_DIRS=(
  [actualbudget]="data ts-state ts-config"
  [affine]="data/storage data/config data/postgres ts-state ts-config"
  [dsm]="state ts-config"
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
  [esphome]="ts-state ts-config"
  [observability]="ts-state ts-config config data/prometheus data/alertmanager data/grafana data/loki data/alloy textfile"
)

# Extra files to copy beyond the compose file and generated .env, as
# "local_path:remote_relative_path" pairs (space-separated). Sidecar stacks
# drop serve.json into ts-config/ so the whole /config mount is a plain
# directory — no single-file mounts (which break if the file is missing
# and are cwd-sensitive when relative).
declare -A STACK_EXTRA_FILES=(
  [actualbudget]="serve.json:ts-config/serve.json"
  [affine]="serve.json:ts-config/serve.json"
  [dsm]="serve.json:ts-config/serve.json"
  [frigate]="frigate-config.yml:config/config.yml serve.json:ts-config/serve.json"
  [ha]="serve.json:ts-config/serve.json"
  [langfuse]="serve.json:ts-config/serve.json"
  [mosquitto]="config/mosquitto.conf:config/mosquitto.conf serve.json:ts-config/serve.json"
  [mcp]="serve.json:ts-config/serve.json servers/time/Dockerfile:servers/time/Dockerfile"
  [n8n]="serve.json:ts-config/serve.json"
  [nextcloud]="serve.json:ts-config/serve.json"
  [openwebui]="serve.json:ts-config/serve.json configure-litellm.sh:configure-litellm.sh"
  [pihole]="serve.json:ts-config/serve.json"
  [plex]="serve.json:ts-config/serve.json"
  [portainer]="serve.json:ts-config/serve.json"
  [postgresql]="serve.json:ts-config/serve.json"
  [syncthing]="serve.json:ts-config/serve.json"
  [esphome]="serve.json:ts-config/serve.json"
  # observability: rendered templates (serve.json, prometheus.yml, alertmanager.yml,
  # telegram_bot_token, snmp-auth.yml) plus the plain config files under config/.
  [observability]="serve.json:ts-config/serve.json prometheus.yml:config/prometheus/prometheus.yml prometheus/rules/containers.yml:config/prometheus/rules/containers.yml prometheus/rules/nas.yml:config/prometheus/rules/nas.yml prometheus/rules/endpoints.yml:config/prometheus/rules/endpoints.yml prometheus/rules/self.yml:config/prometheus/rules/self.yml prometheus/rules/laptops.yml:config/prometheus/rules/laptops.yml alertmanager.yml:config/alertmanager/alertmanager.yml telegram_bot_token:config/alertmanager/telegram_bot_token loki/loki.yml:config/loki/loki.yml loki/rules/fake/nas.yml:config/loki/rules/fake/nas.yml alloy/config.alloy:config/alloy/config.alloy blackbox/blackbox.yml:config/blackbox/blackbox.yml snmp-auth.yml:config/snmp/auth.yml docker-state/docker-state.sh:config/docker-state/docker-state.sh laptop-probe/laptop-probe.sh:config/laptop-probe/laptop-probe.sh laptop-probe.conf:config/laptop-probe/laptop-probe.conf grafana/provisioning/datasources/datasources.yml:config/grafana/provisioning/datasources/datasources.yml grafana/provisioning/dashboards/dashboards.yml:config/grafana/provisioning/dashboards/dashboards.yml grafana/dashboards/homelab-overview.json:config/grafana/dashboards/homelab-overview.json"
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
  # observability: none on purpose. Its non-root services run as the SSH user
  # (OBS_PUID/OBS_PGID), so the default chown to that user is what they need.
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

# Set by render_templates to enable per-stack .env fallback.
CURRENT_STACK="${CURRENT_STACK:-}"

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
    local known_stacks="actualbudget affine dsm frigate ha langfuse mosquitto n8n nextcloud openwebui pihole plex portainer postgresql syncthing mcp observability"
    echo "ERROR: unknown stack '$stack' — expected one of: $known_stacks" >&2
    exit 1
  fi
  # Check if the stack is disabled (local override or default).
  local typ
  typ="$(stack_type "$stack" 2>/dev/null)" || typ=""
  if [[ "$typ" == "disabled" ]]; then
    echo "ERROR: stack '$stack' is disabled — skipping" >&2
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
  # When there's no central secrets file, read from <stack>/.env.
  if [[ -z "$value" && -n "$CURRENT_STACK" && -f "$CURRENT_STACK/.env" ]]; then
    value="$(grep -m1 -E "^${key}=" "$CURRENT_STACK/.env" | cut -d= -f2- || true)"
  fi
  [[ -n "$value" ]] || return 0

  if [[ "$value" == op://* ]]; then
    # Service account FIRST: reads and writes on the secrets vault were verified 2026-10-11, and it never prompts.
    # (The old advice to unset it came from an August 403 and from a variable named OP_SERVICE_ACCOUNT, without
    # _TOKEN, holding an unresolved op:// reference. Unset THAT one, not the token.) The desktop app is only a
    # fallback, because it can raise a Touch ID prompt on every call.
    local resolved="" sa_token="${OP_SERVICE_ACCOUNT_TOKEN:-}"
    if [[ -z "$sa_token" && -n "$IAC_USER_ENV_FILE" && -f "$IAC_USER_ENV_FILE" ]]; then
      sa_token="$(grep -m1 -E '^(export[[:space:]]+)?OP_SERVICE_ACCOUNT_TOKEN=' "$IAC_USER_ENV_FILE" | cut -d= -f2- || true)"
      sa_token="${sa_token%\"}"; sa_token="${sa_token#\"}"; sa_token="${sa_token%\'}"; sa_token="${sa_token#\'}"
    fi
    if [[ -n "$sa_token" && "$sa_token" != op://* ]]; then
      resolved="$(env -u OP_SERVICE_ACCOUNT OP_SERVICE_ACCOUNT_TOKEN="$sa_token" OP_BIOMETRIC_UNLOCK_ENABLED=false \
                  op read "$value" 2>/dev/null)" || resolved=""
    fi
    if [[ -z "$resolved" ]]; then
      echo "WARN: service-account read failed for $key; falling back to the 1Password desktop app (may prompt Touch ID)" >&2
      resolved="$(env -u OP_SERVICE_ACCOUNT -u OP_SERVICE_ACCOUNT_TOKEN -u OP_TOKEN op read "$value" 2>/dev/null)" || {
        echo "WARN: op read failed for $key ($value): treating as unset" >&2
        return 0
      }
    fi
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
  CURRENT_STACK="$stack"
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
        echo "    ⚠ $tmpl: {{$token}} has no value, leaving as-is"
        break
      fi
      content="${content//\{\{$token\}\}/$value}"
    done

    printf '%s\n' "$content" >"$out"
    echo "==> $stack: rendered $tmpl -> $out"
  done
}
