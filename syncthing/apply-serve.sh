#!/usr/bin/env bash
set -euo pipefail

COMPOSE_FILE="${COMPOSE_FILE:-$(dirname "$0")/docker-compose.yaml}"
STACK_DIR="$(cd "$(dirname "$0")" && pwd)"

if [[ ! -f "$COMPOSE_FILE" ]]; then
  echo "Compose file not found: $COMPOSE_FILE" >&2
  exit 1
fi

reset=false
if [[ "${1:-}" == "--reset" ]]; then
  reset=true
fi

extract_ports() {
  awk '
    /^[[:space:]]*ports:/ { in_ports=1; next }
    in_ports && /^[[:space:]]*-[[:space:]]*'\''[^'\'']+'\''/ {
      gsub(/^[[:space:]]*-[[:space:]]*'\''/, "", $0)
      gsub(/'\''[[:space:]]*$/, "", $0)
      print $0
      next
    }
    in_ports && /^[^[:space:]]/ { in_ports=0 }
  ' "$COMPOSE_FILE"
}

apply_port() {
  local mapping="$1"

  if [[ "$mapping" == */udp ]]; then
    echo "Skipping UDP mapping: $mapping"
    return 0
  fi

  local cleaned proto host_port container_port
  cleaned="${mapping%/tcp}"
  proto="tcp"

  IFS=':' read -r host_port container_port <<< "$cleaned"

  if [[ -z "${host_port:-}" || -z "${container_port:-}" ]]; then
    echo "Skipping unsupported port mapping: $mapping"
    return 0
  fi

  case "$container_port" in
    8384)
      echo "Applying Tailscale Serve for Syncthing UI on :$host_port -> http://127.0.0.1:$host_port"
      tailscale serve --bg "https:${host_port}" "http://127.0.0.1:${host_port}"
      ;;
    *)
      echo "Skipping non-HTTP TCP mapping: $mapping"
      ;;
  esac
}

if $reset; then
  echo "Resetting Tailscale Serve config for Syncthing-known HTTPS port(s)..."
  for mapping in $(extract_ports); do
    [[ "$mapping" == */udp ]] && continue
    cleaned="${mapping%/tcp}"
    IFS=':' read -r host_port container_port <<< "$cleaned"
    if [[ "${container_port:-}" == "8384" ]]; then
      tailscale serve --https="$host_port" off || true
    fi
  done
fi

while IFS= read -r mapping; do
  [[ -n "$mapping" ]] || continue
  apply_port "$mapping"
done < <(extract_ports)

tailscale serve status