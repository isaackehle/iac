#!/usr/bin/env bash
# scripts/deploy.sh — push a stack's compose/env/config files to the NAS and
# (optionally) bring it up, all driven from the laptop over SSH.
#
# Replaces the old per-stack init.sh / apply-serve.sh / deploy-*.sh scripts.
# Directory layout and file lists come from scripts/lib.sh, so every stack
# is provisioned the same way instead of each having bespoke setup logic.
#
# Usage:
#   scripts/deploy.sh env   <stack>                 # generate <stack>/.env locally
#   scripts/deploy.sh dirs  <stack> <ssh-host>       # mkdir -p + chown on the NAS
#   scripts/deploy.sh push  <stack> <ssh-host>       # scp compose/.env/extra files
#   scripts/deploy.sh serve <stack> <ssh-host>       # apply host-level tailscale serve (Pattern A/hybrid stacks)
#   scripts/deploy.sh up    <stack> <ssh-host>       # ssh in, docker compose up -d
#   scripts/deploy.sh all   <stack> <ssh-host>       # env + dirs + push + serve + up
#
# <ssh-host> is anything ssh/scp accepts, e.g. `nas` (an ssh config alias)
# or `user@192.168.1.20`.

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
  serve  <stack> <ssh-host>    apply host-level tailscale serve mappings (if any)
  up     <stack> <ssh-host>    ssh in and run `docker compose up -d`
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
  scp "$stack/$compose" "$host:$remote/$compose"

  if [[ -f "$stack/.env" ]]; then
    echo "==> $stack: pushing .env to $host:$remote/"
    scp "$stack/.env" "$host:$remote/.env"
  fi

  local extras="${STACK_EXTRA_FILES[$stack]:-}"
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
    scp "$stack/$local_path" "$host:$remote/$remote_rel"
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
    ssh "$host" "sudo tailscale serve --bg --https=$port '$backend'"
  done
}

cmd_up() {
  local stack="$1" host="$2"
  require_stack "$stack"
  local remote="${STACK_REMOTE_DIR[$stack]}"
  local compose
  compose="$(compose_file_for "$stack")"

  echo "==> $stack: docker compose up -d on $host"
  ssh "$host" "cd '$remote' && docker compose -f '$compose' up -d"
}

cmd_all() {
  local stack="$1" host="$2"
  cmd_env "$stack"
  cmd_dirs "$stack" "$host"
  cmd_push "$stack" "$host"
  cmd_serve "$stack" "$host"
  cmd_up "$stack" "$host"
}

[[ $# -ge 2 ]] || usage
command="$1"
stack="$2"
host="${3:-}"

cd "$ROOT_DIR"

case "$command" in
  env)
    cmd_env "$stack"
    ;;
  dirs|push|serve|up|all)
    [[ -n "$host" ]] || usage
    "cmd_${command}" "$stack" "$host"
    ;;
  *)
    usage
    ;;
esac
