#!/usr/bin/env bash
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
#                                                     # config (serve.json, Caddyfile,
#                                                     # etc.) — no compose file, no
#                                                     # .env
#   scripts/deploy.sh serve  <stack> <ssh-host>       # apply host-level tailscale serve (Pattern A/hybrid stacks)
#   scripts/deploy.sh up     <stack> <ssh-host>       # ssh in, docker compose up -d
#   scripts/deploy.sh api    <stack>                  # create stack in Portainer via API with GitConfig (Total control)
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
# host bind-mounts (serve.json, Caddyfile, ...).

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
  api    <stack>               create stack in Portainer via API with GitConfig (Total control)
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

cmd_api() {
  local stack="$1"
  require_stack "$stack"

  local git_url="https://github.com/isaackehle/iac.git"
  local git_branch="main"
  local compose_path="$stack/docker-compose.yml"
  local endpoint=3

  echo "==> $stack: creating GitOps stack in Portainer via API..."
  echo "  Note: This creates a REPOSITORY-based stack (GitOps)."
  echo "  Portainer will pull docker-compose.yml from GitHub automatically."
  echo ""

  # Source secrets file if it exists (resolves op:// references via get_secret_value)
  if [[ -f "$IAC_SECRETS_FILE" ]]; then
    echo "==> $stack: sourcing secrets from $IAC_SECRETS_FILE"
    
    # Extract PORTAINER_URL and PORTAINER_API_KEY, resolving op:// references
    if [[ -n "${PORTAINER_URL:-}" ]]; then
      echo "   Using PORTAINER_URL from environment"
    elif PORTAINER_URL_VAL=$(get_secret_value "PORTAINER_URL"); then
      export PORTAINER_URL="$PORTAINER_URL_VAL"
      echo "   Resolved PORTAINER_URL from secrets file"
    else
      echo "ERROR: PORTAINER_URL not set in environment or $IAC_SECRETS_FILE" >&2
      exit 1
    fi
    
    if [[ -n "${PORTAINER_API_KEY:-}" ]]; then
      echo "   Using PORTAINER_API_KEY from environment"
    elif PORTAINER_API_KEY_VAL=$(get_secret_value "PORTAINER_API_KEY"); then
      export PORTAINER_API_KEY="$PORTAINER_API_KEY_VAL"
      echo "   Resolved PORTAINER_API_KEY from secrets file"
    else
      echo "ERROR: PORTAINER_API_KEY not set in environment or $IAC_SECRETS_FILE" >&2
      exit 1
    fi
  else
    echo "ERROR: secrets file not found at $IAC_SECRETS_FILE" >&2
    exit 1
  fi

  if [[ -z "${PORTAINER_API_KEY:-}" ]]; then
    echo "ERROR: PORTAINER_API_KEY not set after sourcing secrets" >&2
    exit 1
  fi

  if [[ -z "${PORTAINER_URL:-}" ]]; then
    echo "ERROR: PORTAINER_URL not set after sourcing secrets" >&2
    exit 1
  fi

  # Build env JSON array from .env file
  local env_json="["
  local first=true
  if [[ -f "$stack/.env" ]]; then
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
    done < "$stack/.env"
  fi
  env_json+="]"

  echo "   Environment variables: $(echo "$env_json" | jq -r 'length')"

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

  echo "   Stack JSON: $(echo "$stack_json" | jq -c .)"

  # Portainer 2.39 API: POST /api/stacks/create/standalone/repository?endpointId=<id>
  local stack_response
  stack_response=$(curl -s -X POST \
    -H "Content-Type: application/json" \
    -H "X-Api-Key: $PORTAINER_API_KEY" \
    "$PORTAINER_URL/api/stacks/create/standalone/repository?endpointId=$endpoint" \
    -d "$stack_json")

  echo "   Response: $stack_response"

  if echo "$stack_response" | grep -q '"message"'; then
    echo "ERROR: Failed to create stack:"
    echo "$stack_response" | jq . 2>/dev/null || echo "$stack_response"
    exit 1
  fi

  local stack_id
  stack_id=$(echo "$stack_response" | jq -r '.Id // empty')

  if [[ -z "$stack_id" || "$stack_id" == "null" ]]; then
    echo "ERROR: Failed to extract stack ID"
    echo "Response was: $stack_response"
    exit 1
  fi

  echo "   Stack created: ID=$stack_id"
  echo "   → GitOps mode (will pull from GitHub automatically)"
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
  dirs|push|extras|serve|up|down)
    [[ -n "$host" ]] || usage
    "cmd_${command}" "$stack" "$host"
    ;;
  api)
    cmd_"$command" "$stack"
    ;;
  *)
    usage
    ;;
esac
