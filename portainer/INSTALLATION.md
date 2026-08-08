# Portainer Server Installation

Portainer is the only stack deployed via Synology Container Manager rather than
Portainer's own UI — you're bootstrapping Portainer itself. Everything else in
this repo gets deployed *from* Portainer once this is running.

## Architecture

Three containers sharing one network namespace (Pattern B — see the root
`README.md`):

| Container         | Role                                                          |
| ----------------- | ------------------------------------------------------------- |
| `portainer`       | Portainer CE. Listens on `:9000` (HTTP) and `:9443` (HTTPS).  |
| `portainer-tailscale`    | Tailscale sidecar. Owns the namespace; joins the tailnet.     |
| `portainer-caddy` | Reverse proxy. Listens on `:8444`, forwards to `:9000`.       |

Request path for `https://portainer.<tailnet>.ts.net`:

```text
client → tailscaled (:443, TerminateTLS) → Caddy (:8444) → Portainer (:9000)
```

Tailscale terminates TLS with its own auto-issued Let's Encrypt cert, then hands
Caddy raw decrypted TCP. **Caddy does the HTTP-level proxying, not tailscaled** —
tailscaled's built-in `Web`/`Proxy` serve mode is documented as 5-10x slower
under load ([tailscale/tailscale#18307](https://github.com/tailscale/tailscale/issues/18307))
and has caused real outages here. Pi-hole uses the identical pattern.

Because all three share `portainer-tailscale`'s namespace, they reach each other over
`127.0.0.1`. Ports `9000`, `19443` (→`9443`), and `8000` are also published to
the NAS host for LAN access; `8444` deliberately is not.

## Prerequisites

- Synology NAS with Container Manager installed
- A Tailscale auth key (`tskey-...`) from <https://login.tailscale.com/admin/settings/keys>
- SSH or File Station access to the NAS

## 1. Directory setup

Secrets live outside the stack directory, since `/volume1/docker/stacks/` is
world-writable on DSM.

```shell
STACK=/volume1/docker/stacks/portainer

mkdir -p $STACK/{data,ts-config,ts-state,caddy-config}

# Secrets: 700, root-owned, separate tree
sudo mkdir -p /volume1/docker/portainer-secrets/{certs,chisel}
sudo chmod 700 /volume1/docker/portainer-secrets
sudo chown root:root /volume1/docker/portainer-secrets

# cert.pem + key.pem → certs/ ; private-key.pem → chisel/
sudo chmod 600 /volume1/docker/portainer-secrets/{certs,chisel}/*
sudo chown root:root /volume1/docker/portainer-secrets/{certs,chisel}/*
```

Resulting layout:

```text
/volume1/docker/portainer-secrets/     ← 700 root:root
├── certs/{cert.pem,key.pem}           ← 600
└── chisel/private-key.pem             ← 600

/volume1/docker/stacks/portainer/
├── .env                               ← 600, TS_AUTHKEY lives here
├── docker-compose.yml
├── caddy-config/Caddyfile
├── ts-config/serve.json               ← rendered from serve.json.tmpl
├── ts-state/                          ← tailscaled state (see DEBUG.md)
└── data/                              ← portainer.db and Portainer's data
```

The chisel private key authenticates Portainer's reverse tunnel to its agents —
if it leaks, treat it as a full compromise and rotate it.

## 2. Environment file

Create `/volume1/docker/stacks/portainer/.env`:

```shell
TS_HOSTNAME_PORTAINER=portainer
TS_AUTHKEY=tskey-your-auth-key-here
TS_CERT_DOMAIN=portainer.your-tailnet.ts.net
```

```shell
sudo chmod 600 /volume1/docker/stacks/portainer/.env
```

Note this file serves two separate purposes: Compose reads it for `${VAR}`
substitution in the YAML (which requires it to sit in the directory you run
`docker compose` from), and the `env_file:` directive injects it into the
`portainer` container at runtime. A missing `.env` shows up as
`WARN The "TS_AUTHKEY" variable is not set` — Compose substitution failing, not
the `env_file` directive.

## 3. Push the stack files

From your Mac:

```shell
cd ~/code/isaackehle/iac
scripts/gen-env.sh portainer          # renders serve.json from serve.json.tmpl
scripts/deploy.sh portainer nas   # pushes compose, .env, serve.json, Caddyfile
```

Or manually — note `-O`, which forces the legacy SCP protocol. Without it,
modern OpenSSH uses SFTP, which DSM's sshd doesn't reliably serve, and you get a
misleading `No such file or directory` on a directory that plainly exists:

```shell
scp -O portainer/docker-compose.yml isaac@nas:/volume1/docker/stacks/portainer/
scp -O portainer/Caddyfile          isaac@nas:/volume1/docker/stacks/portainer/caddy-config/
scp -O portainer/serve.json         isaac@nas:/volume1/docker/stacks/portainer/ts-config/
```

## 4. Deploy

CLI (preferred — Container Manager keeps its own internal copy of imported YAML,
which then drifts from what's on disk):

```shell
cd /volume1/docker/stacks/portainer
docker compose up -d
```

Via Container Manager UI: **Project** → **Create** → **Import from YAML/JSON**,
paste `docker-compose.yml`, then **Use existing .env file** →
`/volume1/docker/stacks/portainer/.env` → **Apply**.

> `tailscaled` reads `serve.json` **once at container start**. Always write the
> config first, then bring the stack up — a config written after startup is
> silently ignored, and the log says `no serve config at "/config/serve.json", skipping`.

## 5. Verify

```shell
docker ps -a --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'
docker exec portainer-tailscale tailscale status
docker exec portainer-tailscale tailscale serve status
```

Expect all three containers `Up` with **matching uptimes**, and serve status
showing `tcp://portainer.<tailnet>.ts.net:443 → tcp://127.0.0.1:8444`.

Then, from a machine on the tailnet (not the NAS itself — see DEBUG.md):

```shell
curl -sS -o /dev/null -w '%{http_code}\n' https://portainer.<tailnet>.ts.net/
```

## 6. First login

Open `https://portainer.<tailnet>.ts.net` and create the admin account.

**Portainer self-locks 5 minutes after start if no admin account exists.** If you
see `the Portainer instance timed out for security purposes`, restart it and
grab the fresh setup token:

```shell
docker restart portainer
docker logs --tail 20 portainer | grep setup_token
```

## Updates

```shell
cd /volume1/docker/stacks/portainer
docker compose pull
docker compose down && docker compose up -d
```

> **Never restart the sidecar alone.** `network_mode: service:portainer-tailscale`
> binds the namespace at *container creation*. `docker restart portainer-tailscale`
> leaves `portainer` and `portainer-caddy` pointed at a namespace that no longer
> exists, which presents as `connection refused` to `127.0.0.1:9000` in the
> sidecar log. Mismatched uptimes in `docker ps` are the tell. Always
> `down && up -d` the whole stack.

## Next steps

- Deploy remaining stacks from the Portainer UI
- Back up `/volume1/docker/stacks/portainer/data/` (contains `portainer.db`)
