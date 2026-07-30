# Quick Start Guide

For each stack below: copy `.env.example` → `.env`, fill in secrets, then run `docker compose up -d`.

---

## Home Assistant (sidecar pattern)

```bash
cd homeassistant
cp .env.example .env  # edit to add TS_AUTHKEY_HOMEASSISTANT
docker compose up -d
# Deploy your actual HA app container via Portainer with: network_mode: service:ts-homeassistant
```

**Access:** `https://homeassistant.<tailnet>.ts.net`

---

## Nextcloud (sidecar pattern)

```bash
cd nextcloud
cp .env.example .env  # edit to add secrets
docker compose up -d
```

**Access:** `https://nextcloud.<taillet>.ts.net`

---

## Pihole (sidecar + host ports)

```bash
cd pihole
cp .env.example .env  # edit PIHOLE_PASSWORD
./apply-serve.sh      # register Tailscale serve mapping
docker compose up -d
```

**Access:** `https://nas.<tailnet>.ts.net:8080` (web), `https://nas.<tailnet>.ts.net:8443` (admin)

---

## Plex (sidecar pattern)

```bash
cd plex
cp .env.example .env  # edit PLEX_CLAIM, TS_AUTHKEY_PLEX
docker compose up -d
```

**Access:** `https://plex.<tailnet>.ts.net:32400`

---

## PostgreSQL (host serve)

```bash
cd postgresql
cp .env.example .env  # edit if needed
./apply-serve.sh      # register Tailscale serve mapping
docker compose up -d
```

**Access:** `https://nas.<tailnet>.ts.net:2660` (pgAdmin)

---

## Frigate (host serve, no sidecar)

```bash
cd frigate
cp .env.example .env  # edit MQTT credentials
./apply-serve.sh      # register Tailscale serve mapping
docker compose up -d
```

**Access:** `https://nas.<tailnet>.ts.net:8971` (web), RTSP at `rtsp://<TS_IP>:8554`

---

## Affine (host serve, no sidecar)

```bash
cd affine
cp .env.example .env  # edit secrets
./apply-serve.sh      # register Tailscale serve mapping
docker compose up -d
```

**Access:** `https://nas.<tailnet>.ts.net:3010`

---

## Syncthing (sidecar pattern)

```bash
cd syncthing
cp .env.example .env  # edit SYNC_PUID, SYNC_PGID, TS_AUTHKEY_SYNCTHING
./apply-serve.sh      # register Tailscale serve mapping
docker compose up -d
```

**Access:** `https://syncthing.<tailnet>.ts.net`

---

## OpenWebUI (sidecar pattern)

```bash
cd openwebui
cp .env.example .env  # edit OPENWEBUI_API_KEY, OLLAMA_ENGINES
docker compose up -d
# Optional: ./configure-ollama.sh to set up Ollama engines
```

**Access:** `https://openwebui.<tailnet>.ts.net` (via sidecar)

---

## Mosquitto (host ports only, no Tailscale)

```bash
cd mosquitto
cp .env.example .env  # edit if needed
docker compose up -d
```

**Access:** LAN-only via `mosquitto.<tailnet>.ts.net:1883` once tailscaled is running on the host.

---

## Portainer (sidecar + host ports)

```bash
cd portainer
cp .env.example .env  # edit TS_AUTHKEY_PORTAINER, TZ
docker compose up -d
# Note: this exposes some ports directly to LAN as well (9000, 8000, 19443)
```

**Access:** `https://portainer.<tailnet>.ts.net`, plus direct LAN on port 9000.

---

## Applying all host serve mappings at once

From the repo root:

```bash
./apply-serve.sh              # apply all stacks
./apply-serve.sh --reset      # reset everything, then re-apply
```
