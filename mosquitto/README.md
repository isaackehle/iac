# Mosquitto MQTT Broker on Synology NAS

Lightweight MQTT broker for offloading message processing from Home Assistant. Perfect for Zigbee2MQTT integration.

## Why This Setup?

- **No device reconfiguration needed** - Your SLZB-06M stays exactly as-is
- **Offloads MQTT processing** - Removes broker responsibility from HA core
- **Clean separation** - IoT messaging infrastructure on dedicated NAS container
- **Zero disruption** - Just point Zigbee2MQTT to the new broker

## Quick Start

### 1. Deploy

```shell
# From your laptop: generate .env, create dirs, push files, bring it up
scripts/deploy.sh all mosquitto <ssh-host>

# Then SSH in and generate the password file (one-time, needs MQTT_PASSWORD set)
ssh <ssh-host>
cd /volume1/docker/stacks/mosquitto
MQTT_USER=zigbee MQTT_PASSWORD=<strong-password> ./init.sh
```

### 2. Set secrets

Add `MQTT_USER` / `MQTT_PASSWORD` / `TZ` to `iac-secrets.env.example`'s
mosquitto section and your real `./iac-secrets.env (repo root, gitignored)`, then
`scripts/gen-env.sh mosquitto` before deploying.

### 3. Configure Zigbee2MQTT in Home Assistant

In HA's Zigbee2MQTT addon configuration (`configuration.yaml`):

```yaml
mqtt:
  server: mqtt://192.168.68.30:1883 # Your NAS IP address
  user: zigbee
  password: <your-password>
  base_topic: zigbee2mqtt
  client_id: Zigbee2MQTT
```

Then restart the Zigbee2MQTT addon in HA.

## Architecture

```text
┌─────────────┐     TCP:6638      ┌──────────────────┐
│ SLZB-06M    │◄─────────────────►│ Zigbee2MQTT (HA) │
└─────────────┘                   └────────┬─────────┘
                                           │
                                    MQTT:1883
                                           ▼
                              ┌──────────────────────┐
                              │ Mosquitto Broker     │
                              │ (Synology NAS Docker)│
                              └──────────────────────┘
```

**Key points:**

- SLZB-06M → Zigbee2MQTT: Unchanged, no re-pairing needed
- Zigbee2MQTT → Mosquitto: Now uses external broker instead of built-in
- HA Core ← Mosquitto: Receives all Zigbee events via MQTT

## Verification

After deployment, verify the broker is running:

```shell
# Check container status
docker ps | grep mosquitto

# Test connection from Synology
docker exec -it mosquitto mosquitto_sub -t '#' -h localhost

# Or test with a client tool
mosquitto_pub -h 192.168.68.30 -u zigbee -P <password> -t "zigbee2mqtt/test" -m "hello"
```

## Troubleshooting

### Zigbee2MQTT can't connect to broker

**Check:** NAS IP address is correct in configuration
**Check:** Mosquitto container is running (`docker ps`)
**Check:** Port 1883 is accessible from HA network (firewall rules)

### Permission errors on password file

The `init.sh` script handles this, but if issues persist:

```shell
sudo chown ${UID}:${GROUPS[0]} /volume1/docker/stacks/mosquitto/data/password
```

### Need TLS encryption

Edit `/mosquitto/config/conf.d/tls.conf`:

```conf
listener 8883
cafile /mosquitto/certs/ca.crt
certfile /mosquitto/certs/server.crt
keyfile /mosquitto/certs/server.key
tls_version tlsv1.2
```

Then mount your certificates in `docker-compose.yaml`.

## Maintenance

### Update broker version

Edit `docker-compose.yaml` with new image tag:

```yaml
image: eclipse-mosquitto:2.0 # <- update to latest stable
```

Deploy again via Portainer to pull new image and restart container.

### Reset password

```shell
# Get username from environment variable or .env.example
MQTT_USER="${MQTT_USER:-zigbee}"

docker run --rm \
    -v /volume1/docker/stacks/mosquitto/data:/mosquitto/data \
    eclipse-mosquitto:2.0 \
    mosquitto_passwd /mosquitto/data/password "${MQTT_USER}" <<<"newpassword"
```

## Files Reference

- `docker-compose.yaml` - Container definition and port mappings
- `config/mosquitto.conf` - Broker configuration (read-only bind mount)
- `data/` - Persistent storage for password file and messages
- `init.sh` - Setup script for initial deployment
- `.env.example` - Environment variable template

## Resources

- [Mosquitto Documentation](https://mosquitto.org/documentation/)
- [Zigbee2MQTT MQTT Configuration](https://www.zigbee2mqtt.io/guide/configuration/mqtt.html)
- [Home Assistant Zigbee2MQTT Addon](https://github.com/zigbee2mqtt/hassio-zigbee2mqtt)
