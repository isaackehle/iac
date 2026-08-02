# Synology Container Manager Project SSH Update Checklist

## Scope

This runbook applies to a Synology Container Manager Project managed from a project working directory on the NAS.

## Assumptions

- The project has a dedicated working directory, e.g. `{{PROJECT_DIR}}`
- The compose file is `docker-compose.yml` or equivalent in that directory
- Any bind mounts already exist on the NAS file system
- SSH access is available

## Preflight

- [ ] Confirm SSH access to the NAS.
- [ ] Confirm the project is a Synology Container Manager Project.
- [ ] Record the project path: `{{PROJECT_DIR}}`
- [ ] Record the project name: `{{PROJECT_NAME}}`
- [ ] Record the compose file path: `{{PROJECT_DIR}}/docker-compose.yml`
- [ ] Record the env file path if used: `{{PROJECT_DIR}}/.env`
- [ ] Identify all mapped volumes and host paths.
- [ ] Confirm downtime is acceptable.
- [ ] Make sure nobody is editing the same project in the DSM UI.

## Backup

- [ ] SSH into the NAS.
- [ ] Change into the project directory:

  ```shell
  cd "{{PROJECT_DIR}}"
  ```

- [ ] Create a timestamped backup:

  ```shell
  BACKUP_DIR="./backup-$(date +%Y%m%d-%H%M%S)"
  mkdir -p "$BACKUP_DIR"
  cp docker-compose.yml "$BACKUP_DIR"/
  [ -f .env ] && cp .env "$BACKUP_DIR"/
  ```

- [ ] Back up any changed config files or app data folders if the update touches them.

## Stop the project

- [ ] Stop the project cleanly from SSH:

  ```shell
  docker compose down
  ```

- [ ] If the project uses a specific Compose project name:

  ```shell
  docker compose -p "{{PROJECT_NAME}}" down
  ```

- [ ] Verify containers are stopped:

  ```shell
  docker ps
  ```

## Update

- [ ] Edit `docker-compose.yml` as needed.
- [ ] Save the updated file.
- [ ] If the project uses environment variables, update `.env` carefully.
- [ ] Pull the new images:

  ```shell
  docker compose pull
  ```

- [ ] Recreate the project:

  ```shell
  docker compose up -d --force-recreate
  ```

## Validate

- [ ] Confirm containers are running:

  ```shell
  docker ps
  ```

- [ ] Review logs:

  ```shell
  docker compose logs --tail=100
  ```

- [ ] Verify service health and connectivity.
- [ ] Confirm the app is using the updated image/config.

## Rollback

- [ ] Stop the updated project:

  ```shell
  docker compose down
  ```

- [ ] Restore the backup:

  ```shell
  cp "$BACKUP_DIR/docker-compose.yml" docker-compose.yml
  [ -f "$BACKUP_DIR/.env" ] && cp "$BACKUP_DIR/.env" .env
  ```

- [ ] Recreate the previous version:

  ```shell
  docker compose up -d
  ```

- [ ] Verify recovery with `docker ps` and logs.

## Hermes notes

- [ ] Treat the Container Manager project directory as the source of truth.
- [ ] Avoid mixing DSM UI edits with SSH edits during the same change window.
- [ ] Preserve the directory structure Container Manager expects.
- [ ] If the app uses bind mounts, make sure the host folders already exist under the Synology share path, such as `/volume1/...`.
