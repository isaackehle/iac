mkdir -p /volume1/docker/syncthing/{config,sync,data,ts-state,ts-config}
sudo chown -R $UID:${GROUPS[0]} /volume1/docker/syncthing
mkdir -p /volume1/docker/stacks/syncthing
sudo chown -R $UID:${GROUPS[0]} /volume1/docker/stacks/syncthing
