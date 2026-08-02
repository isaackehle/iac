# Debug Commands

Quick reference for troubleshooting the Frigate stack.

## Container Access

```shell
docker exec -it frigate sh
```

## Container Logs

```shell
docker logs frigate
docker logs -f frigate
```

## Frigate-Specific Commands

```shell
# Inside the container:
cat /config/config.yml        # current config
ls /media/frigate/            # recorded clips
```

## Access

- **Via Tailscale:** `https://nas.${TS_TAILNET_DOMAIN}:8971`

## Restart Services

```shell
docker compose -f /volume1/docker/stacks/frigate/docker-compose.yaml restart frigate
```

## Config Files

| Purpose | Host Path |
|---------|-----------|
| Frigate config | `/volume1/docker/stacks/frigate/config/config.yml` |
| Media storage | `/volume1/docker/stacks/frigate/storage` |
| tmpfs cache | in-memory (not persisted) |
