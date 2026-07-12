mkdir -p /volume1/docker/nextcloud/{app,data,db,ts-state,ts-config}
sudo chown -R $UID:${GROUPS[0]} /volume1/docker/nextcloud
mkdir -p /volume1/docker/stacks/nextcloud
sudo chown -R $UID:${GROUPS[0]} /volume1/docker/stacks/nextcloud

# save the serve.json for Tailscale sidecar
cat > /volume1/docker/stacks/nextcloud/serve.json << 'EOF'
# This is a Tailscale serve.json file for the Nextcloud sidecar container.
# Copy from ./serve.json
...

EOF