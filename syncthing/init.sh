mkdir -p /volume1/docker/syncthing/{config,sync,data,ts-state,ts-config}
sudo chown -R $UID:${GROUPS[0]} /volume1/docker/syncthing
mkdir -p /volume1/docker/stacks/syncthing
sudo chown -R $UID:${GROUPS[0]} /volume1/docker/stacks/syncthing

# save the serve.json for Tailscale sidecar
cat > /volume1/docker/stacks/syncthing/serve.json << 'EOF'
# This is a Tailscale serve.json file for the Syncthing sidecar container.
# Copy from ./serve.json
...
EOF