# Quick Start Guide

One-time setup, then per-stack deploys. See `README.md` for the full
secrets/deploy model and Tailscale pattern details.

---

## One-time: set up the secrets file

```bash
cp iac-secrets.env.example iac-secrets.env
$EDITOR iac-secrets.env   # fill in real values
```

This file lives at the repo root, gitignored and never committed. Every
stack's real `env.txt` is generated from it.

---

## Per-stack deploy

Preview the steps for any stack:

```bash
scripts/deploy.sh info <stack>
```

Run the full deploy in one command:

```bash
scripts/deploy.sh all <stack> <ssh-host>
```

This generates the stack's `env.txt`, creates its directories on the NAS,
pushes the compose file + `env.txt` + any extra config, applies host-level
`tailscale serve` mappings if the stack needs them, and runs
`docker compose up -d` — in one command. `<ssh-host>` is anything
`ssh`/`scp` accepts (an `~/.ssh/config` alias or `user@host`).

Run the steps individually if you'd rather stage files first and deploy via
the Portainer UI instead of `docker compose up -d` directly:

```bash
scripts/deploy.sh env   <stack>                # generate <stack>/env.txt locally
scripts/deploy.sh dirs  <stack> <ssh-host>      # mkdir -p + chown on the NAS
scripts/deploy.sh push  <stack> <ssh-host>      # scp files into place
scripts/deploy.sh serve <stack> <ssh-host>      # host-level tailscale serve, if applicable
```

After `push`, the compose file and `env.txt` are already sitting in the
stack's directory on the NAS — in Portainer, deploy from repository
(`github.com/isaackehle/iac.git`, path `<stack>/docker-compose.yml`), then
under Environment variables use **Load variables from .env file** and pick
the generated `<stack>/env.txt` from your laptop. It's named `env.txt`
rather than `.env` specifically so that file picker can actually see it —
most OS "Open File" dialogs hide dotfiles by default.

### Per-stack notes

- **mosquitto** has no Tailscale integration; after `deploy.sh dirs`/`push`,
  SSH in and run `mosquitto/init.sh` once to generate the hashed password
  file (needs `MQTT_PASSWORD` set in the shell environment).
- **frigate** needs real camera RTSP details filled into
  `frigate/frigate-config.yml` (it reads credentials from
  `{FRIGATE_RTSP_USER}`/`{FRIGATE_RTSP_PASSWORD}`, substituted from the
  stack's `env.txt` at container start).
- **plex** needs `PLEX_CLAIM` from <https://www.plex.tv/claim> — only
  required on first run.
- **openwebui** needs a post-deploy step to register Ollama backends; see
  `openwebui/README.md`.

---

## Applying all host-level serve mappings at once

```bash
scripts/serve-all.sh <ssh-host>              # apply all stacks
scripts/serve-all.sh <ssh-host> --reset      # reset everything, then re-apply
```
