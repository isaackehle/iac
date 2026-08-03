# Portainer Debug Reference

Troubleshooting for the Portainer + Tailscale + Caddy stack. For the full
narrative of the 2026-08-03 outage that produced most of these notes, see
`OUTAGE-2026-08-03.md`.

## Read this first

Four traps that cost hours during the August 2026 outage. Check them before
anything else — each one produces symptoms that look like a different problem.

**1. Never `docker restart` the sidecar alone.** `network_mode: service:ts-portainer`
binds the namespace at container *creation*. Restarting `ts-portainer` by itself
leaves the others pointed at a dead namespace. Symptom: `netstack: could not
connect to local backend server at 127.0.0.1:9000: connect: connection refused`,
and mismatched uptimes in `docker ps`. Fix: `docker compose down && docker compose up -d`.

**2. Don't test `.ts.net` URLs from the NAS's own shell.** Voyager resolves
`.ts.net` via public DNS (`8.8.8.8` → `NXDOMAIN`), not Tailscale's resolver at
`100.100.100.100`, so `curl` there returns unrelated junk — a Fastmail landing
page, in our case — that looks like a real response. Always test from a laptop
or another tailnet node. Verify with `nslookup portainer.<tailnet>.ts.net`.

**3. `serve.json` is read once at container start.** Edit it, then
`docker compose down && up -d`. Editing a running container's config does
nothing, and `boot: serve proxy: no serve config at "/config/serve.json",
skipping` in the log means it started before the file existed.

**4. Check what's actually deployed, not what's in git.** The live compose file,
Container Manager's internal copy of an imported project, and the repo can all
disagree. Ground truth:

```shell
docker inspect ts-portainer --format '{{index .Config.Labels "com.docker.compose.project.config_files"}}'
docker inspect ts-portainer --format '{{range .Mounts}}{{.Source}} -> {{.Destination}}{{"\n"}}{{end}}'
docker exec ts-portainer cat /config/serve.json
```

## Health check

```shell
docker ps -a --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'
docker logs --tail 30 ts-portainer
docker logs --tail 30 portainer
docker logs --tail 30 caddy-portainer
docker exec ts-portainer tailscale status
docker exec ts-portainer tailscale serve status
```

Want: three containers `Up` with matching uptimes, and

```text
|-- tcp://portainer.<tailnet>.ts.net:443 (TLS terminated, tailnet only)
|--> tcp://127.0.0.1:8444
```

## Diagnosing by symptom

### Hangs after connecting — no response, no error

TCP connects, request goes out, nothing comes back, eventually times out. This
is **not** connection refused (that fails instantly) and not DNS.

Test whether it's payload-size dependent — small responses succeeding while
large ones hang points at a broken MTU/path, not the application:

```shell
# tiny JSON, no auth required
curl -v --max-time 10 http://<tailscale-ip>:9000/api/status   # 72 bytes
curl -v --max-time 10 http://<tailscale-ip>:9000/             # full HTML
```

If small works and large hangs, compare against a known-good sidecar on the same
host, same peer, same relay:

```shell
docker exec ts-portainer tailscale ping --size 1300 <your-laptop>
docker exec ts-pihole    tailscale ping --size 1300 <your-laptop>
```

One failing while the other succeeds proves the fault is local to that node's
`tailscaled` state, not the network. Fix — wipe state and re-register:

```shell
cd /volume1/docker/stacks/portainer
docker compose down
rm -rf ts-state/*
docker compose up -d
```

The node gets a **new tailnet IP**; the hostname is unchanged. Cert re-issue
takes ~2 minutes (`docker logs ts-portainer | grep -i cert` → `got cert`);
requests before that fail with a certificate name mismatch, which is expected
and self-resolving.

> Requires a **reusable** auth key. With `TS_AUTH_ONCE=true` and a single-use
> key already consumed, the node cannot rejoin — check the key in the Tailscale
> console before wiping, or you'll be left with a logged-out node.

### Connection refused

The port isn't listening or isn't published. Check `PORTS` in `docker ps`, and
confirm the container isn't in the stale-namespace state from trap #1.

### Port already bound / "network is busy"

Usually a stale host-level `tailscale serve` mapping or an orphaned network from
a renamed Compose project (project name prefixes network names —
`portainer_portainer_net`, not `portainer_net`).

```shell
tailscale serve status          # on the host, not in the container
tailscale serve reset           # wipes ALL host mappings — see caveat below
docker network ls | grep portainer
docker network rm <orphaned-network>
```

> `tailscale serve reset` clears every host-level mapping, including other
> stacks (affine, frigate, postgresql). Reapply with `scripts/serve-all.sh <ssh-host>`.

### "no administrator account configured"

Portainer disables itself 5 minutes after start if no admin exists.

```shell
docker restart portainer
docker logs --tail 20 portainer | grep setup_token
```

Then create the admin account within 5 minutes. Note that BoltDB pre-allocates
~256KB regardless of content, so **file size tells you nothing** about whether a
`portainer.db` contains a real admin account — don't pick a database to restore
based on size.

### TLS handshake never completes

If it hangs at Client Hello with no ServerHello, that's the payload-size problem
above, not a certificate problem. A genuine cert issue looks like
`no alternative certificate subject name matches target host name` — check
`docker logs ts-portainer | grep -i cert` for the ACME exchange.

### `WARN The "TS_AUTHKEY" variable is not set`

Compose `${VAR}` substitution, not the `env_file:` directive — they're separate
mechanisms. Compose reads `.env` from the directory you invoke it in, so
`cd /volume1/docker/stacks/portainer` before `docker compose up -d`.

### scp fails with "No such file or directory" on a directory that exists

Modern OpenSSH defaults to the SFTP protocol; DSM's sshd doesn't reliably serve
it. Force legacy SCP with `-O`, or bypass both:

```shell
scp -O local-file isaac@voyager:/volume1/docker/stacks/portainer/
ssh isaac@voyager "cat > /path/on/nas" < local-file
```

## Reference

```shell
# shell into the sidecar
docker exec -it ts-portainer sh

# what tailscaled thinks it's serving
docker exec ts-portainer cat /config/serve.json
docker exec ts-portainer tailscale serve status
docker exec ts-portainer tailscale ip -4

# is the backend actually up, from inside the shared namespace?
docker exec ts-portainer wget -qO- http://127.0.0.1:9000/api/status
docker exec ts-portainer wget -qO- http://127.0.0.1:8444/api/status   # via Caddy
```

There is no `tailscale0` interface in these containers — they run with
`--tun=userspace-networking`, so `ip link show tailscale0` fails by design and
tells you nothing.

| Purpose         | Host path                                                 |
| --------------- | --------------------------------------------------------- |
| Compose file    | `/volume1/docker/stacks/portainer/docker-compose.yml`     |
| Env file        | `/volume1/docker/stacks/portainer/.env`                   |
| Serve config    | `/volume1/docker/stacks/portainer/ts-config/serve.json`   |
| Caddy config    | `/volume1/docker/stacks/portainer/caddy-config/Caddyfile` |
| Tailscale state | `/volume1/docker/stacks/portainer/ts-state/`              |
| Portainer data  | `/volume1/docker/stacks/portainer/data/`                  |
| Secrets         | `/volume1/docker/portainer-secrets/` (700, root:root)     |

Access: `https://portainer.<tailnet>.ts.net` (tailnet), `http://<nas>:9000` (LAN).
