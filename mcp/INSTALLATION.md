# mcp: MCP servers behind one tailnet name

One Tailscale node, `mcp`, in front of small MCP server containers. Each server
gets a path:

| URL | Server | Local port |
| --- | --- | --- |
| `https://mcp.<tailnet>.ts.net/synology/mcp` | Synology DSM tools (`ghcr.io/lefty3382/synology-mcp`) | 8485 |
| `https://mcp.<tailnet>.ts.net/` | A plain-text list of the servers | — |

`http://nas.<tailnet>.ts.net:8485/mcp` also still works (the port is published on
the NAS) for clients configured before this stack existed. Move them to the `mcp`
URL, then drop the published port.

The header of [docker-compose.yml](docker-compose.yml) explains the design:

- a shared network namespace, so each server needs its own port;
- path routing through Tailscale's web proxy, which strips the path prefix;
- the port table.

## Deploy

The stack was called `synology-mcp` until 2026-09-26. If that stack is still
running, remove it first, in Portainer (Stacks → `synology-mcp` → Delete) or with
`docker compose down` in `/volume1/docker/stacks/synology-mcp`. It has no data to
keep.

```shell
scripts/gen-env.sh mcp                  # .env (SYNOLOGY_*, TS_AUTHKEY) + serve.json
git push                                 # Portainer reads the compose file from GitHub
scripts/deploy.sh dirs mcp nas           # ts-state/ and ts-config/ on the NAS (Portainer won't create them)
scripts/deploy.sh extras mcp nas         # serve.json to /volume1/docker/stacks/mcp/ts-config/
scripts/deploy.sh api mcp                # Portainer-managed stack
```

Or over SSH: `scripts/deploy.sh all mcp nas`.

## Verify

From any tailnet machine:

```shell
curl -s https://mcp.<tailnet>.ts.net/                          # the server list
curl -s -o /dev/null -w '%{http_code}\n' https://mcp.<tailnet>.ts.net/synology/mcp
```

The second is an MCP endpoint, so a plain GET answering 4xx is normal; a TLS error
or timeout is not. On the NAS:

```shell
docker exec mcp-tailscale tailscale serve status
docker logs --tail 50 mcp-synology
```

## Point clients at it

MCP clients take the full URL, e.g. in opencode:

```jsonc
"synology": { "type": "remote", "url": "https://mcp.<tailnet>.ts.net/synology/mcp", "enabled": true }
```

## Add a server

The catalog of servers (what each one is, whether it belongs here or stays local,
its planned path and port, and a ready-to-copy Dockerfile and service) lives with
the server sources, outside this repo:

- **`~/code/isaackehle/mcp-servers/README.md`:** the catalog, the container-or-local rule, and
  client config for opencode, Hermes, LM Studio and Claude Code.
- **`~/code/isaackehle/mcp-servers/docs/plugin-recipe.md`:** the generic steps. A stdio server
  runs behind `supergateway` (Node) or `mcp-proxy` (Python) on its own port; you
  add a service here, a path handler in `serve.json.tmpl`, and its secrets.
- **`~/code/isaackehle/mcp-servers/docs/<server>.md`:** one per server (search, weather,
  tailscale, amazon-products, ...).

Short version:

1. **Check it's an MCP server.** LM Studio plugins (e.g. `Beledarians_LM_Studio_Toolbox`)
   run inside LM Studio and can't live here.
2. **Check it's safe on an unauthenticated node.** Anything that spends money or
   reads financial or password data stays local.
3. **Add** a Dockerfile under `servers/<name>/`, a service on the next free port
   (table in `docker-compose.yml`), a `"/<name>"` handler in `serve.json.tmpl`, and
   its secrets in `.env.example` and `iac-secrets.env`.
4. **Redeploy:** `scripts/gen-env.sh mcp`, `scripts/deploy.sh extras mcp nas`, then
   Pull and redeploy in Portainer.
