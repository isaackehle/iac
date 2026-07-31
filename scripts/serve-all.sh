#!/usr/bin/env bash
# scripts/serve-all.sh — apply every stack's host-level tailscale serve
# mappings in one pass. Replaces the old root-level apply-serve.sh, which
# scanned for per-stack apply-serve.sh scripts; mappings now live in
# scripts/lib.sh (STACK_SERVE_PORTS) instead of being duplicated per stack.
#
# Usage:
#   scripts/serve-all.sh <ssh-host>              # apply all mappings
#   scripts/serve-all.sh <ssh-host> --reset      # reset first, then apply all

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib.sh
source "$ROOT_DIR/scripts/lib.sh"

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <ssh-host> [--reset]" >&2
  exit 1
fi

host="$1"
reset="${2:-}"

if [[ "$reset" == "--reset" ]]; then
  echo "Resetting all tailscale serve config on $host..."
  ssh "$host" "sudo tailscale serve reset"
  echo
fi

failed=0
for stack in "${ALL_STACKS[@]}"; do
  if [[ -n "${STACK_SERVE_PORTS[$stack]:-}" ]]; then
    "$ROOT_DIR/scripts/deploy.sh" serve "$stack" "$host" || failed=1
  fi
done

echo
echo "Current tailscale serve status on $host:"
ssh "$host" "tailscale serve status"

exit "$failed"
