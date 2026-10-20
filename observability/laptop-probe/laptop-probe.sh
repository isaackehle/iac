#!/bin/sh
# laptop-probe: LiteLLM on the fleet laptops (discovery, enterprise), probed the
# way a MacBook needs. blackbox probed them every 30 s like servers, so every
# sleep paged EndpointDown [critical], and every dark wake (the probe itself can
# wake a Mac with "Wake for network access") sent a ✅ and then another page.
#
# Per host, a small state machine:
#   awake       probe every AWAKE_INTERVAL (30 s); ASLEEP_AFTER (3) failures in
#               a row -> asleep
#   asleep      probe every ASLEEP_INTERVAL (30 min), so the probe does not keep
#               waking it; an answer means it woke (on its own or for the
#               request) -> confirming
#   confirming  probe again CONFIRM_DELAY (15 s) later; an answer -> awake and
#               "woke up" is logged, no answer -> it woke only briefly, back to
#               asleep
# Every transition is one level=info line on stdout, which Alloy ships to Loki
# ({container="obs-laptop-probe"}).
#
# Metrics (label host=<name>), for node-exporter's textfile collector:
#   laptop_asleep                  1 while asleep or confirming (LaptopAsleep)
#   laptop_litellm_up              1 if the last probe answered
#   laptop_wakes_total             confirmed wake-ups since this container started
#   laptop_probe_last_run_timestamp_seconds  when this file was last written
#
# Probes go through tailscaled's outbound HTTP proxy, like blackbox's: the
# sidecar is userspace, so this namespace has no tailnet route and no MagicDNS.

OUT=/textfile/laptop_probe.prom
CONF=${CONF:-/opt/laptop-probe/laptop-probe.conf}
S=/tmp/laptop-probe
LAPTOPS=${LAPTOPS:-discovery enterprise}
PROXY=${PROXY:-http://127.0.0.1:1055}
TIMEOUT=${TIMEOUT:-10}
AWAKE_INTERVAL=${AWAKE_INTERVAL:-30}
ASLEEP_INTERVAL=${ASLEEP_INTERVAL:-1800}
CONFIRM_DELAY=${CONFIRM_DELAY:-15}
ASLEEP_AFTER=${ASLEEP_AFTER:-3}
TICK=5

log() { echo "$(date -u +%FT%TZ) laptop-probe level=info $*"; }
get() { cat "$S/$1.$2" 2>/dev/null; }
put() { printf '%s' "$3" > "$S/$1.$2"; }

probe() {
  curl -fsS -o /dev/null --max-time "$TIMEOUT" -x "$PROXY" \
    "http://$1.$TS_TAILNET_DOMAIN:4000/health/liveliness" 2>/dev/null
}

step() {
  h=$1
  if probe "$h"; then up=1; else up=0; fi
  now=$(date +%s)
  put "$h" up "$up"
  case "$(get "$h" state):$up" in
    awake:1)
      put "$h" fails 0
      put "$h" next $((now + AWAKE_INTERVAL)) ;;
    awake:0)
      fails=$(($(get "$h" fails) + 1))
      put "$h" fails "$fails"
      if [ "$fails" -ge "$ASLEEP_AFTER" ]; then
        put "$h" state asleep
        put "$h" next $((now + ASLEEP_INTERVAL))
        log "host=$h event=asleep msg=\"LiteLLM missed $fails probes in a row; marked asleep, probing every $((ASLEEP_INTERVAL / 60)) min\""
      else
        put "$h" next $((now + AWAKE_INTERVAL))
      fi ;;
    asleep:1)
      put "$h" state confirming
      put "$h" next $((now + CONFIRM_DELAY))
      log "host=$h event=answered msg=\"answered while marked asleep; re-checking in $CONFIRM_DELAY s\"" ;;
    asleep:0)
      put "$h" next $((now + ASLEEP_INTERVAL)) ;;
    confirming:1)
      put "$h" state awake
      put "$h" fails 0
      put "$h" wakes $(($(get "$h" wakes) + 1))
      put "$h" next $((now + AWAKE_INTERVAL))
      log "host=$h event=woke msg=\"woke up: LiteLLM answered twice $CONFIRM_DELAY s apart\"" ;;
    confirming:0)
      put "$h" state asleep
      put "$h" next $((now + ASLEEP_INTERVAL))
      log "host=$h event=dark-wake msg=\"woke only briefly for the probe; still asleep, next probe in $((ASLEEP_INTERVAL / 60)) min\"" ;;
  esac
}

write_metrics() {
  {
    echo "# HELP laptop_asleep 1 while the laptop is marked asleep (missed $ASLEEP_AFTER probes in a row, not yet confirmed awake)."
    echo "# TYPE laptop_asleep gauge"
    for h in $LAPTOPS; do
      case "$(get "$h" state)" in awake) a=0 ;; *) a=1 ;; esac
      echo "laptop_asleep{host=\"$h\"} $a"
    done
    echo "# HELP laptop_litellm_up 1 if the last LiteLLM probe of the laptop answered."
    echo "# TYPE laptop_litellm_up gauge"
    for h in $LAPTOPS; do echo "laptop_litellm_up{host=\"$h\"} $(get "$h" up)"; done
    echo "# HELP laptop_wakes_total Confirmed wake-ups since laptop-probe started."
    echo "# TYPE laptop_wakes_total counter"
    for h in $LAPTOPS; do echo "laptop_wakes_total{host=\"$h\"} $(get "$h" wakes)"; done
    echo "# HELP laptop_probe_last_run_timestamp_seconds Unix time laptop-probe last wrote this file."
    echo "# TYPE laptop_probe_last_run_timestamp_seconds gauge"
    echo "laptop_probe_last_run_timestamp_seconds $(date +%s)"
  } > "$OUT.tmp" && chmod 0644 "$OUT.tmp" && mv "$OUT.tmp" "$OUT"
}

# TS_TAILNET_DOMAIN, rendered from laptop-probe.conf.tmpl by gen-env.sh.
# shellcheck source=/dev/null
[ -r "$CONF" ] && . "$CONF"
if [ -z "$TS_TAILNET_DOMAIN" ] || [ "$TS_TAILNET_DOMAIN" = "{{TS_TAILNET_DOMAIN}}" ]; then
  echo "$(date -u +%FT%TZ) laptop-probe level=error msg=\"TS_TAILNET_DOMAIN is not set in $CONF (run scripts/deploy.sh extras observability)\"" >&2
  exit 1
fi

mkdir -p "$S"
for h in $LAPTOPS; do
  put "$h" state awake; put "$h" fails 0; put "$h" wakes 0; put "$h" up 0; put "$h" next 0
done
log "event=start msg=\"probing $LAPTOPS: every $AWAKE_INTERVAL s awake, asleep after $ASLEEP_AFTER misses, then every $((ASLEEP_INTERVAL / 60)) min\""

while :; do
  for h in $LAPTOPS; do
    [ "$(date +%s)" -ge "$(get "$h" next)" ] && step "$h"
  done
  write_metrics
  sleep "$TICK"
done
