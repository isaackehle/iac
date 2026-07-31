#!/usr/bin/env bash
set -euo pipefail

# Mosquitto broker on Synology NAS — generates the mosquitto_passwd hash
# file. Run this on the NAS *after* scripts/deploy.sh dirs/push have created
# the directories and pushed config/mosquitto.conf into place.
#
# Directory creation, chown, and config file placement are handled by
# `scripts/deploy.sh dirs` / `scripts/deploy.sh push` (see scripts/lib.sh)
# — this script only does the one thing that's mosquitto-specific.

STACK_DIR="/volume1/docker/stacks/mosquitto"

echo "Setting up Mosquitto password file..."

if [ ! -f "${STACK_DIR}/data/password" ]; then
    MQTT_USER="${MQTT_USER:-zigbee}"
    MQTT_PASSWORD="${MQTT_PASSWORD:?Set MQTT_PASSWORD before running this script}"

    docker run --rm \
        -v "${STACK_DIR}/data:/mosquitto/data" \
        eclipse-mosquitto:2.0 \
        mosquitto_passwd -c /mosquitto/data/password "${MQTT_USER}" <<<"${MQTT_PASSWORD}"

    sudo chown "$(id -u)":"$(id -g)" "${STACK_DIR}/data/password"
    echo "Password file created for user: ${MQTT_USER}"
else
    echo "Password file already exists, skipping."
fi
