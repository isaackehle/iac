#!/bin/sh
# docker-boot-guard: start the containers that DSM Container Manager failed to
# start at boot.
#
# How it fails: at boot, Container Manager starts containers one at a time,
# about 5s apart. A container that joins another container's network
# (network_mode: container:/service:) fails if Container Manager reaches it
# before the container that owns that network ("Failed to cRunWithDep()" in
# /var/log/messages). Docker's restart policy never retries a container that
# failed to start, and State.Error may stay empty.
#
# This script runs as a DSM Task Scheduler boot-up task, as root. It waits for
# dockerd, gives Container Manager time to finish its own pass, then starts
# every container that is not running, has an unless-stopped/always restart
# policy, and was not stopped by hand. A container that joins another's network
# is only started once that network owner is running.
#
# Install and verify: docs/docker_boot_guard.md
#
# Usage: docker-boot-guard.sh [--dry-run] [--now] [--match REGEX]
#   --dry-run  report what would be started; start nothing (one pass)
#   --now      skip the boot settle delay
#   --match    only consider containers whose name matches REGEX (testing)

D=/usr/local/bin/docker
SETTLE=180 PASSES=6 INTERVAL=30
DRY=0 NOW=0 MATCH=.
while [ $# -gt 0 ]; do
  case $1 in
    --dry-run) DRY=1 ;;
    --now) NOW=1 ;;
    --match) MATCH=$2; shift ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
  shift
done

# DSM's syslog drops logger(1) lines, so keep our own log.
LOG=/var/log/docker-boot-guard.log
log() { echo "$(date -u +%FT%TZ) $*" | tee -a "$LOG"; }

i=0
until $D info >/dev/null 2>&1; do
  i=$((i + 1))
  [ $i -gt 120 ] && { log "dockerd not up after 10 min, giving up"; exit 1; }
  sleep 5
done
[ $NOW = 1 ] || [ $DRY = 1 ] || sleep $SETTLE
ROOT=$($D info -f '{{.DockerRootDir}}')

name_of() { $D inspect -f '{{.Name}}' "$1" 2>/dev/null | sed 's#^/##'; }
is_running() { [ "$($D inspect -f '{{.State.Running}}' "$1" 2>/dev/null)" = true ]; }

# Print "id name network" for every container that should be running but isn't.
eligible() {
  for id in $($D ps -aq --no-trunc --filter status=exited --filter status=created); do
    # shellcheck disable=SC2046 # split "name policy network" into $1 $2 $3
    set -- $($D inspect -f '{{.Name}} {{.HostConfig.RestartPolicy.Name}} {{.HostConfig.NetworkMode}}' "$id")
    name=${1#/} policy=$2 net=$3
    echo "$name" | grep -Eq -- "$MATCH" || continue
    case $policy in unless-stopped | always) ;; *) continue ;; esac
    grep -q '"HasBeenManuallyStopped":true' "$ROOT/containers/$id/config.v2.json" 2>/dev/null && continue
    echo "$id $name $net"
  done
}

start() { # id name
  if [ $DRY = 1 ]; then
    log "dry-run: would start $2"
  elif $D start "$1" >/dev/null 2>&1; then
    log "started $2"
  else
    log "FAILED to start $2"
  fi
}

pass=1
while :; do
  todo=$(eligible)
  [ -z "$todo" ] && { log "pass $pass: nothing to start"; exit 0; }
  # Network owners and standalone containers first, then the containers that join them.
  # In a dry run nothing starts, so a joiner counts its owner as running if it is planned.
  planned=$(echo "$todo" | awk '$3 !~ /^container:/ {print $1}')
  echo "$todo" | while read -r id name net; do
    case $net in container:*) ;; *) start "$id" "$name" ;; esac
  done
  echo "$todo" | while read -r id name net; do
    case $net in
      container:*)
        # NetworkMode holds an id (compose) or a name (docker run); resolve to the id.
        owner=$($D inspect -f '{{.Id}}' "${net#container:}" 2>/dev/null) || owner=${net#container:}
        if is_running "$owner" || { [ $DRY = 1 ] && echo "$planned" | grep -q "$owner"; }; then
          start "$id" "$name"
        else
          log "pass $pass: $name waits for its network owner $(name_of "$owner")"
        fi
        ;;
    esac
  done
  [ $DRY = 1 ] && exit 0
  pass=$((pass + 1))
  [ $pass -gt $PASSES ] && break
  sleep $INTERVAL
done

left=$(eligible | awk '{print $2}' | tr '\n' ' ')
[ -n "$left" ] && { log "still not running after $PASSES passes: $left"; exit 1; }
exit 0
