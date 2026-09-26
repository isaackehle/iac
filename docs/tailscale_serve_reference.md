# Tailscale Serve — host-level reference

## How `tailscale serve --bg` works

`tailscale serve --bg` tells the Tailscale daemon (`tailscaled`) to:

1. Open an HTTPS listener on the specified port on the node's Tailscale
   interface.
2. Reverse-proxy inbound requests from tailnet clients to the corresponding
   local container.
3. Present a valid TLS certificate issued by Tailscale for the tailnet
   hostname, even when the backend uses a self-signed cert or plain HTTP.

All endpoints are **tailnet-only**. Nothing is reachable from the public
internet unless explicitly enabled via Funnel.

## Managing host serve mappings

```shell
# Apply all mappings (idempotent)
scripts/serve-all.sh <ssh-host>

# Reset everything and re-apply
scripts/serve-all.sh <ssh-host> --reset

# Check current state
ssh <ssh-host> tailscale serve status

# Remove a single port
ssh <ssh-host> "sudo tailscale serve --https=8971 off"

# Remove all
ssh <ssh-host> "sudo tailscale serve reset"
```

## Persistence

`tailscale serve --bg` writes config into `tailscaled`'s internal state at
`/var/lib/tailscale/`. It is not a running process — mappings survive
reboots automatically as long as `tailscaled` starts at boot
(`sudo systemctl enable --now tailscaled`).

## `serve.json` format (sidecar pattern)

Sidecar stacks mount a `serve.json` via `TS_SERVE_CONFIG`. Every stack uses
`TCPForward` + `TerminateTLS`, rendered from `<stack>/serve.json.tmpl`:

```json
{
  "TCP": {
    "443": {
      "TCPForward": "127.0.0.1:<port>",
      "TerminateTLS": "<name>.{{TS_TAILNET_DOMAIN}}"
    }
  }
}
```

The sidecar re-reads this file on container start — unlike the host
pattern, the file must remain present at the mounted path. See
[tailscale_patterns.md](tailscale_patterns.md) for why the `Web`/`Proxy`
shape and the old Caddy hop are no longer used.

## Templated files (`*.tmpl`)

Every sidecar stack keeps its committed `serve.json` source as
`serve.json.tmpl`; `scripts/gen-env.sh` renders it to `serve.json`
(gitignored, like `.env`) at deploy time. For most stacks the render just
copies the file through, since Tailscale's own `${TS_CERT_DOMAIN}`
substitution covers the node's own domain. `{{KEY}}` tokens (filled from
`./iac-secrets.env (repo root, gitignored)`) are only needed for values Tailscale can't
substitute — e.g. a backend on a _different_ tailnet node, as in
`portainer/serve.json.tmpl` (backend is the separate `nas` node); or a
value inside a `TCP` handler rather than a `Web` map key, since `${...}`
runtime substitution is only confirmed to apply to the latter — see
`pihole/serve.json.tmpl`'s `TerminateTLS` field, templated with
`{{TS_TAILNET_DOMAIN}}`. If you add a new `.tmpl` file (beyond the standard
`serve.json.tmpl`), also add its rendered output path to `.gitignore`.
