# Observability: debugging

Containers: `obs-tailscale` (owns the network namespace), `obs-prometheus`, `obs-alertmanager`, `obs-loki`,
`obs-grafana`, `obs-alloy`, `obs-blackbox`, `obs-snmp` (all borrow it), `obs-cadvisor` (stack bridge, 172.20.35.10),
`obs-node-exporter` (host network, :9100), `obs-docker-state` (no network). Files live under
`/volume1/docker/stacks/observability/` (`config/`, `data/`, `textfile/`, `ts-state/`, `ts-config/`).

```shell
ssh nas
D=/usr/local/bin/docker
$D ps -a --filter name=obs- --format 'table {{.Names}}\t{{.Status}}'
$D logs --tail 50 obs-prometheus
$D exec obs-tailscale tailscale status
$D exec obs-tailscale tailscale serve status
```

**Never `docker restart obs-tailscale` alone.** The borrowers stay pointed at the namespace that no longer exists.
Recreate the whole stack (Portainer redeploy, or `docker compose down && up -d`). Restarting a borrower alone is fine.

## Probes fail with "no such host" for `*.ts.net`

The sidecar runs with `TS_ACCEPT_DNS=true` so the namespace gets MagicDNS (100.100.100.100). Without it nothing in the
namespace resolves tailnet names (checked 2026-10-18 from `openwebui-tailscale`).

```shell
$D exec obs-tailscale cat /etc/resolv.conf
$D exec obs-tailscale nslookup discovery.<tailnet>.ts.net 100.100.100.100
$D exec obs-tailscale nslookup api.telegram.org          # external names must still resolve (Telegram)
```

If MagicDNS works but external names break, or the reverse, fall back to tailscaled's outbound proxy for the tailnet
probes only: set `TS_OUTBOUND_HTTP_PROXY_LISTEN=127.0.0.1:1055` on the sidecar, `TS_ACCEPT_DNS=false`, and
`proxy_url: http://127.0.0.1:1055` in the `https_2xx` and `http_2xx` blackbox modules.

## `ContainerDown` never fires, or `DockerStateStale` fires

```shell
cat /volume1/docker/stacks/observability/textfile/docker_state.prom | head
$D logs --tail 20 obs-docker-state
curl -s http://127.0.0.1:9100/metrics | grep -E '^docker_|node_textfile_scrape_error'
```

Every container should appear, including stopped ones. One-shot containers (`restart: no`) show `should_run 0`.
The script uses `{{.ID}}` in `docker inspect`. With `{{.Id}}` the CLI falls back to the raw JSON map, and containers
without a healthcheck drop out of the output.

## Prometheus can't scrape `node` (172.20.35.1:9100)

node-exporter is in the host network; Prometheus reaches it through the stack bridge gateway. If DSM's firewall drops
that, `ObservabilityTargetDown{job="node"}` fires. Allow 172.20.35.0/24 to port 9100 in DSM's firewall, or change the
target to `{{NAS_LAN_IP}}:9100` in `prometheus.yml.tmpl`.

## Rules fail to load after editing over SMB

macOS writes `._name.yml` AppleDouble files over SMB. Prometheus lists its rule files by name, so it ignores them.
Loki loads every file in `config/loki/rules/fake/`, so delete them there:

```shell
find /volume1/docker/stacks/observability/config -name '._*' -delete
```

## Telegram alerts don't arrive

```shell
$D logs --tail 50 obs-alertmanager | grep -i -E 'telegram|notify|error'
# Send a test alert straight to Alertmanager (from inside the namespace):
$D exec obs-alertmanager amtool alert add alertname=TestAlert severity=critical \
  --annotation=summary="test from amtool" --alertmanager.url=http://127.0.0.1:9093
```

`AlertmanagerNotificationsFailing` shows send errors in Grafana even when Telegram itself is the broken part.

## Validate config before pushing

```shell
$D run --rm --network none --entrypoint promtool -v /volume1/docker/stacks/observability/config/prometheus:/etc/prometheus:ro \
  prom/prometheus:v3.15.0 check config /etc/prometheus/prometheus.yml
$D run --rm --network none --entrypoint amtool -v /volume1/docker/stacks/observability/config/alertmanager:/etc/alertmanager:ro \
  prom/alertmanager:v0.34.1 check-config /etc/alertmanager/alertmanager.yml
$D run --rm --network none -v /volume1/docker/stacks/observability/config/loki:/etc/loki:ro \
  grafana/loki:3.7.8 -config.file=/etc/loki/loki.yml -verify-config
$D run --rm --network none -v /volume1/docker/stacks/observability/config/alloy:/etc/alloy:ro \
  grafana/alloy:v1.20.1 validate /etc/alloy/config.alloy
```
