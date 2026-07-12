mkdir -p /volume1/docker/nextcloud/{app,data,db,ts-state,ts-config}
sudo chown -R $UID:${GROUPS[0]} /volume1/docker/nextcloud
mkdir -p /volume1/docker/stacks/nextcloud
sudo chown -R $UID:${GROUPS[0]} /volume1/docker/stacks/nextcloud
