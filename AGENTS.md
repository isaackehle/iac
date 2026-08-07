# AGENTS.md

## What this repo is

Infrastructure-as-code for a single self-hosted Synology NAS ("NAS") on a
Tailscale tailnet (`${TS_TAILNET_DOMAIN}`). There is no application code,
build step, package manager, or test suite — every stack is a
`docker-compose.yml` plus a `.env.example`, optional Tailscale `serve.json`,
and a `PORTAINER.md`/`README.md`. "Testing" a change means validating
compose syntax (`docker compose config`) and, where possible, actually
deploying and checking `docker compose ps` / logs / `tailscale serve
status`.

Read `README.md` and `QUICKSTART.md` first — they're the human-facing docs
and are kept in sync with reality (unlike in the past — see git history if
curious about the old host-serve-only setup).

## Repo layout

One directory per stack (`affine/`, `frigate/`, `homeassistant/`,
`mosquitto/`, `n8n/`, `nextcloud/`, `openwebui/`, `pihole/`, `plex/`,
`portainer/`, `postgresql/`, `syncthing/`), plus `_template/` (copy this to
scaffold a new sidecar-pattern stack), `scripts/` (the deploy tooling, see
below), and `docs/TODO.md` (known outstanding cleanup work). Each stack
directory is self-contained: nothing is shared/imported between stacks
except conventions and the scripts in `scripts/`.

Typical files in a stack directory (not all stacks have all of these):

- `docker-compose.yml` (or `.yaml` — inconsistent extension across stacks,
  `scripts/lib.sh compose_file_for()` auto-detects either)
- `.env.example` — template listing what env vars that stack needs; real
  values come from the central secrets file (see below), not from editing
  this file directly
- `serve.json` — Tailscale sidecar serve config (sidecar-pattern stacks only)
- `PORTAINER.md` — step-by-step deploy instructions for that specific stack
- `README.md` — stack-specific docs (only some stacks have one)

## Secrets: one central file, gitignored

Real secrets (Tailscale auth keys, DB passwords, API keys) live in exactly
one place: `iac-secrets.env` at the repo root — present in the working
tree but gitignored, never committed (it is in `.gitignore`; verify with
`git check-ignore iac-secrets.env` before trusting that). Override the
path with `IAC_SECRETS_FILE=/other/path` (e.g. to keep it outside the repo
in a synced folder).

`iac-secrets.env.example` (repo root, committed, no real values) documents
every key every stack needs, grouped by stack with `# --- stackname ---`
comments.

**`scripts/gen-env.sh <stack>`** cross-references a stack's `.env.example`
against the central secrets file and writes a real `<stack>/env.txt`
(gitignored). Named `env.txt`, not `.env` — dotfiles are hidden by default
in most OS file pickers, which makes Portainer's "Load variables from .env
file" button annoying to use with a literal `.env`; `docker compose`
therefore needs `--env-file env.txt` passed explicitly (it only auto-loads
a file literally named `.env`) — `scripts/deploy.sh up` already does this.
Resolution order per key: secrets file → derived value (only
for `TS_CERT_DOMAIN`, computed as `<stack>.<TS_TAILNET_DOMAIN>` if
`TS_TAILNET_DOMAIN` is set in the secrets file) → the `.env.example`
default. Anything left as an empty string or an obvious placeholder
(`changeme`, `tskey-auth-xxxx`, `${TS_TAILNET_DOMAIN}`, ...) is printed as a warning at
the end — that's the todo list for that stack's secrets.

If you're asked to add a new env var to a stack: add it to that stack's
`.env.example` (with a safe placeholder/comment) *and* to
`iac-secrets.env.example` under that stack's section. Don't add real values
to either — those only ever go in the user's real `iac-secrets.env`,
which you should never print or exfiltrate the contents of.

Generated `<stack>/env.txt` files are throwaway — they are not committed
and not kept around; `scripts/gen-env.sh` regenerates them on demand at
deploy time. `scripts/deploy.sh env` is a no-network alias for this.

### Templated files (`*.tmpl`)

Every sidecar stack keeps its committed `serve.json` source as
`serve.json.tmpl`; `scripts/gen-env.sh` (via `render_templates` in
`scripts/lib.sh`) renders it to `serve.json` (gitignored, like `env.txt`) at
deploy time. For most stacks the render just copies the file through —
Tailscale's own `${TS_CERT_DOMAIN}` runtime substitution covers the node's
own domain. `{{KEY}}` tokens (filled from the secrets file) are only needed
for values Tailscale can't substitute: a backend on a *different* tailnet
node — `portainer/serve.json.tmpl` (backend is the separate `nas`
node) — or a value inside a `TCP` handler rather than a `Web` map key,
since `${...}` runtime substitution is only confirmed to apply to the
latter — `pihole/serve.json.tmpl`'s `TerminateTLS` field, templated with
`{{TS_TAILNET_DOMAIN}}`. New `.tmpl` files need their rendered output path
added to `.gitignore` manually — the ignore list isn't automatic.

## Deploy tooling (`scripts/`)

This replaces what used to be bespoke per-stack `init.sh` / `apply-serve.sh`
/ `deploy-*.sh` scripts (removed). Everything is driven by config tables in
`scripts/lib.sh`:

- `ALL_STACKS` — canonical stack list
- `STACK_REMOTE_DIR` — where each stack lives on the NAS (see "legacy
  paths" below — most are `/volume1/docker/stacks/<name>`, four are not)
- `STACK_DIRS` — subdirectories to `mkdir -p` under that path
- `STACK_EXTRA_FILES` — `local:remote` file pairs to copy beyond the
  compose file and `env.txt` (mostly `serve.json`)
- `STACK_CHOWN_OVERRIDES` — `dir:uid:gid` for the few stacks that need a
  non-session-user owner (nextcloud's `app`/`data` need `33:33` for
  Apache's `www-data`; n8n's `config` needs `1000:1000`)
- `STACK_SERVE_PORTS` — host-level `tailscale serve` mappings for Pattern
  A/hybrid stacks

`scripts/deploy.sh <command> <stack> [ssh-host]` has subcommands `env`,
`dirs`, `push`, `serve`, `up`, `all` — see README.md for usage. `ssh`/`scp`
are in this sandbox's banned-commands list, so these scripts are meant to
be run by the user on their own machine, not executed by an agent in this
environment — don't try to actually run `scripts/deploy.sh dirs/push/serve/up`
here; `scripts/gen-env.sh` and `scripts/deploy.sh env` are safe to run
locally since they don't touch the network.

`scripts/serve-all.sh <ssh-host>` loops `STACK_SERVE_PORTS` for every stack
(replaces the old root-level `apply-serve.sh` that scanned for per-stack
scripts).

If you add a new stack, you must add entries to all of the relevant tables
above or `deploy.sh`/`gen-env.sh` will silently no-op for it (empty string
default for missing map entries, not an error).

## Two competing Tailscale deployment patterns — know which one applies

**Pattern A — Host-level `tailscale serve` (no sidecar container)**
Stacks: `affine`, `frigate`, `postgresql`

- Container just publishes a port on the NAS host via `ports:`.
- `scripts/deploy.sh serve <stack> <host>` runs
  `tailscale serve --bg --https=<port> <backend>` directly against the
  host's own `tailscaled` — no Tailscale container involved.
- Backend scheme matters: `http://127.0.0.1:<port>` for plain HTTP,
  `https+insecure://127.0.0.1:<port>` for self-signed HTTPS backends.

**Pattern B — Tailscale sidecar container (own tailnet node)**
Stacks: `homeassistant`, `langfuse`, `nextcloud`, `n8n`, `openwebui`, `plex`,
`portainer`, `syncthing`, `pihole` (`pihole` uses a variant, see below)

- A `tailscale/tailscale:latest` container joins the tailnet as its own
  node (`<name>.${TS_TAILNET_DOMAIN}`) and the app container has **no
  `ports:` and no `networks:` of its own** — it runs
  `network_mode: service:<sidecar>` and borrows the sidecar's entire
  network namespace.
- The sidecar reads its `serve.json` (via `TS_SERVE_CONFIG=/config/serve.json`)
  using `${TS_CERT_DOMAIN}` templating; it's re-read on sidecar container
  start, so the file must stay present at the mounted path (not a one-shot
  apply like Pattern A). Every sidecar stack mounts the **whole `ts-config`
  directory** at `/config` and `deploy.sh` pushes `serve.json` into
  `ts-config/serve.json` on the NAS — do not reintroduce single-file
  `<stack>/serve.json:/config/serve.json` mounts (they're cwd-sensitive when
  relative, and Docker silently creates a *directory* at the mount point if
  the source file is missing).
- If the app needs an extra LAN/host port besides the tailnet URL, that
  `ports:` entry goes on the **sidecar** service, not the app (see
  `pihole/docker-compose.yml`, `portainer/docker-compose.yml`).
- If the app has sibling containers (a db, browserless, etc.), those
  siblings join a dedicated bridge network (`<stack>-net`) and **the
  sidecar also joins that same network** — that's what lets the app (which
  has borrowed the sidecar's netns) still resolve siblings by name. Real
  examples: `nextcloud/docker-compose.yml` (db + redis),
  `n8n/docker-compose.yml` (browserless).
- `syncthing` inverts the usual direction: the *app* container is primary
  (keeps its own `ports:`/`hostname:`) and `ts-syncthing` runs
  `network_mode: service:syncthing`, borrowing the app's netns instead of
  the other way around. Don't assume all sidecar stacks are wired the same
  way — check `network_mode` before editing.

**⚠️ Critical gotcha — never use compose `hostname:` on a Tailscale
sidecar.** Always set the tailnet name via `TS_HOSTNAME=<name>` env var.
Using the compose `hostname:` field on a sidecar collides with Docker's
internal DNS and breaks MagicDNS resolution for *every* sidecar on the
host, not just the one you changed. This is documented inline in the
affected compose files and in `README.md`.

**`pihole` is Pattern B with one deliberate variant**, not a clean example
to copy verbatim: its `ts-pihole` sidecar uses `TCPForward`/`TerminateTLS`
in `serve.json` instead of the usual `HTTPS: true` + `Web` shape, and routes
through a third sibling container, `caddy`, which does the actual HTTP
reverse-proxying. This exists because `tailscaled`'s own built-in
`Web`/`Proxy` mode is measurably slower under concurrent load (enough to
make Pi-hole's admin UI hang loading its own CSS/JS —
[tailscale/tailscale#18307](https://github.com/tailscale/tailscale/issues/18307)),
not because pihole needs anything else unusual. It also inverts the usual
direction like `syncthing` does: `pihole` is primary (`ports:`, `hostname:`)
and `ts-pihole`/`caddy` both run `network_mode: service:pihole`. See
`README.md`'s "pihole — Pattern B + Caddy" section for the full schema
before reapplying this elsewhere — it's a real, reusable pattern for any
other Pattern B stack that hits the same slow-proxy wall, just not
something to copy blind.

**`portainer` now uses that same Caddy variant** (added 2026-08-03):
`ts-portainer` does `TCPForward`/`TerminateTLS` → `caddy-portainer` on
`:8444` → Portainer's plain HTTP `:9000`. Note it inverts pihole's
direction — here the *sidecar* owns the namespace and both `portainer` and
`caddy-sidecar` borrow it, so the `depends_on` edges point the opposite way.
Worth reading alongside pihole's version to see which parts of the pattern
are essential (the serve.json shape, Caddy doing the HTTP hop) and which are
per-stack (who owns the netns).

## Legacy directory paths — do not silently "fix"

Four stacks were deployed before the `/volume1/docker/stacks/<name>`
convention existed and still hold real data at their original path:
`homeassistant` → `/volume1/docker/homeassistant`, `pihole` →
`/volume1/docker/pihole`, `plex` → `/volume1/docker/plex`, `postgresql` →
`/volume1/docker/postgresql` + `/volume1/docker/postgresadmin`. These are
recorded as-is in `scripts/lib.sh` (`STACK_REMOTE_DIR`). Renaming these
paths in compose files would orphan real data on the NAS unless someone
manually migrates it first — don't do it as a drive-by cleanup.

## Compose correctness rules — read before editing any compose file

`docs/006_docker_compose_standards.md` is mostly a *style* guide (ordering,
naming). Its **Correctness Rules** section is not — those are the rules where
getting it wrong means the stack won't start, or starts and silently does the
wrong thing. Every one of them has broken a stack in this repo. Read that
section before editing compose files; the short version:

1. **`depends_on` follows namespace ownership, one direction only.** Exactly
   one service owns the netns; borrowers (`network_mode: service:<owner>`)
   depend on it, and the owner depends on **none** of them. Both directions =
   `cycle found in dependencies` = stack won't start. Which service owns it
   differs per stack (portainer: the sidecar; pihole/syncthing: the app) —
   check `network_mode` first.
2. **`depends_on` takes service names, never `container_name`.** Under our
   naming convention those deliberately differ (`tailscale-sidecar` vs
   `ts-portainer`), so this is easy to get wrong.
3. **`network_mode: host` is incompatible with the sidecar pattern** — the
   sidecar lands on the host network next to the NAS's own `tailscaled`.
4. **If a stack is in `STACK_EXTRA_FILES`, its compose file must consume what
   `lib.sh` pushes** (`TS_SERVE_CONFIG` + the `ts-config` mount), or the file
   is written and silently never read. Keep `lib.sh` and compose in sync both
   ways.
5. **Published ports must match the port the process actually listens on.**
6. **No literal secrets and no redactions.** A pasted `***` where a password
   belongs is a silent auth failure, not a placeholder.
7. **Stateful deps get a `healthcheck` + `condition: service_healthy`.** Bare
   `depends_on` waits for *start*, not *ready*.
8. **Absolute volume paths** — relative paths resolve against whatever
   directory Compose was invoked from, which differs between CLI, Container
   Manager, and Portainer.
9. **No `version:` key** (obsolete in Compose v2), and no unreferenced
   top-level `networks:`/`volumes:`.

**Operational, not a file rule: never `docker restart` a sidecar alone.**
`network_mode: service:X` binds the namespace at container *creation*, so
restarting one container leaves the others pointed at a namespace that no
longer exists. Always `docker compose down && docker compose up -d`.

## Known bugs already fixed (context for git blame / history)

- `postgresql/docker-compose.yml` used to have real DB/pgAdmin credentials
  hardcoded in plaintext (now parameterized via `env.txt`). Those values were
  already committed to git history before the fix — rotating the actual
  NAS credentials is a manual follow-up, not something fixable by editing
  files here.
- `postgresql/.env.example` used to contain Plex's variables (copy-paste
  bug) instead of Postgres/pgAdmin ones.
- `postgresql/docker-compose.yml` published `2665:5454`, but Postgres listens
  on 5432 — nothing could connect. Now `2665:5432`.
- `homeassistant/docker-compose.yml` had a stray `depends_on: - nextcloud`
  on its Tailscale sidecar (copy-paste leftover, removed).
- `homeassistant/docker-compose.yml` then had a genuine `depends_on` cycle
  (app ↔ sidecar) that prevented the stack from starting at all. Removed the
  app→sidecar edge. **Still unresolved:** it runs `network_mode: host` while
  the sidecar borrows that namespace (see correctness rule 3), and it has no
  `TS_SERVE_CONFIG` despite `lib.sh` pushing a `serve.json` for it. This stack
  needs a design decision, not a patch.
- `affine/docker-compose.yml` had a literal `***` in `DATABASE_URL` where the
  password belongs, in both `affine` and `affine_migration` — a committed
  redaction, silently breaking auth. Now `${DB_PASSWORD}`.
- `langfuse/docker-compose.yml` defines only `langfuse` + `postgres`, while
  `scripts/lib.sh` provisions `ts-state`, `ts-config`, `clickhouse-data`,
  `clickhouse-logs`, `minio-data`, `redis-data` and pushes a `serve.json`.
  One of the two is stale — **unresolved**, don't assume either is correct.
- `portainer` was down for ~8 hours on 2026-08-03. Root cause was corrupted
  `tailscaled` path/MTU state persisted in `ts-state/`, producing a
  payload-size-dependent hang (small responses fine, anything larger died
  after the TCP handshake). Not a compose problem, not a serve-config problem
  — both were also broken and fixing them changed nothing. Full writeup and
  the diagnostic technique that isolated it in
  `portainer/OUTAGE-2026-08-03.md`; symptom-indexed troubleshooting in
  `portainer/DEBUG.md`.

## Environment variable conventions

- Naming: inside a stack's compose file and generated `env.txt`, the
  Tailscale auth key is just `TS_AUTHKEY` (each stack has its own
  `env.txt`, so no collision). The *central* secrets file keeps them
  distinct as
  `TS_AUTHKEY_<STACK>` since it's a single file holding every stack's key —
  `gen-env.sh` maps `TS_AUTHKEY_<STACK>` → `TS_AUTHKEY` at generation time.
  `TS_CERT_DOMAIN` (full MagicDNS name used inside `serve.json` templating,
  auto-derived by `gen-env.sh` from `TS_TAILNET_DOMAIN` + stack name),
  `TS_HOSTNAME` (set directly in compose, not via secrets file — it's the
  same value as the stack name, not a secret).
- Generate Tailscale auth keys at
  `https://login.tailscale.com/admin/settings/keys` — reusable,
  pre-authorized keys, one per `TS_AUTHKEY_<STACK>` variable in the central
  secrets file (some stacks currently reuse the same key across sidecars;
  not ideal but not broken).

## Working on a stack

1. `cd <stack>` and read its `docker-compose.yml`, `.env.example`, and
   `PORTAINER.md`/`README.md` if present — conventions vary per stack,
   don't assume `_template/` is followed exactly everywhere.
2. Validate compose changes with `docker compose --env-file env.txt config`
   (catches YAML/interpolation errors without needing the real NAS or
   secrets — it'll fail if the local `env.txt` doesn't exist or is missing
   a referenced var, so run `scripts/gen-env.sh <stack>` first; note the
   explicit `--env-file` — compose only auto-loads a file literally named
   `.env`, and this repo generates `env.txt` instead, see "Secrets" above).
3. If adding a new env var, update both that stack's `.env.example` and
   `iac-secrets.env.example` (see "Secrets" above).
4. If adding a new sidecar-pattern stack, start from `_template/` and
   follow `_template/README.md`, which lists everything to wire up in
   `scripts/lib.sh`.
5. **Markdown linting is required** — all `.md` files must pass `rumdl` before commit.
   - Configuration: `.rumdl.toml` (line length: 160, excludes common files)
   - Run checks: `rumdl check .`
   - Auto-fix: `rumdl fmt .`
   - Pre-commit hook: `lefthook` runs `rumdl` automatically
   - Line length limit is 160 characters, blank lines required before/after fenced code blocks, lists must be preceded by blank lines. Don't treat linting warnings as blocking — fix them before committing.

## Commands

```shell
# Generate a stack's real env.txt from the central secrets file
scripts/gen-env.sh <stack>
scripts/gen-env.sh --all

# Validate a stack's compose file without deploying (needs env.txt to exist)
cd <stack> && docker compose --env-file env.txt config

# Full deploy pipeline (env + dirs + push + serve + up) — requires SSH
# access to the NAS, not runnable from this sandbox
scripts/deploy.sh all <stack> <ssh-host>

# Apply/reset all host-level Tailscale serve mappings — also requires SSH
scripts/serve-all.sh <ssh-host>
scripts/serve-all.sh <ssh-host> --reset
```

## Agent Rules

### Markdown Linting (MANDATORY)

All `.md` files **must** pass `rumdl` linter before commit. The pre-commit
hook (`lefthook`) will run `rumdl` automatically, but agents should also
verify linting before writing files.

**Configuration:** `.rumdl.toml` defines the linting rules:

- Line length: 160 characters (MD013)
- Blank lines before/after fenced code blocks (MD031)
- Lists must be preceded by blank lines (MD032)
- Unordered list indentation: 2 spaces (MD007)
- Allowed inline HTML elements: code, kbd, pre, samp, var (MD033)

**Commands:**

```shell
# Check all markdown files
rumdl check .

# Auto-fix issues
rumdl fmt .

# Check a single file
rumdl check <file.md>
```

**When writing markdown:**

1. Write the content with linting in mind
2. Run `rumdl check .` locally before committing
3. If issues are found, run `rumdl fmt .` to auto-fix
4. Never skip linting — it's a hard requirement

**If linting fails:**

- Fix the issues manually (usually easy: add blank lines, wrap long lines)
- Do NOT commit unlinted files
- If you can't fix it, ask the user for guidance

### Git Commit Messages

All commits must follow Conventional Commits format:

- `docs: <description>` — for documentation changes
- `feat: <description>` — for new features
- `fix: <description>` — for bug fixes
- `refactor: <description>` — for code changes that don't affect behavior
- `chore: <description>` — for maintenance tasks

**Examples:**

- `docs: add SSH deployment instructions to INSTALLATION.md`
- `feat(deploy): add new stack template`
- `fix(compose): correct depends_on cycle in homeassistant`

### File Organization

- Never write to `~/.hermes/skills/` directly — use the git repo pattern
- Never write secrets to files — use environment variables or 1Password
- Never commit `.env` files — only `.env.example` templates
- Keep stack directories self-contained
- Use `docs/` for cross-stack documentation

### Deployment Safety

- Always validate compose files with `docker compose config` before deploying
- Never restart sidecar containers alone — always use `docker compose down && up -d`
- For sidecar stacks, ensure `serve.json` is mounted correctly before starting
- For host-level serve stacks, ensure `tailscale serve` is applied after deployment
