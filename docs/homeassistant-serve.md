# Home Assistant — Tailscale Serve Configuration

The HA box (Home Assistant OS) runs its own Tailscale add-on node
(`homeassistant.tail303fda.ts.net`) and proxies port 443/80 to HA's UI on
port 8123. This document covers the two approaches for configuring it.

## Approach 1 — Tailscale Add-on Config (Recommended, Persistent)

Configure the Tailscale add-on on the HA box via its Web UI:

1. Install the **Tailscale** add-on from the HA Supervisor store (if not
   already installed).
2. In the add-on configuration, enable **Share Home Assistant with Serve**
   (set `share_homeassistant: serve`).
3. Set `share_on_port: 443` (default).
4. In the Tailscale admin console (console.tailscale.com):
   - Ensure **MagicDNS** is enabled for your tailnet.
   - Enable **HTTPS** under the DNS page (provisions TLS certs
     automatically).
5. In HA's **Settings → System → Network → HTTP server**:
   - **Disable SSL/TLS** — let Tailscale handle HTTPS.
   - **Enable "Trust X-Forwarded-For"**.
   - Add `127.0.0.1` to **Trusted proxies**.
   - **Save** and then immediately click **Restart Home Assistant**
     (must be done within the 60-second confirmation window, or the
     change rolls back).

Restart the Tailscale add-on. Access at
`https://homeassistant.tail303fda.ts.net` (no port needed — serves on 443).

### Why Disable SSL/TLS in HA?

Tailscale Serve terminates TLS and presents a valid certificate. If HA is
also configured for SSL/TLS, you get a double-hops (Tailscale → HA HTTPS)
which can cause certificate mismatches and browser warnings. Let Tailscale
handle the TLS layer.

## Approach 2 — CLI via SSH (HA OS)

If SSH is enabled on the HA OS, you can run `tailscale serve` directly:

```bash
# SSH into the HA box
ssh root@homeassistant.tail303fda.ts.net

# Run Tailscale serve (binary is at /opt/tailscale on HA OS)
/opt/tailscale serve --bg --https homeassistant.tail303fda.ts.net \
  http://127.0.0.1:8123

# Verify
/opt/tailscale status
/opt/tailscale serve status
```

The `--bg` flag makes it persistent across reboots.

### Prerequisites (both approaches)

HA must be configured to trust the reverse proxy so it generates correct
`base_url` values and `x-forwarded-for` headers:

```yaml
# In configuration.yaml (or via HA UI — same effect)
http:
  use_x_forwarded_for: true
  trusted_proxies:
    - 127.0.0.1
```

Without this, HA may redirect to the LAN IP or show mixed-content warnings.

## Troubleshooting

### "Connection refused" on `homeassistant.tail303fda.ts.net`

- Verify the Tailscale add-on is running and authenticated.
- Check `share_homeassistant` is set to `serve` (not `disabled`).
- Ensure MagicDNS and HTTPS are enabled in the Tailscale admin console.
- Verify HA's HTTP server is listening on port 8123.

### Browser shows "Not Secure" or certificate errors

- Ensure HA's SSL/TLS is **disabled** in the HA UI (Settings → System →
  Network → HTTP server → SSL/TLS → Disabled).
- Clear browser cache and cookies for the domain.
- Wait up to 10 minutes after enabling HTTPS in the admin console —
  certificate provisioning can take a moment.

### HA rolls back HTTP configuration changes

The HA UI has a 60-second confirmation window. If you don't click **Save**
and then **Restart** within that window, the change is discarded.

**Workaround:** Write the config directly to `configuration.yaml`:

```yaml
http:
  use_x_forwarded_for: true
  trusted_proxies:
    - 127.0.0.1
```

Then restart HA. This bypasses the UI rollback mechanism entirely.

### HA shows "This site can't be reached" or 502

- The HA box may not have subnet routes enabled for your local network.
- Verify the HA box appears in the Tailscale admin console with a green
  status indicator.
- Check the Tailscale add-on logs for authentication errors.

## References

- [Tailscale add-on docs](https://github.com/hassio-addons/addon-tailscale)
- [Tailscale Serve docs](https://tailscale.com/docs/features/tailscale-serve)
- [Tailscale blog — Home Assistant](https://tailscale.com/blog/remotely-access-home-assistant)
