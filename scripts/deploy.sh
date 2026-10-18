#!/opt/homebrew/bin/bash
# scripts/deploy.sh — push a stack's compose/env/config files to the NAS and
# (optionally) bring it up, all driven from the laptop over SSH.
#
# Replaces the old per-stack init.sh / apply-serve.sh / deploy-*.sh scripts.
# Directory layout and file lists come from scripts/lib.sh, so every stack
# is provisioned the same way instead of each having bespoke setup logic.
#
# Usage:
#   scripts/deploy.sh env    <stack>                  # generate <stack>/.env locally
#   scripts/deploy.sh dirs   <stack> <ssh-host>       # mkdir -p + chown on the NAS
#   scripts/deploy.sh push   <stack> <ssh-host>       # scp compose/.env/extra files
#   scripts/deploy.sh extras <stack> <ssh-host>       # scp ONLY the bind-mounted extra
#                                                     # config (serve.json,
#                                                     # etc.) — no compose file, no
#                                                     # .env
#   scripts/deploy.sh serve  <stack> <ssh-host>       # apply host-level tailscale serve (Pattern A/hybrid stacks)
#   scripts/deploy.sh up     <stack> <ssh-host>       # ssh in, docker compose up -d
#   scripts/deploy.sh api    <stack>                  # create stack in Portainer via API with GitConfig (Total control);
#                                                     # refuses if it already exists, never deletes
#   scripts/deploy.sh redeploy <stack> [--yes]        # Portainer git redeploy of an existing stack, Env unchanged
#   scripts/deploy.sh down   <stack> <ssh-host>       # ssh in, docker compose down -v
#   scripts/deploy.sh info   <stack>                  # print step-by-step deploy instructions
#   scripts/deploy.sh all    <stack> <ssh-host>       # env + dirs + push + serve + up
#
# <ssh-host> is anything ssh/scp accepts, e.g. `nas` (an ssh config alias)
# or `user@192.168.1.20`.
#
# push vs. extras: `push` is for stacks brought up directly via
# `docker compose up -d` on the NAS (the `up` command below) — it stages
# everything the compose file needs, including itself and .env. For
# stacks deployed through Portainer's Repository/GitOps mode instead (the
# documented method in most stacks' INSTALLATION.md), the compose file is
# never read from the NAS filesystem — Portainer clones its own copy from
# GitHub — and .env is meant to be selected from your laptop via
# Portainer's "Load variables from .env file" picker, not present on the
# NAS at all. Pushing either there just leaves a stale, unused duplicate
# sitting next to the real bind-mounted config. Use `extras` instead for
# those stacks: it pushes only the files containers actually read via
# host bind-mounts (serve.json, ...).

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib.sh
source "$ROOT_DIR/scripts/lib.sh"

usage() {
  cat >&2 <<'EOF'
Usage: scripts/deploy.sh <command> <stack> [ssh-host]

Commands:
  env    <stack>               generate <stack>/.env locally from the secrets file
  dirs   <stack> <ssh-host>    mkdir -p + chown the stack's directories on the NAS
  push   <stack> <ssh-host>    scp compose file, .env, and extra config into place
  extras <stack> <ssh-host>    scp ONLY the extra bind-mounted config (no compose, no
                                .env) — use for stacks deployed via Portainer
                                Repository/GitOps instead of `docker compose up -d`
  serve  <stack> <ssh-host>    apply host-level tailscale serve mappings (if any)
  up     <stack> <ssh-host>    ssh in and run `docker compose up -d`
  down   <stack> <ssh-host>    ssh in and run `docker compose down -v` (remove volumes)
  api    <stack>               create stack in Portainer via API with GitConfig (Total control);
                                refuses if a stack with that name exists, never deletes
  redeploy <stack> [--yes]     pull the compose file from git and redeploy an existing
                                Portainer stack, keeping its variables (asks first)
  info   <stack>               print deploy instructions for this stack
  all    <stack> <ssh-host>    env + dirs + push + serve + up
EOF
  exit 1
}

cmd_env() {
  "$ROOT_DIR/scripts/gen-env.sh" "$1"
}

cmd_dirs() {
  local stack="$1" host="$2"
  require_stack "$stack"
  local remote="${STACK_REMOTE_DIR[$stack]}"
  local dirs="${STACK_DIRS[$stack]:-}"

  echo "==> $stack: ensuring $remote exists on $host"
  ssh "$host" "mkdir -p '$remote'"

  if [[ -n "$dirs" ]]; then
    # shellcheck disable=SC2086
    ssh "$host" "cd '$remote' && mkdir -p $dirs"
  fi

  ssh "$host" "sudo chown -R \"\$(id -u)\":\"\$(id -g)\" '$remote'"

  local overrides="${STACK_CHOWN_OVERRIDES[$stack]:-}"
  for pair in $overrides; do
    local dir uid gid
    dir="${pair%%:*}"
    uid="$(echo "$pair" | cut -d: -f2)"
    gid="$(echo "$pair" | cut -d: -f3)"
    echo "    chown $uid:$gid $remote/$dir"
    ssh "$host" "sudo chown -R $uid:$gid '$remote/$dir'"
  done
}

cmd_push() {
  local stack="$1" host="$2"
  require_stack "$stack"
  local remote="${STACK_REMOTE_DIR[$stack]}"
  local compose
  compose="$(compose_file_for "$stack")"

  echo "==> $stack: pushing $compose to $host:$remote/"
  scp -O "$stack/$compose" "$host:$remote/$compose"

  if [[ -f "$stack/.env" ]]; then
    echo "==> $stack: pushing .env to $host:$remote/"
    scp -O "$stack/.env" "$host:$remote/.env"
  fi

  cmd_extras "$stack" "$host"
}

cmd_extras() {
  local stack="$1" host="$2"
  require_stack "$stack"
  local remote="${STACK_REMOTE_DIR[$stack]}"
  local extras="${STACK_EXTRA_FILES[$stack]:-}"

  if [[ -z "$extras" ]]; then
    echo "==> $stack: no extra config files to push"
    return 0
  fi

  for pair in $extras; do
    local local_path remote_rel
    local_path="${pair%%:*}"
    remote_rel="${pair#*:}"
    if [[ ! -f "$stack/$local_path" && -f "$stack/$local_path.tmpl" ]]; then
      echo "ERROR: $stack/$local_path not rendered yet — run 'scripts/gen-env.sh $stack' first" >&2
      echo "       (it is generated from $stack/$local_path.tmpl)" >&2
      exit 1
    fi
    echo "==> $stack: pushing $local_path to $host:$remote/$remote_rel"
    ssh "$host" "mkdir -p '$remote/$(dirname "$remote_rel")'"
    scp -O "$stack/$local_path" "$host:$remote/$remote_rel"
  done
}

cmd_serve() {
  local stack="$1" host="$2"
  require_stack "$stack"
  local mappings="${STACK_SERVE_PORTS[$stack]:-}"

  if [[ -z "$mappings" ]]; then
    echo "==> $stack: no host-level tailscale serve mappings (sidecar pattern or none)"
    return 0
  fi

  for pair in $mappings; do
    local port backend
    port="${pair%%:*}"
    backend="${pair#*:}"
    echo "==> $stack: tailscale serve --bg --https=$port $backend"
    # Use full path and sudo because /var/packages/Tailscale/target/bin is not in PATH
    # and the Tailscale package requires root for serve commands
    ssh "$host" "sudo /var/packages/Tailscale/target/bin/tailscale serve --bg --https=$port '$backend'"
  done
}

cmd_up() {
  local stack="$1" host="$2"
  require_stack "$stack"
  local remote="${STACK_REMOTE_DIR[$stack]}"
  local compose
  compose="$(compose_file_for "$stack")"

  echo "==> $stack: docker compose up -d on $host"
  # .env is now referenced explicitly in docker-compose.yml via env_file directive,
  # so no need for --env-file flag here.
  # Use full path because /usr/local/bin is not in PATH on the NAS
  ssh "$host" "cd '$remote' && /usr/local/bin/docker compose -f '$compose' up -d"
}

cmd_down() {
  local stack="$1" host="$2"
  require_stack "$stack"
  local remote="${STACK_REMOTE_DIR[$stack]}"
  local compose
  compose="$(compose_file_for "$stack")"

  echo "==> $stack: docker compose down -v on $host"
  # -v removes anonymous volumes (data directories)
  # Use full path because /usr/local/bin is not in PATH on the NAS
  ssh "$host" "cd '$remote' && /usr/local/bin/docker compose -f '$compose' down -v"
}

# --- Portainer API helpers (api / redeploy) ---------------------------------
#
# Stack changes on the NAS go through the Portainer API only, and nothing here
# ever DELETEs a stack.

PORTAINER_ENDPOINT=3

# portainer_auth STACK — set PORTAINER_URL and PORTAINER_API_KEY. The key is
# PORTAINER_API_KEY_<suffix> when set (environment first, then iac-secrets.env /
# ~/.env via get_secret_value; suffix from STACK_PORTAINER_KEY_SUFFIX in lib.sh,
# default the upper-cased stack name), else PORTAINER_API_KEY. Prints which
# variable was used, never any part of the value.
portainer_auth() {
  local stack="$1"
  local suffix="${STACK_PORTAINER_KEY_SUFFIX[$stack]:-}"
  [[ -n "$suffix" ]] || suffix="$(printf '%s' "$stack" | tr '[:lower:]-' '[:upper:]_')"
  local stack_var="PORTAINER_API_KEY_${suffix}"

  if [[ -z "${PORTAINER_URL:-}" ]]; then
    PORTAINER_URL="$(get_secret_value "PORTAINER_URL")"
  fi
  if [[ -z "${PORTAINER_URL:-}" ]]; then
    echo "ERROR: PORTAINER_URL not set in the environment, $IAC_SECRETS_FILE or $IAC_USER_ENV_FILE" >&2
    exit 1
  fi

  local key source
  key="${!stack_var:-}"; source="$stack_var (environment)"
  if [[ -z "$key" ]]; then
    key="$(get_secret_value "$stack_var")"; source="$stack_var (secrets file or ~/.env)"
  fi
  if [[ -z "$key" ]]; then
    key="${PORTAINER_API_KEY:-}"; source="PORTAINER_API_KEY (environment)"
  fi
  if [[ -z "$key" ]]; then
    key="$(get_secret_value "PORTAINER_API_KEY")"; source="PORTAINER_API_KEY (secrets file or ~/.env)"
  fi
  if [[ -z "$key" ]]; then
    echo "ERROR: neither $stack_var nor PORTAINER_API_KEY is set in the environment, $IAC_SECRETS_FILE or $IAC_USER_ENV_FILE" >&2
    exit 1
  fi
  PORTAINER_API_KEY="$key"

  echo "   Portainer: $PORTAINER_URL"
  echo "   API key:   $source"
}

# portainer_curl ARGS... — curl with the API key header. The header is passed
# through a file descriptor so the key never appears in the process list.
portainer_curl() {
  curl -sS --fail-with-body -H @<(printf 'X-Api-Key: %s\n' "$PORTAINER_API_KEY") "$@"
}

# portainer_stacks_named NAME — read a GET /api/stacks body on stdin, print the
# stacks whose Name is exactly NAME, one compact JSON object per line. Portainer
# ignores /api/stacks?name=, so the match has to happen here. Fails on anything
# that is not a JSON array (an error body, say) instead of matching nothing.
portainer_stacks_named() {
  jq -c --arg name "$1" '
    if type == "array" then .[] | select(.Name == $name)
    else error("expected a JSON array of stacks, got \(type)") end'
}

# portainer_find_stack STACK — print the existing Portainer stacks named STACK
# (see portainer_stacks_named); empty when there are none.
portainer_find_stack() {
  local stack="$1" stacks
  if ! stacks="$(portainer_curl "$PORTAINER_URL/api/stacks")"; then
    echo "ERROR: GET $PORTAINER_URL/api/stacks failed: $stacks" >&2
    exit 1
  fi
  if ! printf '%s' "$stacks" | portainer_stacks_named "$stack"; then
    echo "ERROR: could not read the stack list from $PORTAINER_URL/api/stacks" >&2
    exit 1
  fi
}

# redeploy_body — read one stack object on stdin, print the git redeploy body:
# its current Env passed back unchanged, prune on, same git ref.
redeploy_body() {
  jq -c '{
    env: (.Env // []),
    prune: true,
    pullImage: false,
    repositoryReferenceName: (.GitConfig.ReferenceName // "refs/heads/main")
  }'
}

cmd_api() {
  local stack="$1"
  require_stack "$stack"

  local git_url="https://github.com/isaackehle/iac.git"
  local git_branch="main"
  local compose_path="$stack/docker-compose.yml"
  local endpoint="$PORTAINER_ENDPOINT"

  echo "==> $stack: creating GitOps stack in Portainer via API..."
  echo "  Note: This creates a REPOSITORY-based stack (GitOps)."
  echo "  Portainer will pull docker-compose.yml from GitHub automatically."
  echo "  It only creates: an existing stack is never deleted or replaced."
  echo ""

  portainer_auth "$stack"
  echo ""

  # Refuse when the stack already exists. Checked before the port check, which
  # would otherwise report the existing stack's own ports as conflicts.
  echo "==> $stack: checking for an existing Portainer stack named '$stack'..."
  local existing
  existing="$(portainer_find_stack "$stack")"
  if [[ -n "$existing" ]]; then
    echo ""
    echo "ERROR: Portainer already has a stack named '$stack'. Nothing was changed."
    printf '%s\n' "$existing" | jq -r '"   - Id \(.Id), endpoint \(.EndpointId), status \(.Status)"'
    echo ""
    echo "   To pull the latest compose file from git and redeploy it, keeping its"
    echo "   current variables:"
    echo "     scripts/deploy.sh redeploy $stack"
    echo ""
    echo "   That is PUT /api/stacks/<Id>/git/redeploy?endpointId=$endpoint with body"
    echo '   {"env": <the stack'"'"'s Env, unchanged>, "prune": true, "pullImage": false,'
    echo '    "repositoryReferenceName": "refs/heads/main"}'
    exit 1
  fi
  echo "   ✓ No existing stack, proceeding with creation"
  echo ""

  # Extract port mappings from compose file for pre-check
  local port_mappings
  port_mappings=$(grep -E '^\s+-\s+"?[0-9]+' "$compose_path" 2>/dev/null | head -20 || true)

  # Pre-deployment port check (limited - Portainer API doesn't expose all container ports)
  if [[ -n "$port_mappings" ]]; then
    echo "==> $stack: checking for port conflicts..."
    
    # Extract host ports from mappings (format: "8280:80/tcp" or "53:53/udp")
    local port_conflicts=()
    
    while IFS= read -r mapping; do
      [[ -z "$mapping" ]] && continue
      # Extract the host port (before the colon, remove quotes and protocol)
      local host_port
      host_port=$(echo "$mapping" | sed 's/^[[:space:]]*-[[:space:]]*//' | sed 's/"//g' | cut -d: -f1 | sed 's/[^0-9]//g')
      [[ -z "$host_port" ]] && continue
      
      # Try to detect port conflicts via Portainer Docker API
      # Note: This only works for containers managed through Portainer
      local containers_with_port
      containers_with_port=$(portainer_curl \
        "$PORTAINER_URL/api/docker/endpoints/$endpoint/container?all=1" 2>/dev/null || true)
      
      if echo "$containers_with_port" | grep -q "\"HostPort\":\"$host_port\""; then
        # Extract container names using the port
        local affected_containers
        affected_containers=$(echo "$containers_with_port" | grep -B 30 "\"HostPort\":\"$host_port\"" | grep '"Name":' | \
          sed 's/.*"Name":\s*"\([^"]*\)".*/\1/' | sort -u | tr '\n' ' ')
        
        if [[ -n "$affected_containers" ]]; then
          port_conflicts+=("$host_port (used by: $affected_containers)")
        fi
      fi
    done <<< "$port_mappings"
    
    if [[ ${#port_conflicts[@]} -gt 0 ]]; then
      echo ""
      echo "ERROR: Port conflict detected!"
      echo ""
      echo "   The following ports are already in use:"
      for conflict in "${port_conflicts[@]}"; do
        echo "   - $conflict"
      done
      echo ""
      echo "   To fix:"
      echo "   1. Stop the conflicting containers:"
      echo "      - Via Portainer UI: Stacks → Remove the stack(s) using these ports"
      echo "      - Via SSH: docker compose -f <path>/docker-compose.yml down"
      echo ""
      echo "   2. Or change the port mappings in $compose_path"
      echo ""
      exit 1
    else
      echo "   ✓ No port conflicts detected via Portainer API"
      echo "   Note: Unmanaged containers (legacy deployments) may still conflict"
      echo ""
    fi
  fi

  # Build env JSON array from .env file
  local env_json="["
  local first=true
  local env_count=0
  if [[ -f "$stack/.env" ]]; then
    echo "==> $stack: reading environment variables from $stack/.env"
    while IFS='=' read -r key value || [[ -n "$key" ]]; do
      [[ "$key" =~ ^[[:space:]]*# ]] && continue
      [[ -z "$key" ]] && continue
      key=$(echo "$key" | xargs)
      value=$(echo "$value" | xargs)
      [[ -z "$key" ]] && continue
      value=$(printf '%s' "$value" | sed 's/\\/\\\\/g; s/"/\\"/g')
      
      if [[ "$first" == true ]]; then
        first=false
      else
        env_json+=","
      fi
      env_json+="{\"name\":\"$key\",\"value\":\"$value\"}"
      echo "   → $key"
      env_count=$((env_count + 1))
    done < "$stack/.env"
  else
    echo "   ⚠ Warning: $stack/.env not found, creating stack without environment variables"
  fi
  env_json+="]"

  echo "   Total environment variables: $env_count"
  echo ""

  # Build the repository-stack payload using the GitOps endpoint
  local stack_json
  stack_json=$(cat <<EOF
{
  "name": "$stack",
  "composeFile": "$compose_path",
  "repositoryURL": "$git_url",
  "repositoryReferenceName": "refs/heads/$git_branch",
  "repositoryAuthentication": false,
  "env": $env_json
}
EOF
  )

  echo "==> $stack: constructing API payload"
  echo "   Stack name: $stack"
  echo "   Compose path: $compose_path"
  echo "   Repository: $git_url"
  echo "   Branch: $git_branch"
  echo "   Endpoint ID: $endpoint"
  echo ""

  # Portainer 2.39 API: POST /api/stacks/create/standalone/repository?endpointId=<id>
  local api_url="$PORTAINER_URL/api/stacks/create/standalone/repository?endpointId=$endpoint"
  echo "==> $stack: making API request"
  echo "   Method: POST"
  echo "   URL: $api_url"
  echo "   Headers:"
  echo "     Content-Type: application/json"
  echo "     X-Api-Key: (redacted)"
  echo ""

  # The body goes in on stdin so the env values stay out of the process list.
  # An HTTP error still leaves its body in stack_response for the checks below.
  local stack_response
  stack_response=$(printf '%s' "$stack_json" | portainer_curl -X POST \
    -H "Content-Type: application/json" \
    --data-binary @- \
    "$api_url") || true


  echo "==> $stack: received API response"
  echo "   Response length: $(echo "$stack_response" | wc -c) bytes"
  echo ""

  if echo "$stack_response" | grep -q '"message"'; then
    echo "ERROR: Failed to create stack:"
    echo "$stack_response" | jq . 2>/dev/null || echo "$stack_response"
    echo ""
    
    # Check for common error patterns and provide helpful suggestions
    if echo "$stack_response" | grep -q "port is already allocated"; then
      echo "⚠ HINT: Port is already in use. This usually means:"
      echo "  1. A legacy SSH deployment exists (not managed by Portainer)"
      echo "  2. Another service is using that port"
      echo ""
      echo "   GitOps stacks use: /volume1/docker/stacks/<stack-name>"
      echo "   Legacy SSH deployments use original paths:"
      echo "   - homeassistant: /volume1/docker/homeassistant"
      echo "   - pihole: /volume1/docker/pihole"
      echo "   - plex: /volume1/docker/plex"
      echo "   - postgresql: /volume1/docker/postgresql"
      echo ""
      echo "   To fix, SSH into your NAS and stop the legacy deployment:"
      echo "   cd /volume1/docker/pihole"
      echo "   docker compose down"
      echo ""
      echo "   Or find it in Container Manager UI and remove it."
      echo ""
      echo "   After stopping the legacy deployment, run this command again:"
      echo "   ./scripts/deploy.sh api pihole"
    elif echo "$stack_response" | grep -qi "already exists"; then
      echo "⚠ HINT: A stack with this name already exists."
      echo "   To redeploy it from git with its current variables:"
      echo "     scripts/deploy.sh redeploy $stack"
    fi
    
    exit 1
  fi

  local stack_id
  stack_id=$(echo "$stack_response" | jq -r '.Id // empty')

  if [[ -z "$stack_id" || "$stack_id" == "null" ]]; then
    echo "ERROR: Failed to extract stack ID"
    echo "Response was: $stack_response"
    exit 1
  fi

  echo "   ✓ Stack created successfully"
  echo "   Stack ID: $stack_id"
  echo "   → GitOps mode (will pull from GitHub automatically)"
}

# cmd_redeploy STACK [--yes] — pull the stack's compose file from git and
# redeploy it: PUT /api/stacks/<id>/git/redeploy with the stack's current Env
# passed back unchanged and prune on. Variables are not changed; edit them in
# Portainer. Asks before redeploying unless --yes is given.
cmd_redeploy() {
  local stack="$1" assume_yes="${2:-}"
  require_stack "$stack"
  if [[ -n "$assume_yes" && "$assume_yes" != "--yes" ]]; then
    usage
  fi
  local endpoint="$PORTAINER_ENDPOINT"

  echo "==> $stack: git redeploy through the Portainer API"
  portainer_auth "$stack"
  echo ""

  local existing count
  existing="$(portainer_find_stack "$stack")"
  count="$(printf '%s' "$existing" | grep -c . || true)"
  if [[ "$count" -eq 0 ]]; then
    echo "ERROR: Portainer has no stack named '$stack'. Create it with: scripts/deploy.sh api $stack" >&2
    exit 1
  fi
  if [[ "$count" -gt 1 ]]; then
    echo "ERROR: Portainer has $count stacks named '$stack'; refusing to pick one:" >&2
    printf '%s\n' "$existing" | jq -r '"   - Id \(.Id), endpoint \(.EndpointId)"' >&2
    exit 1
  fi

  local id stack_endpoint ref git_url compose env_names
  id="$(jq -r '.Id' <<< "$existing")"
  stack_endpoint="$(jq -r '.EndpointId' <<< "$existing")"
  ref="$(jq -r '.GitConfig.ReferenceName // empty' <<< "$existing")"
  git_url="$(jq -r '.GitConfig.URL // empty' <<< "$existing")"
  compose="$(jq -r '.GitConfig.ConfigFilePath // .EntryPoint // empty' <<< "$existing")"
  env_names="$(jq -r '[(.Env // [])[].name] | join(" ")' <<< "$existing")"

  if [[ "$stack_endpoint" != "$endpoint" ]]; then
    echo "ERROR: stack '$stack' (Id $id) is on endpoint $stack_endpoint, expected $endpoint; refusing" >&2
    exit 1
  fi
  if [[ -z "$git_url" ]]; then
    echo "ERROR: stack '$stack' (Id $id) is not a git stack; redeploy it from the Portainer UI" >&2
    exit 1
  fi

  echo "   Stack:     $stack (Id $id, endpoint $stack_endpoint)"
  echo "   Git:       $git_url ${ref:-refs/heads/main} $compose"
  echo "   Variables: ${env_names:-(none)} (passed back unchanged)"
  echo "   Request:   PUT /api/stacks/$id/git/redeploy?endpointId=$endpoint, prune true"
  echo ""

  if [[ "$assume_yes" != "--yes" ]]; then
    if [[ ! -t 0 ]]; then
      echo "ERROR: not a terminal; re-run with --yes to redeploy without asking" >&2
      exit 1
    fi
    local answer
    read -r -p "Redeploy '$stack' (Id $id)? [y/N] " answer
    if [[ "$answer" != [yY] ]]; then
      echo "Aborted, nothing changed."
      exit 1
    fi
  fi

  local response
  if ! response="$(redeploy_body <<< "$existing" | portainer_curl -X PUT \
      -H "Content-Type: application/json" \
      --data-binary @- \
      "$PORTAINER_URL/api/stacks/$id/git/redeploy?endpointId=$endpoint")"; then
    echo "ERROR: redeploy failed:" >&2
    jq . <<< "$response" >&2 2>/dev/null || echo "$response" >&2
    exit 1
  fi

  echo "   ✓ Redeployed '$stack' (Id $(jq -r '.Id // "?"' <<< "$response"))"
}

cmd_all() {
  local stack="$1" host="$2"
  cmd_env "$stack"
  cmd_dirs "$stack" "$host"
  cmd_push "$stack" "$host"
  cmd_serve "$stack" "$host"
  cmd_up "$stack" "$host"
}

cmd_info() {
  local stack="$1"
  require_stack "$stack"

  local remote="${STACK_REMOTE_DIR[$stack]}"
  local compose
  compose="$(compose_file_for "$stack")"
  local dirs="${STACK_DIRS[$stack]:-}"
  local extras="${STACK_EXTRA_FILES[$stack]:-}"
  local mappings="${STACK_SERVE_PORTS[$stack]:-}"

  echo ""
  echo "=== Deploy: $stack ==="
  echo ""

  # Step 1: generate .env
  echo "1. Generate .env:"
  echo "   scripts/deploy.sh env $stack"
  echo ""

  # Step 2: create directories
  echo "2. Create directories on the NAS:"
  echo "   scripts/deploy.sh dirs $stack <ssh-host>"
  if [[ -n "$dirs" ]]; then
    for d in $dirs; do
      echo "   → $remote/$d"
    done
  fi
  echo ""

  # Step 3: push files
  echo "3. Push files to the NAS:"
  echo "   scripts/deploy.sh push $stack <ssh-host>"
  echo "   → $compose"
  if [[ -n "$extras" ]]; then
    for pair in $extras; do
      local local_path="${pair%%:*}"
      echo "   → $local_path"
    done
  fi
  echo ""

  # Step 4: serve mappings (if any)
  if [[ -n "$mappings" ]]; then
    echo "4. Apply Tailscale serve mappings:"
    echo "   scripts/deploy.sh serve $stack <ssh-host>"
    for pair in $mappings; do
      local port="${pair%%:*}"
      local backend="${pair#*:}"
      echo "   → :$port → $backend"
    done
    echo ""
  else
    echo "4. (skip — no host-level serve mappings; sidecar handles it)"
    echo ""
  fi

  # Step 5: bring it up
  echo "5. Start the stack:"
  echo "   scripts/deploy.sh up $stack <ssh-host>"
  echo ""

  # Access info
  echo "---"
  echo "Access: see $stack/DEBUG.md for URLs and debug commands"
  echo ""
}

[[ $# -ge 2 ]] || usage
command="$1"
stack="$2"
host="${3:-}"

cd "$ROOT_DIR"

case "$command" in
  env|info)
    cmd_"$command" "$stack"
    ;;
  dirs|push|extras|serve|up|down|all)
    [[ -n "$host" ]] || usage
    "cmd_${command}" "$stack" "$host"
    ;;
  api)
    cmd_"$command" "$stack"
    ;;
  redeploy)
    cmd_redeploy "$stack" "$host"
    ;;
  *)
    usage
    ;;
esac
