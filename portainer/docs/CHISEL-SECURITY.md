# Chisel Private Key Security

## Current Issue

The chisel private key is currently at:
`/volume1/docker/stacks/portainer/chisel/private-key.pem`

**Problems:**

- Directory is world-writable (`drwxrwxrwx+`)
- Key is in the stacks directory alongside config files
- Not in a dedicated secure location

## Recommended Solution

### Option 1: Dedicated Secure Directory (Best)

```shell
# Create secure directory
sudo mkdir -p /volume1/docker/chisel-private
sudo chmod 700 /volume1/docker/chisel-private

# Move key
sudo mv /volume1/docker/stacks/portainer/chisel/private-key.pem /volume1/docker/chisel-private/

# Set secure permissions
sudo chmod 600 /volume1/docker/chisel-private/private-key.pem
sudo chown root:root /volume1/docker/chisel-private/private-key.pem
```

**Update compose.yaml:**

```yaml
volumes:
  - /volume1/docker/chisel-private:/chisel-private:ro
```

Then in the container, reference it as `/chisel-private/private-key.pem`

### Option 2: Docker Volume (Good)

```shell
# Create a Docker volume
sudo /var/packages/ContainerManager/target/tool/docker volume create portainer_chisel_private

# Copy key into volume
sudo /var/packages/ContainerManager/target/tool/docker run --rm   -v portainer_chisel_private:/data   alpine cp /dev/stdin /data/private-key.pem < /volume1/docker/stacks/portainer/chisel/private-key.pem

# Remove old key
sudo rm /volume1/docker/stacks/portainer/chisel/private-key.pem
```

**Update compose.yaml:**

```yaml
volumes:
  - portainer_chisel_private:/chisel-private:ro
```

### Option 3: Quick Fix (Acceptable)

If you don't want to change the structure, at minimum:

```shell
# Set restrictive permissions
sudo chmod 700 /volume1/docker/stacks/portainer/chisel
sudo chmod 600 /volume1/docker/stacks/portainer/chisel/private-key.pem
sudo chown root:root /volume1/docker/stacks/portainer/chisel/private-key.pem
```

## Verification

After applying any fix:

```shell
# Check permissions
ls -la /volume1/docker/chisel-private/private-key.pem
# Should show: -rw------- (600) owned by root

# Verify container can still access it
sudo /var/packages/ContainerManager/target/tool/docker exec ts-portainer ls -la /chisel-private/
```

## Security Notes

- Private keys should never be world-readable
- The chisel key is used for Tailscale authentication - if compromised, an attacker could join your tailnet
- Consider rotating the key if it's been in an insecure location for a long time
- Back up the key securely before moving it
