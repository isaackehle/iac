# Frigate — Portainer Stack Deployment

> **Recommended:** `scripts/deploy.sh all frigate <ssh-host>` from the repo root handles directory setup, `.env` generation, file placement, and bringing the stack up in one step — see root `README.md`/`QUICKSTART.md`. The manual steps below are the equivalent broken out.

## Overview

Frigate is a Network Video Recorder (NVR) for IP cameras with real-time object detection. It uses TensorFlow and YOLO to provide intelligent surveillance with notifications, clips, and live view.

## Directory Setup (on Synology NAS)

```shell
STACK_PATH="/volume1/docker/stacks/frigate"

mkdir -p $STACK_PATH/{config,storage}
```

## Deploy via Portainer

1. Go to **Stacks → Add stack**
2. Choose **Repository** as the build method
3. Set:
   - **Repository URL:** `https://github.com/isaackehle/iac.git`
   - **Repository reference:** `refs/heads/main`
   - **Compose path:** `frigate/docker-compose.yml`
4. Under **Environment variables**, fill in:
   - `FRIGATE_MQTT_HOST` — MQTT broker hostname (e.g., `mosquitto.tail303fda.ts.net`)
   - `FRIGATE_MQTT_USER` — MQTT username (e.g., `zigbee`)
   - `FRIGATE_MQTT_PASSWORD` — MQTT password
   - `FRIGATE_RTSP_USER` — RTSP camera username (if cameras require auth)
   - `FRIGATE_RTSP_PASSWORD` — RTSP camera password (if cameras require auth)
5. Click **Deploy the stack**

## Configure Frigate

After deploying the stack, you need to create the Frigate configuration file:

### Create `config.yml`

Create `/volume1/docker/stacks/frigate/config/config.yml`:

```yaml
mqtt:
  host: ${FRIGATE_MQTT_HOST}
  user: ${FRIGATE_MQTT_USER}
  password: ${FRIGATE_MQTT_PASSWORD}

detectors:
  coral1:
    type: edgetpu
    device: /dev/ttyUSB0

cameras:
  front_door:
    ffmpeg:
      inputs:
        - path: rtsp://camera_ip:554/stream1
          roles:
            - detect
            - record
        - path: rtsp://camera_ip:554/stream2
          roles:
            - clip
    detect:
      width: 1280
      height: 720
      fps: 5
    record:
      enabled: True
    objects:
      track:
        - person
        - car
        - dog
        - cat
```

**Important:** Replace the RTSP URLs with your actual camera streams. Common RTSP paths:
- Generic: `rtsp://username:password@camera_ip:554/stream1`
- Hikvision: `rtsp://username:password@camera_ip:554/Streaming/Channel/1/Main`
- Dahua: `rtsp://username:password@camera_ip:554/cam/realmonitor?channel=1&subtype=0`

## What the Stack Contains

| Container | Image | Role |
|-----------|-------|------|
| `frigate` | `ghcr.io/blakeblackshear/frigate:0.16.4` | Frigate NVR — pinned version for stability |

The container is pinned to a specific version (`0.16.4`) rather than using `:stable` — this is deliberate for GitOps-deployed stacks to ensure predictable behavior. Check the [Frigate releases](https://github.com/blakeblackshear/frigate/releases) before updating.

## First-Run Frigate Setup

1. Wait for the stack to start (check `docker ps` for the container)
2. Create the `config.yml` file as shown above
3. Restart the container to pick up the config:
   ```shell
   docker restart frigate
   ```
4. Access the Frigate Web UI:
   - Open `https://nas.tail303fda.ts.net:8971` (or the direct Tailscale IP)
5. Verify camera streams are connecting:
   - Check the **Cameras** tab in the UI
   - Verify live view is working for each camera
6. Configure object detection:
   - Go to **Configuration → Objects**
   - Select which objects to track (person, car, dog, cat, etc.)
7. Set up recording:
   - Go to **Configuration → Record**
   - Configure motion detection, zones, and retention policies

## Persistent Data

| Host Path | Container Path | Contents |
|-----------|----------------|----------|
| `$STACK_PATH/config` | `/config` | Frigate configuration (`config.yml`, database) |
| `$STACK_PATH/storage` | `/media/frigate` | Recordings, clips, snapshots |
| `/tmp/cache` | `/tmp/cache` (tmpfs) | Ephemeral cache for camera streams (1GB) |

## Access

| URL/Endpoint | Description |
|--------------|-------------|
| `https://nas.tail303fda.ts.net:8971` | Frigate Web UI (tailnet-only, via host-level serve) |
| `frigate.tail303fda.ts.net:8971` | Frigate Web UI (tailnet-only, via host-level serve) |
| `<NAS-Tailscale-IP>:8971` | Direct Tailscale IP access |
| `<NAS-LAN-IP>:8971` | LAN access (if NAS is on same network) |
| `<NAS-Tailscale-IP>:8554` | RTSP restream (re-stream camera feeds) |
| `<NAS-Tailscale-IP>:8555/tcp` | WebRTC over TCP (low-latency live view) |
| `<NAS-Tailscale-IP>:8555/udp` | WebRTC over UDP (preferred for live view) |

## Common Frigate Operations

### View Logs

```shell
docker logs frigate
```

### Restart Frigate

```shell
docker restart frigate
```

### Check Camera Status

```shell
docker exec frigate wget -qO- http://localhost:5000/api/stats | jq
```

### Backup Recordings

```shell
# From the NAS shell:
tar czf /volume1/backups/frigate-recordings-$(date +%Y%m%d).tar.gz /volume1/docker/stacks/frigate/storage
```

### Update Frigate Version

```shell
# Pull the latest version:
docker compose pull

# Restart with the new version:
docker compose down && docker compose up -d
```

## Backups

Include `$STACK_PATH/storage` in your Synology backup task (Hyper Backup, Syncthing, etc.). This directory contains:
- Video recordings
- Motion clips
- Snapshot images

**Note:** Recordings can be large — consider a separate backup strategy for this directory (e.g., offsite replication, cloud backup).

## Troubleshooting

### Camera Not Connecting

1. Check camera RTSP URL is correct:
   ```shell
   # Test from your laptop:
   ffplay rtsp://username:password@camera_ip:554/stream1
   ```
2. Verify camera credentials are correct
3. Check network connectivity to the camera
4. Verify the camera supports the stream format Frigate expects

### Object Detection Not Working

1. Check the Coral device is detected:
   ```shell
   docker exec frigate ls -l /dev/ttyUSB0
   ```
2. Verify the Coral firmware is up to date
3. Check Frigate logs for detection errors:
   ```shell
   docker logs frigate | grep -i detector
   ```

### Recordings Not Being Created

1. Verify recording is enabled in `config.yml`
2. Check motion detection is working (view the motion map in the UI)
3. Verify there's enough disk space:
   ```shell
   df -h /volume1/docker/stacks/frigate/storage
   ```
4. Check the recording schedule and retention settings

### High CPU Usage

1. Reduce the detection FPS in `config.yml`:
   ```yaml
   detect:
     fps: 5  # Lower if CPU is overloaded
   ```
2. Reduce the resolution if cameras are high-res:
   ```yaml
   detect:
     width: 1280  # Lower if needed
     height: 720
   ```
3. Check for other resource-intensive processes

## References

- [Frigate Documentation](https://docs.frigate.video/)
- [Frigate GitHub](https://github.com/blakeblackshear/frigate)
- [RTSP URL Format Guide](https://github.com/blakeblackshear/frigate/blob/master/docs/configuration/cameras.md#rtsp-url)
- [Coral Accelerator Setup](https://docs.frigate.video/hardware/)
