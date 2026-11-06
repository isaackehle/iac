# Debug: esphome

## Is the container up?

```shell
ssh esphome 'docker ps -a | grep esphome'
```

Expected: both `esphome` and `esphome-tailscale` running for at least
a minute. If `esphome-tailscale` keeps restarting, the auth key is
likely exhausted or revoked — rotate at
<https://login.tailscale.com/admin/settings/keys>.

## Is mDNS visible?

```shell
ssh esphome 'dns-sd -B _esphome._tcp local.'
```

This must list every ESPHome device on the LAN. If it's empty, the
container is on a bridge network, not host — confirm:

```shell
ssh esphome 'docker inspect esphome \
  | jq -r ".[0].HostConfig.NetworkMode"'
```

Expected: `host`. If `bridge`, the compose file regressed; fix and
re-run.

## Tailscale alive but dashboard unreachable

```shell
ssh esphome 'tailscale status'
ssh esphome 'tailscale netcheck'
```

If `tailscale netcheck` shows UDP blocked, the host firewall (DSM
rule set) is the problem, not this stack.

If Tailscale is fine but `curl https://esphome.${TS_TAILNET_DOMAIN}/`
502s:

```shell
ssh esphome 'curl -sI http://127.0.0.1:6052/'
```

If empty / connection refused, the primary isn't healthy yet:

```shell
ssh esphome 'docker logs esphome --tail 30'
```

## Compile fails with cryptic errors

```shell
ssh esphome 'ls -la config/*.yaml'
ssh esphome 'docker exec esphome esphome config config/<device>.yaml'
```

`esphome config` is a precompile validator; faster and clearer than
running the full build.

## DNS collision with peers

If `hostname:` is set on the sidecar (instead of `TS_HOSTNAME=
esphome`), every other Tailscale sidecar on the same NAS breaks
MagicDNS resolution. Quick check:

```shell
ssh esphome 'docker inspect esphome-tailscale \
  | jq -r ".[0].Config.Hostname"'
```

If the value is `esphome`, that's the regression — unset `hostname:`
in the compose file and redeploy.

## See also

- `_template/DEBUG.md` for the generic sidecar template.
