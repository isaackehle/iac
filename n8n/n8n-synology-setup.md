# N8N on Synology NAS via Portainer — Setup Guide

## 1. Prerequisites on the Synology NAS

1. DSM 7.x with **Container Manager** (DSM 7.2+) or the legacy **Docker** package (DSM 7.0–7.1) installed via Package
   Center.
2. SSH access enabled (Control Panel → Terminal & SNMP → Enable SSH), or use File Station for the folder setup.
3. A static local IP or DHCP reservation for the NAS, so Telegram webhooks / n8n URLs don't break on reboot.
4. At least 2GB RAM headroom free — n8n plus a headless Chromium instance is not lightweight.

## 2. Install Portainer (if not already running)

SSH into the NAS:

```shell
ssh your-user@nas-ip
sudo -i
mkdir -p /volume1/docker/stacks/portainer/data
docker volume create portainer_data

docker run -d \
  -p 8000:8000 \
  -p 9443:9443 \
  --name portainer \
  --restart=always \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v /volume1/docker/stacks/portainer/data:/data \
  portainer/portainer-ce:latest
```

Then visit `https://nas-ip:9443` to finish Portainer's first-run setup (create admin user).

## 3. Directory structure

This follows your existing Tailscale sidecar pattern (Pattern B), so n8n lives under `stacks/` alongside your other
sidecar-fronted services, with a config dir, a files dir, and the sidecar's own state/config dirs:

```shell
/volume1/docker/stacks/n8n/
├── config/             # n8n's persistent config, credentials, workflow DB (SQLite by default)
├── files/              # shared folder for file-based nodes (exports, downloads)
├── ts-state/           # tailscale sidecar's persistent state
├── ts-config/          # tailscale sidecar's config dir (holds serve.json)
└── docker-compose.yml
```

```shell
mkdir -p /volume1/docker/stacks/n8n/{config,files,ts-state,ts-config}
chown -R 1000:1000 /volume1/docker/stacks/n8n/config   # n8n container runs as uid 1000 by default
```

You'll also need `serve.json` inside `ts-config/` before the stack comes up cleanly — a copy is provided alongside this
guide, pre-filled with n8n's internal port (5678). `${TS_CERT_DOMAIN}` is filled in automatically by the Tailscale
sidecar at runtime, so nothing to edit there.

And two env vars this compose file expects, either in your Portainer stack's environment settings or a `.env` file
alongside it:

- `TS_AUTHKEY` — a fresh Tailscale auth key for this node (from the Tailscale admin console)
- `N8N_ENCRYPTION_KEY` — generate once with `openssl rand -hex 24` and keep it stable; it encrypts n8n's stored
  credentials
- `TZ` and `TS_TAILNET_DOMAIN` if those aren't already set globally in your Portainer environment

## 4. Copy the compose file and serve.json to the NAS via SCP

From your local machine (Mac/Linux/WSL terminal), with `docker-compose.yml` and `serve.json` saved locally, copy both
into the directory you just created (`serve.json` goes inside `ts-config/`):

```shell
scp docker-compose.yml your-user@nas-ip:/volume1/docker/stacks/n8n/
scp serve.json your-user@nas-ip:/volume1/docker/stacks/n8n/ts-config/
```

- Replace `your-user` with your Synology SSH account and `nas-ip` with the NAS's local IP or Tailscale hostname.
- You'll be prompted for that account's password (or use `-i ~/.ssh/your_key` if you've set up key-based auth).
- If SSH is on a non-default port (check Control Panel → Terminal & SNMP), add `-P <port>`, e.g. `scp -P 2222
docker-compose.yml your-user@nas-ip:/volume1/docker/stacks/n8n/`.
- On Windows, either use WSL/Git Bash for the same `scp` command, or use WinSCP/FileZilla (SFTP mode) pointed at the
  same path if you'd rather drag-and-drop.

Verify they landed correctly:

```shell
ssh your-user@nas-ip "ls -la /volume1/docker/stacks/n8n/"
```

## 5. Deploy n8n as a Portainer Stack

You can either paste the file's contents directly into Portainer's web editor, or point Portainer at the file you just
SCP'd over:

- **Web editor route (simplest):** In Portainer, go to **Stacks → Add Stack → Web editor**, paste the contents of
  `docker-compose.yml`, name it `n8n`, and deploy.
- **Upload route:** **Stacks → Add Stack → Upload**, then browse to your local copy of the file. Portainer can't read
  a stack file directly off an arbitrary NAS path, so even though you SCP'd the file to
  `/volume1/docker/stacks/n8n/docker-compose.yml` for reference and backup, you'll still paste or upload from a copy
  Portainer's UI can browse to.

Key things the compose file sets up:

- n8n reachable only via its tailnet hostname (`n8n`) through the `n8n-ts` sidecar — no port bound on the NAS's
  LAN/public interface
- Persistent volume mapped to `/volume1/docker/stacks/n8n/config`
- Environment variables for timezone, basic auth (still worth keeping even behind Tailscale), and encryption key
- A **browserless/chrome** sidecar container on `n8n-net`, since headless Chromium doesn't run well _inside_ the slim
  n8n image itself — running it as a separate container n8n calls over HTTP (`http://browserless:3000`) is the
  standard pattern

## 6. First-run n8n configuration

1. From a device on your tailnet, visit `http://n8n:5678` (or whatever hostname/URL `TS_SERVE_CONFIG` exposes via
   `serve.json`) and create your owner account.
2. Go to **Credentials** and add:
   - **Telegram API** credential (bot token from @BotFather) for notifications.
   - **HTTP Request** credential for calling external APIs, or point browser-automation nodes
     at `http://browserless:3000` if using headless Chromium.
3. Build your workflows in the n8n editor — the infrastructure is ready, the logic is yours.

## 7. Remote access

This is already handled by the `n8n-ts` sidecar in the compose file — n8n has no `ports:` of its own, so it's only
reachable via its tailnet hostname (`n8n` on your tailnet, or whatever `TS_SERVE_CONFIG`/`serve.json` exposes). Nothing
is bound to the NAS's LAN interface or exposed publicly, consistent with your other Pattern B stacks. If you also want
LAN access without going through Tailscale, add a `ports:` entry to `n8n-ts` (not to `n8n` itself) rather than
reintroducing a port on the app container.

## 8. Backups

Add `/volume1/docker/stacks/n8n/` (config, files, and ts-state) to your existing Synology backup task (Hyper Backup or
your Syncthing scope) — `config` holds your workflows, credentials, and execution history, and `ts-state` holds the
sidecar's tailnet identity so it doesn't need to be re-authed after a restore.
