# Mosquitto — Portainer Stack Deployment

> **Note:** Mosquitto is a non-HTTP service (MQTT broker on port 1883). It is **not** served via Tailscale's HTTP/HTTPS `tailscale serve` — it is reachable
> directly via the NAS's Tailscale IP or hostname on port 1883 (MQTT) and 9001 (WebSocket).

## Directory Setup (on Synology NAS)

```shell
STACK_PATH="/volume1/docker/stacks/mosquitto"

mkdir -p $STACK_PATH/{config/mosquitto,config/certs,data}
```

### Optional: TLS Certificates

If you want to enable TLS (recommended for production):

```shell
# Place your certificates in the certs directory
mkdir -p $STACK_PATH/config/certs

# cert.pem = server certificate
# key.pem = server private key
# ca.pem = CA certificate (optional, for client verification)
```

### Configuration File

Create `/volume1/docker/stacks/mosquitto/config/mosquitto/mosquitto.conf`:

```conf
# Listener for plain MQTT (port 1883)
listener 1883
protocol mqtt

# Listener for WebSocket (port 9001)
listener 9001
protocol websockets

# Authentication (change these!)
password_file /mosquitto/config/mosquitto.conf

# TLS (optional but recommended)
# certificate_file /mosquitto/certs/cert.pem
# cafile /mosquitto/certs/ca.pem
# key_file /mosquitto/certs/key.pem

# Persistent data
persistence true
persistence_location /mosquitto/data

# Logging
log_dest file /mosquitto/logs/mosquitto.log
log_type published
log_type subscription
```

## Deploy via Portainer

1. Go to **Stacks → Add stack**
2. Choose **Repository** as the build method
3. Set:
   - **Repository URL:** `https://github.com/isaackehle/iac.git`
   - **Repository reference:** `refs/heads/main`
   - **Compose path:** `mosquitto/docker-compose.yml`
4. Under **Environment variables**, fill in:
   - `TZ` — timezone (e.g., `America/New_York`)
   - `MQTT_USER` — MQTT username (e.g., `zigbee`)
   - `MQTT_PASSWORD` — strong password (generate with `openssl rand -base64 32`)
5. Click **Deploy the stack**

---

## Deploy via SSH (Recommended for GitOps)

> **Recommended:** `scripts/deploy.sh all mosquitto <ssh-host>` from the repo root handles everything in one step.

### Prerequisites

- SSH access to the NAS (e.g., `nas` alias in `~/.ssh/config`)
- The `scripts/deploy.sh` and `scripts/gen-env.sh` tools available on your laptop
- The central secrets file `iac-secrets.env` with `MQTT_USER` and `MQTT_PASSWORD` set

### One-Line Deployment

```shell
cd ~/code/isaackehle/iac
scripts/deploy.sh all mosquitto nas
```

This single command does:

1. Generates `mosquitto/env.txt` from `iac-secrets.env`
2. Creates `/volume1/docker/stacks/mosquitto/{config/mosquitto,config/certs,data}` on the NAS
3. Copies `docker-compose.yml`, `env.txt`, and any extra files via SCP
4. Runs `docker compose up -d` on the NAS

### Step-by-Step (if you need more control)

```shell
# 1. Generate env.txt locally
scripts/gen-env.sh mosquitto

# 2. Create directories on the NAS
ssh nas "mkdir -p /volume1/docker/stacks/mosquitto/{config/mosquitto,config/certs,data}"

# 3. Push files to the NAS
scp -O mosquitto/docker-compose.yml nas:/volume1/docker/stacks/mosquitto/
scp -O mosquitto/env.txt nas:/volume1/docker/stacks/mosquitto/

# 4. Start the stack
ssh nas "cd /volume1/docker/stacks/mosquitto && docker compose up -d"
```

### Verify Deployment

```shell
# Check containers are running
ssh nas "docker ps | grep mosquitto"

# Check logs
ssh nas "docker logs mosquitto"

# Test MQTT connectivity from your laptop
brew install mosquitto
mosquitto_sub -h mosquitto.tail303fda.ts.net -p 1883 -u zigbee -P 'your-password' -t 'test/#'
```

---

## What the Stack Contains

| Container   | Image                   | Role                                                            |
| ----------- | ----------------------- | --------------------------------------------------------------- |
| `mosquitto` | `eclipse-mosquitto:2.0` | MQTT broker — listens on port 1883 (plain) and 9001 (WebSocket) |

## Access

| URL/Endpoint                      | Description                            |
| --------------------------------- | -------------------------------------- |
| `mosquitto.<tailnet>.ts.net:1883` | MQTT over Tailscale (plain TCP)        |
| `mosquitto.<tailnet>.ts.net:9001` | MQTT over WebSocket (for web clients)  |
| `<NAS-Tailscale-IP>:1883`         | Direct Tailscale IP access             |
| `<NAS-LAN-IP>:1883`               | LAN access (if NAS is on same network) |

**No HTTPS/TLS via Tailscale serve** — Mosquitto is a raw TCP service, not HTTP. If you need TLS, configure it in `mosquitto.conf` and use
`ssl://mosquitto.<tailnet>.ts.net:1883` from clients.

## First-Run Mosquitto Setup

1. Verify the container is running:

   ```shell
   docker ps | grep mosquitto
   docker logs mosquitto
   ```

2. Test connectivity from a client:

   ```shell
   # Install mosquitto-clients on your laptop:
   brew install mosquitto

   # Subscribe to a topic:
   mosquitto_sub -h mosquitto.tail303fda.ts.net -p 1883 -u zigbee -P 'your-password' -t 'test/#'

   # Publish a test message:
   mosquitto_pub -h mosquitto.tail303fda.ts.net -p 1883 -u zigbee -P 'your-password' -t 'test/message' -m 'Hello from Portainer!'
   ```

## Persistent Data

| Host Path                                     | Container Path                     | Contents                                   |
| --------------------------------------------- | ---------------------------------- | ------------------------------------------ |
| `$STACK_PATH/data`                            | `/mosquitto/data`                  | Retained messages, sessions, subscriptions |
| `$STACK_PATH/config/mosquitto/mosquitto.conf` | `/mosquitto/config/mosquitto.conf` | Broker configuration                       |
| `$STACK_PATH/config/certs`                    | `/mosquitto/certs:ro`              | TLS certificates (optional)                |

## Backups

Include `$STACK_PATH/data` in your Synology backup task (Hyper Backup, Syncthing, etc.). This directory contains:

- Retained messages
- Client sessions
- Subscription state
- Last will and testament data

## Troubleshooting

### Client Can't Connect

1. Check container logs:

   ```shell
   docker logs mosquitto
   ```

2. Verify port 1883 is published:

   ```shell
   docker ps | grep mosquitto
   ```

3. Test from NAS shell:

   ```shell
   docker exec mosquitto nc -zv mosquitto 1883
   ```

4. Check Tailscale connectivity:

   ```shell
   docker exec mosquitto tailscale ping <your-laptop>
   ```

### Authentication Failed

1. Verify `MQTT_PASSWORD` is set correctly in Portainer's environment variables
2. Check the password file path in `mosquitto.conf` matches the mounted config
3. Restart the container after changing passwords:

   ```shell
   docker restart mosquitto
   ```

### TLS Not Working

1. Ensure certificates are in `$STACK_PATH/config/certs/` with correct names (`cert.pem`, `key.pem`, `ca.pem`)
2. Uncomment the TLS lines in `mosquitto.conf`
3. Verify certificate permissions:

   ```shell
   chmod 600 /volume1/docker/stacks/mosquitto/config/certs/key.pem
   chmod 644 /volume1/docker/stacks/mosquitto/config/certs/cert.pem
   ```

4. Restart the container

## References

- [Eclipse Mosquitto Docker Image](https://hub.docker.com/_/eclipse-mosquitto)
- [Mosquitto Configuration](https://mosquitto.org/man/mosquitto-conf-5.html)
- [MQTT Protocol Overview](https://mqtt.org/)
