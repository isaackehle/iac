# _template — new stack scaffold

Copy this directory to `<new-stack>/` to start a Tailscale sidecar-pattern
stack (Pattern B — see root `README.md`). Replace every `app` / `APP` with
the real stack name, then delete the comment block at the top of
`docker-compose.yml`.

`serve.json.tmpl` is rendered to `serve.json` by `scripts/gen-env.sh` at
deploy time. For most stacks Tailscale's own `${TS_CERT_DOMAIN}` runtime
substitution (already in the file) is all you need — the render step just
copies it through. If your `serve.json` needs a value Tailscale can't
substitute (e.g. a backend on a *different* tailnet node), put a `{{KEY}}`
token in the `.tmpl` and that key in `./iac-secrets.env (repo root, gitignored)`; see
`portainer/serve.json.tmpl` for a real example. Remember to add the
rendered `serve.json` path to `.gitignore` for your new stack.

`DEBUG.md` is a template for troubleshooting commands — replace the `<stack>` /
`ts-<stack>` / `/volume1/docker/stacks/<stack>` placeholders with real values.

Run `scripts/deploy.sh info <stack>` anytime to see step-by-step deploy instructions.

## After scaffolding

1. Add any secrets the new stack needs to `iac-secrets.env.example` (repo)
   and to your real `./iac-secrets.env (repo root, gitignored)` (or wherever
   `IAC_SECRETS_FILE` points).
2. Add the stack to `ALL_STACKS`, `STACK_REMOTE_DIR`, and `STACK_DIRS` in
   `scripts/lib.sh`. Add an entry to `STACK_EXTRA_FILES` if it has a
   `serve.json` or other config to copy into place.
3. Deploy with `scripts/deploy.sh all <stack> <ssh-host>` (or run the
   `env` / `dirs` / `push` / `up` steps individually — see root
   `README.md`).

## Known DNS collision

Always set the sidecar's tailnet name via `TS_HOSTNAME=<name>` (env var),
never via the compose `hostname:` field — `hostname:` collides with Docker's
internal DNS and breaks MagicDNS resolution for every sidecar on the host,
not just this one. See root `README.md` for details.
