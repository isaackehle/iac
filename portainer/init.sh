mkdir -p /volume1/docker/portainer/{config,data,ts-state,ts-config}
mkdir -p /volume1/docker/stacks/portainer
sudo chown -R $UID:${GROUPS[0]} /volume1/docker/portainer
sudo chown -R $UID:${GROUPS[0]} /volume1/docker/stacks/portainer

cp "$(dirname "$0")/serve.json" /volume1/docker/stacks/portainer/serve.json
cp "$(dirname "$0")/.env" /volume1/docker/stacks/portainer/.env
