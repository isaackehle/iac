#!/usr/bin/env bash
# apply-serve.sh — top-level runner for voyager IAC repo
# Traverses every subdirectory and executes apply-serve.sh if found.
# Idempotent — safe to re-run at any time.
#
# Usage:
#   ./apply-serve.sh              # apply all stacks
#   ./apply-serve.sh --reset      # tailscale serve reset first, then apply all
#
# Structure expected:
#   ./<stack>/apply-serve.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ "${1:-}" == "--reset" ]]; then
  echo "Resetting all tailscale serve config..."
  tailscale serve reset
  echo ""
fi

echo "Applying tailscale serve config — scanning $(basename "$SCRIPT_DIR")/"
echo ""

found=0
failed=0

for stack_dir in "$SCRIPT_DIR"/*/; do
  stack="$(basename "$stack_dir")"
  script="$stack_dir/apply-serve.sh"

  if [[ -x "$script" ]]; then
    echo "── $stack"
    if bash "$script"; then
      (( found++ ))
    else
      echo "  ✗ FAILED: $stack"
      (( failed++ ))
    fi
    echo ""
  fi
done


echo "────────────────────────────────────────"
echo "Applied: $found stack(s)  |  Failed: $failed"
echo ""
echo "Current tailscale serve status:"
tailscale serve status
