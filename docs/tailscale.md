# Issues

That log is consistent with Tailscale’s **Synology package/backend mismatch** rather than a Tailnet connectivity issue. The daemon is getting network discovery traffic (`magicsock`), but the local backend it expects on `127.0.0.1:80` and `127.0.0.1:8443` is refusing connections, which commonly happens on DSM when the package state is broken or the host configuration step was not applied. [github](https://github.com/tailscale/tailscale/issues/13931)

## Likely fix

- On Synology, run the documented host-configuration task: `/var/packages/Tailscale/target/bin/tailscale configure-host; synosystemctl restart pkgctl-Tailscale.service`. [tailscale](https://tailscale.com/docs/integrations/synology)
- If the package is still stuck, SSH in and run `sudo tailscale up`, then complete the login URL in a browser as Tailscale recommends for DSM recovery. [tailscale](https://tailscale.com/docs/integrations/synology)
- If this follows a reinstall or DSM upgrade, uninstall/reinstall the Synology Tailscale package and clear stale app state if needed; that exact DSM7 reinstall/reset flow has resolved similar `connection refused` and local-API failures. [github](https://github.com/tailscale/tailscale/issues/6153)

## Why this happens

- `magicsock` showing a reachable peer/IP just means the network transport is alive; it does not mean the local web/backend service is healthy. [tailscale](https://tailscale.com/docs/reference/troubleshooting/connectivity/connect-device-failure)
- The repeated refusal on port `80` and `8443` usually points to the local backend component not starting, not to a WAN/Tailnet routing problem. [truenas](https://www.truenas.com/community/threads/tailscale-having-netstack-could-not-connect-to-local-server.115399/)
- On Synology, missing the `configure-host` step can leave outbound connectivity and local service integration in a bad state until that command is run and the service is restarted. [youtube](https://www.youtube.com/watch?v=fL0sbPGqHv4)

## What I’d do next

1. Run the Synology `configure-host` task command from SSH as root. [tailscale](https://tailscale.com/docs/integrations/synology)
2. Restart the Tailscale package service. [tailscale](https://tailscale.com/docs/integrations/synology)
3. If still broken, remove and reinstall the package, then re-auth with `sudo tailscale up`. [github](https://github.com/tailscale/tailscale/issues/6153)
4. Only after it boots cleanly would I look at any `serve`, `funnel`, or reverse-proxy settings that might be trying to use ports `80` or `8443`. [tailscale](https://tailscale.com/docs/features/tailscale-funnel)

## Most important clue

Because your logs already showed an invalid auth key earlier, I would treat this as a chain reaction: stale/bad auth key first, then incomplete package/backend startup second. The quickest path is usually fresh auth plus the Synology `configure-host` restart sequence. [github](https://github.com/tailscale/tailscale/issues/9715)
