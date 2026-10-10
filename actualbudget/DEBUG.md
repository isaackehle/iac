# Debug Commands

Quick reference for troubleshooting the `actualbudget` + Tailscale stack.

Replace `actualbudget`, `actualbudget-tailscale`, and `/volume1/docker/stacks/actualbudget` with real values.

## Container Access

```shell
# Enter the Tailscale sidecar container
docker exec -it actualbudget-tailscale sh

# Enter the app container
docker exec -it actualbudget sh
```

## Tailscale Serve Configuration

```shell
# View the current serve config mounted in the container
cat /config/serve.json

# Check what Tailscale Serve is doing (from inside the sidecar)
docker exec actualbudget-tailscale tailscale serve status
```

## Container Logs

```shell
# App logs
docker logs actualbudget

# Tailscale sidecar logs
docker logs actualbudget-tailscale

# Follow logs in real-time
docker logs -f actualbudget-tailscale
```

## Tailscale Connectivity

```shell
# Check Tailscale status and IP
docker exec actualbudget-tailscale tailscale status

# Check IP addresses assigned to this node
docker exec actualbudget-tailscale tailscale ip
docker exec actualbudget-tailscale tailscale serve status
```

## Restart Services

```shell
# Restart both containers
docker compose -f /volume1/docker/stacks/actualbudget/docker-compose.yml restart
# Restart a single service
docker compose -f /volume1/docker/stacks/actualbudget/docker-compose.yml restart actualbudget
docker compose -f /volume1/docker/stacks/actualbudget/docker-compose.yml restart actualbudget-tailscale
```

## Config Files

| Purpose                | Host Path                                                  |
| ---------------------- | ---------------------------------------------------------- |
| App config             | `/volume1/docker/stacks/actualbudget/config`               |
| Tailscale serve config | `/volume1/docker/stacks/actualbudget/ts-config/serve.json` |
| Tailscale state        | `/volume1/docker/stacks/actualbudget/ts-state`             |

## Authentication

The server password is bootstrapped through the API and lives in
`server-files/account.sqlite`, never in compose. See [AUTH.md](AUTH.md) for the
full model.

```shell
# Is a password configured yet?
curl https://actualbudget.tail303fda.ts.net/account/needs-bootstrap

# Set the initial password (only works while bootstrapped=false), then sign in
curl -X POST -H 'Content-Type: application/json' \
  -d '{"loginMethod":"password","password":"<pw>"}' \
  https://actualbudget.tail303fda.ts.net/account/bootstrap
```

Inspect account state without printing hashes:

```shell
sqlite3 /volume1/docker/stacks/actualbudget/data/server-files/account.sqlite \
  "select method, active, length(extra_data) from auth;
   select count(*) from users;
   select count(*) from sessions;"
```

Note: `docker exec actualbudget sh -c 'grep …'` works for reading the bundled
server source, which is the fastest way to confirm auth behaviour.

## Portainer

```shell
export PORTAINER_URL="https://portainer.${TS_TAILNET_DOMAIN}"
export PORTAINER_API_KEY="$(op read op://secrets/Portainer/PORTAINER_API_KEY)"
curl -s -H "X-Api-Key: $PORTAINER_API_KEY" "$PORTAINER_URL/api/stacks" |
  python3 -m json.tool | grep -A2 '"Name": "actualbudget"'
```

Filter by name client-side — `/api/stacks?name=` is ignored.
