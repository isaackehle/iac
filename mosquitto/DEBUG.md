# Debug Commands

Quick reference for troubleshooting the Mosquitto stack.

## Container Access

```shell
docker exec -it mosquitto sh
```

## Container Logs

```shell
docker logs mosquitto
docker logs -f mosquitto
```

## MQTT Testing

```shell
# Subscribe to all topics (from another device on the tailnet)
mosquitto_sub -h <mosquitto-ip> -u zigbee -P "$MQTT_PASSWORD" -t "#"

# Publish a test message
mosquitto_pub -h <mosquitto-ip> -u zigbee -P "$MQTT_PASSWORD" -t "test/topic" -m "hello"

# From inside the container:
mosquitto_sub -t "#"
mosquitto_pub -t "test/topic" -m "hello"
```

## Access

- **LAN/tailnet:** `mqtt://<host>:1883`
- **WebSocket:** `ws://<host>:9001`

## Restart Services

```shell
docker compose -f /volume1/docker/stacks/mosquitto/docker-compose.yaml restart mosquitto
```

## Config Files

| Purpose | Host Path |
|---------|-----------|
| Mosquitto config | `/volume1/docker/stacks/mosquitto/config/mosquitto.conf` |
| Persistent data | `/volume1/docker/stacks/mosquitto/data` |
| TLS certs | `/volume1/docker/stacks/mosquitto/certs` |
