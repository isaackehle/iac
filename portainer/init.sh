mkdir -p /volume1/docker/portainer/{config,data,ts-state,ts-config}
mkdir -p /volume1/docker/stacks/portainer
sudo chown -R $UID:${GROUPS[0]} /volume1/docker/portainer
sudo chown -R $UID:${GROUPS[0]} /volume1/docker/stacks/portainer


# save the serve.json for Tailscale sidecar
cat > /volume1/docker/stacks/portainer/serve.json << 'EOF'
# This is a Tailscale serve.json file for the Portainer sidecar container.
# Copy from ./serve.json
...
EOF