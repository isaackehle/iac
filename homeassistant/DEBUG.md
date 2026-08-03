# Debug Commands

Quick reference for troubleshooting the Home Assistant stack.

> This stack uses **Pattern A** (host-level `tailscale serve`), not a Tailscale
> sidecar. Home Assistant runs `network_mode: host` for device discovery, which
> is incompatible with the sidecar pattern — a sidecar would land in the host
> netns alongside the NAS's own `tailscaled`. There is no `ts-homeassistant`
> container, no `serve.json`, and no `ts-state`/`ts-config` here; the tailnet
> mapping lives on the NAS host. See README.md "Pattern A".

## Container Access

```shell
docker exec -it homeassistant bash
```

## Container Logs

```shell
docker logs homeassistant
docker logs -f homeassistant
```

## Tailscale Serve Configuration

Run these **on the NAS host**, not inside a container — the mapping belongs to
the host's own tailscaled:

```shell
tailscale serve status
```

Expect a mapping for port 8123 → `http://127.0.0.1:8123`. If it's missing (a
`tailscale serve reset` wipes every stack's mapping, not just one), reapply:

```shell
scripts/serve-all.sh <ssh-host>
```

The mapping is defined in `scripts/lib.sh` under `STACK_SERVE_PORTS`.

## Is Home Assistant actually listening?

Because of host networking, HA binds the NAS host's port 8123 directly:

```shell
curl -sS -o /dev/null -w '%{http_code}\n' http://127.0.0.1:8123
```

A `200` here with a failing tailnet URL means the problem is the serve mapping,
not the container.

## Access

- **Via Tailscale:** `https://homeassistant.${TS_TAILNET_DOMAIN}`
- **LAN:** `http://<nas>:8123`

## Restart

```shell
cd /volume1/docker/stacks/homeassistant
docker compose down && docker compose up -d
```

## Config Files

| Purpose            | Host Path                                        |
| ------------------ | ------------------------------------------------ |
| HA config          | `/volume1/docker/stacks/homeassistant/config`    |
| Serve mapping      | `scripts/lib.sh` → `STACK_SERVE_PORTS` (host-level, not a file on the NAS) |
