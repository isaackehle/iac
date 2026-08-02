# Debug Commands

Quick reference for troubleshooting the Nextcloud stack.

## Container Access

```shell
docker exec -it nextcloud-ts sh
docker exec -it nextcloud sh
docker exec -it nextcloud-db sh
docker exec -it nextcloud-redis sh
```

## Tailscale Serve Configuration

```shell
# Inside the sidecar:
cat /config/serve.json
tailscale serve status
```

## Container Logs

```shell
docker logs nextcloud
docker logs nextcloud-ts
docker logs nextcloud-db
docker logs nextcloud-redis
docker logs -f nextcloud
```

## Tailscale Connectivity

```shell
docker exec nextcloud-ts tailscale status
docker exec nextcloud-ts tailscale ip
docker exec nextcloud-ts tailscale serve status
```

## Nextcloud-Specific Commands

```shell
# Inside the nextcloud container:
php -f /var/www/html/occ status
php -f /var/www/html/occ maintenance:mode --on   # enable maintenance
php -f /var/www/html/occ maintenance:mode --off   # disable maintenance
php -f /var/www/html/occ db:add-missing-indices   # fix missing DB indices
php -f /var/www/html/occ files:scan --all         # rescan all files
php -f /var/www/html/cron.php                     # run background jobs manually
```

## Database

```shell
# Connect to PostgreSQL directly
docker exec -it nextcloud-db psql -U nextcloud -d nextcloud

# Check database size
docker exec nextcloud-db psql -U nextcloud -d nextcloud -c "SELECT pg_database_size('nextcloud');"
```

## Access

- **Via Tailscale:** `https://nextcloud.${TS_TAILNET_DOMAIN}`

## Restart Services

```shell
docker compose -f /volume1/docker/stacks/nextcloud/docker-compose.yml restart
docker compose -f /volume1/docker/stacks/nextcloud/docker-compose.yml restart nextcloud
docker compose -f /volume1/docker/stacks/nextcloud/docker-compose.yml restart nextcloud-ts
```

## Config Files

| Purpose | Host Path |
|---------|-----------|
| Nextcloud app/config | `/volume1/docker/stacks/nextcloud/app` |
| Nextcloud data | `/volume1/docker/stacks/nextcloud/data` |
| PostgreSQL data | `/volume1/docker/stacks/nextcloud/postgres` |
| Tailscale serve config | `/volume1/docker/stacks/nextcloud/ts-config/serve.json` |
| Tailscale state | `/volume1/docker/stacks/nextcloud/ts-state` |
