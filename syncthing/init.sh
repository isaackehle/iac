mkdir -p /volume1/docker/stacks/syncthing/{config,sync,data,ts-state,ts-config}
sudo chown -R $UID:${GROUPS[0]} /volume1/docker/stacks/syncthing



mkdir -p /volume1/docker/stacks/portainer/{config,data,ts-state,ts-config}
sudo chown -R $UID:${GROUPS[0]} /volume1/docker/stacks/portainer

cp "$(dirname "$0")/serve.json" /volume1/docker/stacks/portainer/serve.json
cp "$(dirname "$0")/.env" /volume1/docker/stacks/portainer/.env
