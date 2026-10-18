#!/bin/sh
# docker-state: every INTERVAL seconds, write the state of EVERY container on the
# NAS (stopped ones too) as Prometheus metrics for node-exporter's textfile
# collector. cAdvisor only knows running containers, so a container that never
# came back after a reboot simply vanished from it; this is what ContainerDown
# alerts on.
#
# "Should be running" is the boot guard's rule (scripts/docker-boot-guard.sh):
# restart policy unless-stopped/always, and not stopped by hand
# ("HasBeenManuallyStopped":true in @docker/containers/<id>/config.v2.json).
#
# Metrics (label name=<container>):
#   docker_container_running        1 if running
#   docker_container_should_run     1 if it ought to be running
#   docker_container_unhealthy      1 if its healthcheck says unhealthy
#   docker_container_restarts_total  Docker's restart counter
#   docker_state_last_run_timestamp_seconds  when this file was last written
#
# If Docker can't be listed the file is left alone and goes stale, which fires
# DockerStateStale rather than a false all-clear.

OUT=/textfile/docker_state.prom
CONTAINERS=/docker-containers
INTERVAL=${INTERVAL:-30}

collect() {
  ids=$(docker ps -aq --no-trunc) || return 1
  [ -n "$ids" ] || return 0
  # "|"-separated: health is empty for containers without a healthcheck, and the
  # restart policy can be empty too, so whitespace splitting would shift columns.
  # {{.ID}}, not {{.Id}}: an unknown field makes the CLI retry against the raw
  # JSON map, where .State.Health is missing for containers without a
  # healthcheck, and those containers silently drop out of the output.
  # shellcheck disable=SC2086 # one argument per id
  docker inspect --type container -f '{{.ID}}|{{.Name}}|{{.HostConfig.RestartPolicy.Name}}|{{.State.Running}}|{{if .State.Health}}{{.State.Health.Status}}{{end}}|{{.RestartCount}}' $ids 2>/dev/null |
    while IFS='|' read -r id name policy running health restarts; do
      manual=0
      grep -q '"HasBeenManuallyStopped":true' "$CONTAINERS/$id/config.v2.json" 2>/dev/null && manual=1
      echo "${name#/}|$policy|$running|$health|$restarts|$manual"
    done
}

while :; do
  if rows=$(collect); then
    echo "$rows" | awk -F'|' -v now="$(date +%s)" '
      NF == 6 && $1 != "" {
        n = $1
        run[n] = ($3 == "true")
        should[n] = (($2 == "unless-stopped" || $2 == "always") && $6 == 0)
        unhealthy[n] = ($4 == "unhealthy")
        restarts[n] = $5
      }
      END {
        print "# HELP docker_container_running 1 if the container is running."
        print "# TYPE docker_container_running gauge"
        for (n in run) printf "docker_container_running{name=\"%s\"} %d\n", n, run[n]
        print "# HELP docker_container_should_run 1 if restart policy is unless-stopped/always and it was not stopped by hand."
        print "# TYPE docker_container_should_run gauge"
        for (n in should) printf "docker_container_should_run{name=\"%s\"} %d\n", n, should[n]
        print "# HELP docker_container_unhealthy 1 if the container healthcheck reports unhealthy."
        print "# TYPE docker_container_unhealthy gauge"
        for (n in unhealthy) printf "docker_container_unhealthy{name=\"%s\"} %d\n", n, unhealthy[n]
        print "# HELP docker_container_restarts_total Docker restart count of the container."
        print "# TYPE docker_container_restarts_total counter"
        for (n in restarts) printf "docker_container_restarts_total{name=\"%s\"} %d\n", n, restarts[n]
        print "# HELP docker_state_last_run_timestamp_seconds Unix time docker-state last wrote this file."
        print "# TYPE docker_state_last_run_timestamp_seconds gauge"
        printf "docker_state_last_run_timestamp_seconds %d\n", now
      }' > "$OUT.tmp" && chmod 0644 "$OUT.tmp" && mv "$OUT.tmp" "$OUT"
  else
    echo "$(date -u +%FT%TZ) docker-state: cannot list containers; leaving $OUT to go stale" >&2
  fi
  sleep "$INTERVAL"
done
