#!/usr/bin/env bash
# scripts/gen-env.sh — render <stack>/*.tmpl files into their non-.tmpl
# counterparts.  .env files are no longer generated from a central secrets
# file; they already exist with real values and are managed per-stack.
#
# Usage:
#   scripts/gen-env.sh <stack>          # render templates for one stack
#   scripts/gen-env.sh --all            # render templates for every stack
#
# This script is idempotent.  Running it multiple times produces the same
# output.

# shellcheck disable=SC2034
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/lib.sh
source "$ROOT_DIR/scripts/lib.sh"

gen_one() {
  local stack="$1"
  require_stack "$stack"

  render_templates "$stack"
  echo "==> $stack: done"
}

[[ $# -eq 1 ]] || usage

cd "$ROOT_DIR"

if [[ "$1" == "--all" ]]; then
  while IFS= read -r s; do
    gen_one "$s"
  done < <(enabled_stacks)
else
  gen_one "$1"
fi
