# Port Registry — master list

Every host-bound port across every stack, one table, sorted by port number.
Covers Pattern A `tailscale serve` targets, non-HTTP direct ports, and the
handful of ports published straight to the host outside either Tailscale
pattern (syncthing's GUI, portainer's DSM-fronted ports). Check here before
adding a new `STACK_SERVE_PORTS` entry, a new sidecar host port, or a new
non-HTTP port — collisions on the NAS host are otherwise easy to hit blind.

| Port         | Stack            | Protocol  | Access path                             | Notes                                                                                   |
| ------------ | ---------------- | --------- | --------------------------------------- | --------------------------------------------------------------------------------------- |
| 53           | pihole           | TCP + UDP | Direct (non-HTTP)                       | DNS                                                                                     |
| 443          | pihole           | TCP       | `tailscaled` (TCPForward → Caddy)       | web UI, TLS terminated by Tailscale, not published to host — reachable only via tailnet |
| 1883         | mosquitto        | TCP       | Direct (non-HTTP)                       | MQTT — no Tailscale integration                                                         |
| 2660         | postgresql       | TCP       | Pattern A (host serve)                  | pgAdmin (internal `admin` port)                                       |
| 2665         | postgresql       | TCP       | Direct (non-HTTP)                       | raw Postgres, connect via Tailscale IP                                                  |
| 3010         | affine           | TCP       | Pattern A (host serve)                  |                                                                                         |
| 8000         | portainer        | TCP       | DSM reverse proxy (not Tailscale)       | edge agent port                                                                         |
| 8280         | pihole           | TCP       | Direct host publish (bypasses Caddy)    | raw plain-HTTP debug path straight to Pi-hole                                           |
| 8384         | syncthing        | TCP       | Pattern B sidecar + direct host publish | web GUI                                                                                 |
| 8554         | frigate          | TCP       | Direct (non-HTTP)                       | RTSP                                                                                    |
| 8555         | frigate          | TCP + UDP | Direct (non-HTTP)                       | WebRTC — UDP not proxiable via serve                                                    |
| 8971         | frigate          | TCP       | Pattern A (host serve)                  |                                                                                         |
| 9000         | portainer        | TCP       | DSM reverse proxy (not Tailscale)       | Portainer HTTP                                                                          |
| 9090         | langfuse (service.storage) | TCP       | Direct (non-HTTP)                       | S3 API, published on the `storage` sibling                                         |
| 19443 → 9443 | portainer        | TCP       | DSM reverse proxy (not Tailscale)       | Portainer HTTPS; `portainer-tailscale` sidecar exists but is **not enabled**                   |
| 21027        | syncthing        | UDP       | Direct (non-HTTP)                       | discovery                                                                               |
| 22000        | syncthing        | TCP + UDP | Direct (non-HTTP)                       | sync protocol                                                                           |

Not host-bound, so not in the table above but worth knowing about: pihole's
`caddy` listens on **8444** inside the stack's shared network
namespace only — never published to the host, not reachable outside the
`network_mode: service:service.primary` group. Won't collide with anything.

Not covered here: DSM's own native ports (Login Portal 5000/5001, SSH 22,
etc.) — cross-check Control Panel → Network → Firewall/Router if a
collision is suspected outside this table.

Currently actually deployed on the NAS: **syncthing** and (mid-rebuild)
**pihole**. Everything else in this table is either not yet deployed or
(portainer) deployed but fronted by DSM's reverse proxy instead of Tailscale.
