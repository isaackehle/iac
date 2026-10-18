# Docker boot guard (NAS)

`scripts/docker-boot-guard.sh` starts the containers that Container Manager
failed to start when the NAS booted.

## Why it exists

At boot, Container Manager starts containers itself, one at a time, about 5s
apart. It ignores compose `depends_on`, and its
`/var/packages/ContainerManager/etc/<name>.config` files have no start-order
field.

A container that joins another container's network
(`network_mode: service:` / `container:`) fails if Container Manager reaches
it before the network owner. `/var/log/messages` then shows
`Failed to cRunWithDep()`. Docker's `unless-stopped` policy never retries a
container that failed to start, so it stays down until someone starts it.

This hit both sidecar directions:

- **Sidecar joins the app:** `pihole-tailscale`, `syncthing-tailscale` and
  `nextcloud-tailscale`. `pihole-caddy` did too, until Caddy was removed.
- **App joins its sidecar:** `portainer`, `openwebui`, `actualbudget` and
  `mcp-synology`.

It happened on 2026-10-16 and again on 2026-10-18. The second time,
`docker inspect` showed only the clean pre-reboot exit (0/143, with an empty
`State.Error`), so a check that keys on exit code 128 misses it.

## What it does

1. Waits for dockerd, then waits 180s so Container Manager can finish its own
   pass.
2. Makes up to 6 passes, 30s apart. Each pass finds containers that:
   - are not running,
   - have an `unless-stopped` or `always` restart policy, and
   - were not stopped by hand (`HasBeenManuallyStopped` in
     `@docker/containers/<id>/config.v2.json`).
3. Starts standalone containers and network owners first, then the containers
   that join a running owner's network.

One-shot containers (restart `no`, such as `nextcloud-db-init` and
`openwebui-config`) are skipped. It logs to `/var/log/docker-boot-guard.log`,
because DSM's syslog drops `logger` lines. It exits 1 if anything is still
down after the last pass.

## Install

The guard runs as a DSM Task Scheduler triggered task: `bootup`, run as root.
Run this on the NAS. `/tmp` is noexec, so it uses `install`.

```bash
sudo install -o root -g root -m 755 docker-boot-guard.sh /usr/local/sbin/docker-boot-guard.sh
sudo /usr/syno/bin/synowebapi --exec api=SYNO.Core.EventScheduler method=create version=1 \
  task_name='"docker-boot-guard"' owner='{"0":"root"}' event='"bootup"' enable=true \
  depend_on_task='""' notify_enable=false notify_mail='""' notify_if_error=false \
  operation_type='"script"' operation='"/bin/sh /usr/local/sbin/docker-boot-guard.sh"'
```

A major DSM upgrade can reset `/usr/local/sbin`. After each upgrade, check
that the file is still there.

## Verify

```bash
sudo sh /usr/local/sbin/docker-boot-guard.sh --dry-run    # expect "nothing to start"
sudo /usr/syno/bin/synowebapi --exec api=SYNO.Core.EventScheduler method=get version=1 task_name='"docker-boot-guard"'
# after a reboot:
sudo cat /var/log/docker-boot-guard.log
/usr/local/bin/docker ps -a --format '{{.Names}}\t{{.Status}}'
```

Use `--match REGEX` to limit the guard to some containers, for example
throwaway test containers. Use `--now` to skip the 180s wait.
