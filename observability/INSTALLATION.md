# Observability: installation

Metrics, logs, endpoint probes and Telegram alerts for the homelab, on one tailnet node, `obs`:

| URL                                     | What                                                       |
| --------------------------------------- | ---------------------------------------------------------- |
| `https://obs.${TS_TAILNET_DOMAIN}`      | Grafana (admin login; dashboard **Homelab → overview**)    |
| `https://obs.${TS_TAILNET_DOMAIN}:9090` | Prometheus; also the `remote_write` target for fleet Alloy |
| `https://obs.${TS_TAILNET_DOMAIN}:9093` | Alertmanager (silences live here)                          |
| `https://obs.${TS_TAILNET_DOMAIN}:3100` | Loki; also the log push target for fleet Alloy             |

Prometheus, Alertmanager and Loki have no login: tailnet membership is the access control.

Design and phases: `~/Documents/Projects/Homelab/Plans/2026-10-18-homelab-observability.md`. This stack is phase 1
(NAS). Home Assistant (phase 2) and the fleet hosts, including titan (phase 3), add scrape jobs and agents later.

## What it alerts on

Alerts go to Telegram (the same bot and chat as `gateway-healthcheck.py`). Critical alerts are sent at once and repeat
every 4 h, warnings are grouped and repeat every 24 h, and every alert sends a ✅ when it resolves. `info` alerts only
show in Grafana.

| Alert                                                                                   | Severity           | Source                                                              |
| --------------------------------------------------------------------------------------- | ------------------ | ------------------------------------------------------------------- |
| `ContainerDown`                                                                         | critical           | docker-state: should run (boot guard's rule), not running, 2 min    |
| `ContainerUnhealthy`                                                                    | critical           | docker-state: healthcheck unhealthy, 5 min                          |
| `ContainerRestartLoop`                                                                  | warning            | more than 3 restarts in 15 min                                      |
| `DockerStateStale`                                                                      | critical           | the container watcher itself stopped writing                        |
| `EndpointDown`                                                                          | critical           | blackbox: tailnet services, DSM, HA, fleet LiteLLM, 3 min           |
| `CertificateExpiringSoon`                                                               | warning            | tailnet certificate under 14 days                                   |
| `NasVolumeFilling` / `NasVolumeFull`                                                    | warning / critical | `/volume1` over 85 % / 95 %                                         |
| `NasMemoryLow`                                                                          | warning            | under 10 % available for 10 min                                     |
| `Synology*`                                                                             | critical / warning | SNMP: RAID degraded, disk failing or hot, fan/power                 |
| `BootGuardRescuedContainers`                                                            | warning            | Loki: the boot guard had to start containers                        |
| `BootGuardFailed`                                                                       | critical           | Loki: the boot guard could not start everything                     |
| `NasOomKill`                                                                            | warning            | Loki: kernel OOM kill in `/var/log/messages`                        |
| `ObservabilityTargetDown`, `AlertmanagerNotificationsFailing`, `PrometheusRuleFailures` | warning            | the stack itself                                                    |
| `Watchdog`                                                                              | none               | always firing; not sent. The fleet watchdog (phase 3) checks for it |

Silence anything from Alertmanager's UI (`:9093` → Silences).

## Secrets

In `iac-secrets.env` (names only; see `iac-secrets.env.example`):

- `TS_AUTHKEY_OBSERVABILITY`: reusable, pre-authorized
- `TELEGRAM_BOT_TOKEN`, `TELEGRAM_HOME_CHANNEL`
- `GRAFANA_ADMIN_PASSWORD`
- `SNMP_COMMUNITY`, after turning on SNMP in DSM (Control Panel → Terminal & SNMP → SNMPv1/v2c). Without it the
  Synology alerts have no data; `SnmpDown` shows that in Grafana only.
- `DSM_HTTPS_PORT` comes from `~/.env` (personal, never in the repo), for the DSM probe.

The bot token is rendered into its own file (`telegram_bot_token`, used as Alertmanager's `bot_token_file`), never into
`alertmanager.yml`.

## Deploy

Deployed 2026-10-18 as **Portainer stack 73** (git, `main`, `observability/docker-compose.yml`). Stack changes go through
the Portainer API only.

`scripts/deploy.sh api` only creates stacks: it finds the stack by name client-side (Portainer ignores
`/api/stacks?name=`) and refuses if it already exists. It never deletes anything. Before 2026-10-18 it DELETEd the first
stack in the list (syncthing, stack 33), so do not run an older copy of the script.

Config files (everything except the compose file) are pushed with deploy.sh, then the stack is redeployed:

```shell
scripts/gen-env.sh observability                 # .env + rendered templates (all gitignored)
scripts/deploy.sh dirs observability nas         # first time only: directories under /volume1/docker/stacks/observability
scripts/deploy.sh extras observability nas       # config files: serve.json, Prometheus, Alertmanager, Loki, ...
```

Redeploy (after a compose change is merged):

```shell
scripts/deploy.sh redeploy observability         # asks first; --yes to skip the prompt
```

That is `GET /api/stacks`, pick the entry whose `Name` is `observability`, then
`PUT /api/stacks/<id>/git/redeploy?endpointId=3` with body `{"env": <that stack's Env, unchanged>, "prune": true,
"pullImage": false, "repositoryReferenceName": "refs/heads/main"}`. It uses `PORTAINER_API_KEY_OBS` (in `~/.env`) over
`PORTAINER_API_KEY`. Variables are passed back unchanged; change them in Portainer.

The first start of Grafana runs about 800 database migrations and takes around 10 minutes on the NAS.

The non-root services run as `OBS_PUID:OBS_PGID` (isaac, 1026:100), so the files `deploy.sh` pushes as isaac are
readable without any chown. Since the 2026-10-17 docker share ACL change a non-root uid can only reach files it owns.

## Changing config

Edit the file in the repo, then `scripts/gen-env.sh observability && scripts/deploy.sh extras observability nas`, then:

- Prometheus rules or scrape config: `curl -X POST https://obs.${TS_TAILNET_DOMAIN}:9090/-/reload`
- Alertmanager: `curl -X POST https://obs.${TS_TAILNET_DOMAIN}:9093/-/reload`
- Loki rules: picked up within a minute; Grafana dashboards: within 60 s
- Alloy: restart `obs-alloy` (a borrower; restarting a borrower is fine, never restart `obs-tailscale` alone)
- Compose changes: Portainer API git redeploy (above), which recreates the whole stack

Add a tailnet service to the probes in `prometheus.yml.tmpl` (`blackbox-tailnet`).

## Verify

From any tailnet machine:

```shell
curl -s -o /dev/null -w '%{http_code}\n' https://obs.${TS_TAILNET_DOMAIN}/api/health        # 200
curl -s https://obs.${TS_TAILNET_DOMAIN}:9090/-/ready                                      # Ready
curl -s https://obs.${TS_TAILNET_DOMAIN}:9093/-/ready                                      # OK
curl -s https://obs.${TS_TAILNET_DOMAIN}:3100/ready                                        # ready
curl -s 'https://obs.${TS_TAILNET_DOMAIN}:9090/api/v1/query?query=up' | jq '.data.result[] | [.labels.job, .value[1]]'
```

Then a test alert end to end that reproduces the real boot failure: a container that joins a network whose owner is
not running. It is created but never started, and nobody stopped it by hand, so `ContainerDown` should fire in Telegram
within about 3 minutes:

```shell
ssh nas 'D=/usr/local/bin/docker; $D create --name obs-test-owner alpine:3.20 sleep 1d &&
  $D create --name obs-test-joiner --restart unless-stopped --network container:obs-test-owner alpine:3.20 sleep 1d'
# ...wait for the alert, then resolve it and clean up:
ssh nas 'D=/usr/local/bin/docker; $D start obs-test-owner obs-test-joiner; sleep 240; $D rm -f obs-test-joiner obs-test-owner'
```

Wireshark is not part of this stack: packet capture is on demand, not monitoring.
