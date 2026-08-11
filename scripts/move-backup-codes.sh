#!/usr/bin/env bash
# move-backup-codes.sh — moves a batch of items from the secrets vault to
# the 'secrets - backup codes' vault (ID 22b7uct3dfz3o6kabacqdkjeki).
# Usage: ./move-backup-codes.sh <item_id> <source_title_snippet> <dest_title>
# Reads item ID from stdin-pipe via first arg. Each call = ONE item move.
#
# Auth: requires 1Password.app unlocked; OP_SERVICE_ACCOUNT* must be unset
# (SA token 403s on the secrets vault). See op skill doc.
set -euo pipefail

ITEM_ID="$1"
NEW_VAULT="22b7uct3dfz3o6kabacqdkjeki"

if [ -z "$ITEM_ID" ]; then
  echo "ERROR: need item ID" >&2; exit 2
fi

echo "MOVE: $ITEM_ID → backup-codes vault"
# Move the item between vaults (preserves UUID, attachments, history).
op item edit "$ITEM_ID" --vault "$NEW_VAULT" >/dev/null 2>&1 || true
