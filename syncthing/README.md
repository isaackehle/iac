# Syncthing via Portainer

Good reference article: <https://mariushosting.com/synology-install-syncthing-with-portainer/>

## Prereqs

Portainer already installed and connected to your Docker engine (Synology / Linux host / NAS).

Decide where you want Syncthing’s config and data to live, e.g. on your NAS volume or a local disk.

Example directory layout on the host:

- /volume1/docker/syncthing/config – Syncthing config
- /volume1/docker/syncthing/sync – root of synced data

## Create host folders

On the Docker host, create folders for Syncthing’s persistent data.

```bash
mkdir -p /volume1/docker/syncthing/{config,sync,data,ts-state,ts-config}
sudo chown -R $UID:${GROUPS[0]} /volume1/docker/syncthing
```

Using a non‑root UID/GID that matches your `docker user` prevents permission issues inside the container.

## Portainer stack definition

In Portainer:

1. Home → your environment → Stacks → **Add stack**.

2. Name: syncthing.

3. Paste a compose spec like:

    ```text
    version: "2.1"
    services:
    syncthing:
        image: ghcr.io/linuxserver/syncthing:latest
        container_name: syncthing
        hostname: syncthing
        environment:
        - PUID=1000        # your user id
        - PGID=1000        # your group id
        - TZ=America/New_York
        volumes:
        - /volume1/docker/syncthing/config:/config
        - /volume1/docker/syncthing/sync:/data1
        ports:
        - 8384:8384        # Web GUI
        - 22000:22000      # Sync protocol
        - 21027:21027/udp  # Local discovery
        restart: unless-stopped
    ```

    LinuxServer’s image is the de‑facto standard and exposes /config and /data1 for config and data respectively.

4. Click **Deploy the stack**, wait for “Stack successfully deployed”.

## Initial Syncthing setup

- Open http://<host>:8384 in a browser to reach the Syncthing GUI.
- Set GUI username/password under Settings → GUI to lock down access.
- Remove the default folder if you don’t plan to use it, then add a folder pointing at /`data1` (or subdirectories) as your sync root.

Once you’ve confirmed it’s working, you can add devices (other Syncthing instances) via their device IDs and start sharing folders.
