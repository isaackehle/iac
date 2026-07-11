#!/usr/bin/env bash
# apply-serve.sh — top-level runner for NAS IAC repo
# Traverses every subdirectory and executes apply-serve.sh if found.
# Idempotent — safe to re-run at any time.
#
# Usage:
#   ./apply-serve.sh              # apply all stacks
#   ./apply-serve.sh --reset      # tailscale serve reset first, then apply all
#
# Structure expected:
#   ./<stack>/apply-serve.sh

set -uo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESET="${1:-}"

failed=0

if [[ "${1:-}" == "--reset" ]]; then
  echo "Resetting all tailscale serve config..."
  tailscale serve reset
  echo ""
fi

echo "Applying tailscale serve config — scanning $(basename "$ROOT_DIR")/"
echo ""

while IFS= read -r script; do
  echo "==> Running ${script#$ROOT_DIR/}"

  if [[ "$RESET" == "--reset" ]]; then
    bash "$script" --reset || failed=1
  else
    bash "$script" || failed=1
  fi

  echo
done < <(find "$ROOT_DIR" -mindepth 2 -maxdepth 2 -type f -name 'apply-serve.sh' | sort)

echo "Current tailscale serve status:"
tailscale serve status

exit "$failed"