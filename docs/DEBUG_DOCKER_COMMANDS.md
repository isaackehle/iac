# Docker Debug Commands

Quick reference for common Docker debugging commands.

## Container Status

### Show all containers with name and status

```bash
docker ps -a --format "{{.Names}}: {{.Status}}"
```

### Show only running containers

```bash
docker ps --format "{{.Names}}: {{.Status}}"
```

### Show container IDs only

```bash
docker ps -q
```

### Table format with multiple columns

```bash
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Image}}"
```

## Container Logs

### Tail logs for a specific container

```bash
docker logs --tail 100 <container-name>
```

### Follow logs in real-time

```bash
docker logs -f <container-name>
```

### Logs with timestamps

```bash
docker logs --timestamps <container-name>
```

### Combined tail and follow

```bash
docker logs --tail 50 -f <container-name>
```

## Container Inspection

### Get container details

```bash
docker inspect <container-name>
```

### Get specific field (e.g., IP address)

```bash
docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' <container-name>
```

### Get container restart count

```bash
docker inspect -f '{{.RestartCount}}' <container-name>
```

## Container Processes

### Top processes in a container

```bash
docker top <container-name>
```

### Execute command in running container

```bash
docker exec -it <container-name> /bin/bash
```

## Volume and Network Info

### List all volumes

```bash
docker volume ls
```

### Inspect a volume

```bash
docker volume inspect <volume-name>
```

### List all networks

```bash
docker network ls
```

### Inspect a network

```bash
docker network inspect <network-name>
```

## Synology Container Manager Specific

### Using Container Manager's docker binary

```bash
sudo /var/packages/ContainerManager/target/tool/docker ps --format "{{.Names}}: {{.Status}}"
```

### Using synodocker (if available)

```bash
sudo /usr/syno/bin/synodocker ps -a
```

## Common Debug Workflow

```bash
# 1. Check if containers are running
docker ps -a --format "{{.Names}}: {{.Status}}"

# 2. Check logs for failed containers
docker logs --tail 100 <container-name>

# 3. Inspect container details
docker inspect <container-name> | grep -A 5 "State"

# 4. Restart container if needed
docker restart <container-name>

# 5. Pull latest image and redeploy
docker pull <image-name>
docker compose up -d
```

## Quick Reference

| Command | Description |
|---------|-------------|
| `docker ps` | List running containers |
| `docker ps -a` | List all containers |
| `docker logs <name>` | View container logs |
| `docker inspect <name>` | Get detailed container info |
| `docker exec -it <name> /bin/bash` | Enter container shell |
| `docker restart <name>` | Restart container |
| `docker rm <name>` | Remove container |
| `docker rmi <image>` | Remove image |
| `docker volume ls` | List volumes |
| `docker network ls` | List networks |
