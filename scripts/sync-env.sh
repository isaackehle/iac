#!/bin/bash
# scripts/sync-env.sh
# Sync .env files between local machine and Synology NAS
#
# Usage:
#   ./scripts/sync-env.sh push <stack>     # Push .env to NAS
#   ./scripts/sync-env.sh pull <stack>     # Pull .env from NAS
#   ./scripts/sync-env.sh list             # List all stacks
#   ./scripts/sync-env.sh push-all         # Push all .env files to NAS
#   ./scripts/sync-env.sh pull-all         # Pull all .env files from NAS
#
# SSH Configuration:
#   Add to ~/.ssh/config:
#     Host nas
#         HostName nas.tail303fda.ts.net
#         User isaac
#         IdentityFile ~/.ssh/id_ed25519
#   Then use 'nas' instead of full hostname

set -e

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SSH_HOST="${SSH_HOST:-isaac@nas.tail303fda.ts.net}"
NAS_BASE="/volume1/docker/stacks"

# All managed stacks
ALL_STACKS=(
    "homeassistant"
    "langfuse"
    "n8n"
    "nextcloud"
    "openwebui"
    "pihole"
    "plex"
    "portainer"
    "postgresql"
    "syncthing"
    "synology-mcp"
    "affine"
    "frigate"
    "mosquitto"
)

usage() {
    cat >&2 <<EOF
Usage: $(basename "$0") <command> [stack]

Commands:
    push <stack>      Push .env file to NAS
    pull <stack>      Pull .env file from NAS
    list              List all managed stacks
    push-all          Push all .env files to NAS
    pull-all          Pull all .env files from NAS

Environment Variables:
    SSH_HOST          SSH host (default: isaac@nas.tail303fda.ts.net)

Examples:
    $(basename "$0") push portainer
    $(basename "$0") pull homeassistant
    $(basename "$0") list
    $(basename "$0") push-all
    SSH_HOST=nas $(basename "$0") push portainer
EOF
    exit 1
}

push() {
    local stack="$1"
    local local_env="$ROOT_DIR/$stack/.env"
    local remote_env="$SSH_HOST:$NAS_BASE/$stack/.env"

    if [ ! -f "$local_env" ]; then
        echo "✗ Error: $local_env not found. Run 'bash scripts/gen-env.sh $stack' first." >&2
        exit 1
    fi

    echo "Pushing $stack/.env to NAS..."
    scp -O "$local_env" "$remote_env"
    echo "✓ Pushed to $remote_env"
}

pull() {
    local stack="$1"
    local remote_env="$SSH_HOST:$NAS_BASE/$stack/.env"
    local local_env="$ROOT_DIR/$stack/.env"

    echo "Pulling .env from NAS..."
    scp -O "$remote_env" "$local_env"
    echo "✓ Pulled to $local_env"
}

list_stacks() {
    echo "Managed stacks:"
    for stack in "${ALL_STACKS[@]}"; do
        echo "  - $stack"
    done
}

push_all() {
    echo "Pushing all .env files to NAS..."
    for stack in "${ALL_STACKS[@]}"; do
        local local_env="$ROOT_DIR/$stack/.env"
        if [ -f "$local_env" ]; then
            push "$stack"
        else
            echo "⚠ Skipping $stack (no .env file)"
        fi
    done
    echo "✓ All .env files pushed"
}

pull_all() {
    echo "Pulling all .env files from NAS..."
    for stack in "${ALL_STACKS[@]}"; do
        pull "$stack"
    done
    echo "✓ All .env files pulled"
}

# Main
case "${1:-}" in
    push)
        [ -z "$2" ] && { echo "✗ Error: Stack name required" >&2; usage; }
        push "$2"
        ;;
    pull)
        [ -z "$2" ] && { echo "✗ Error: Stack name required" >&2; usage; }
        pull "$2"
        ;;
    list)
        list_stacks
        ;;
    push-all)
        push_all
        ;;
    pull-all)
        pull_all
        ;;
    *)
        usage
        ;;
esac
