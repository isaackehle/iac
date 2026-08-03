# Portainer Recovery — Consolidated Walkthrough (updated 2026-08-02, evening)

Read this top-to-bottom, in order, at a real keyboard. It supersedes the
earlier version of this file — a lot changed in this repo between then and
now (see "What changed since the last note" below), and this reflects the
actual current state of the repo as read directly, not assumptions carried
over from earlier tonight.

**No agent has live shell access to `voyager`.** Every command below needs to
be run by you, over SSH or Container Manager's console — nothing here executes
itself.

---

## What changed since the last note

Between the original recovery session and now, significant additional work
happened in this repo — restructured docs into `portainer/docs/`, moved
`certs/`/`chisel/` secrets to a new `/volume1/docker/portainer-secrets/`
location (700, root:root), updated `portainer/docker-compose.yml` to mount
from there, and added an `env_file:` directive pointing at
`/volume1/docker/stacks/portainer/.env`. `portainer/old/compose.yaml` — which
one of the docs (`DEPLOYMENT-CHECKLIST.md`) still references — **no longer
exists**; the canonical compose file is the top-level
`portainer/docker-compose.yml`.

The docs in `portainer/docs/` (`CONSOLIDATION-PLAN.md`,
`DIRECTORY-STRUCTURE.md`, `DEPLOYMENT-CHECKLIST.md`, `CHISEL-SECURITY.md`)
disagree with each other in places on exact final paths — treat them as
history/rationale, not as the source of truth. The source of truth is
whatever's actually deployed on the NAS, which is why step 4 below is a
verification pass before doing anything else.

---

## 1. Quick typo check (10 seconds)

Confirm you're actually browsing to `https://portainer.tail303fda.ts.net` —
`.ts.net`, not `.net`. Every working check tonight used the `.ts.net` suffix;
rule this out first.

## 2. Diagnose laptop → NAS SSH

```bash
ssh -vvv isaac@voyager.local
```

Read where it actually stops, then pick the matching fix:

- **`REMOTE HOST IDENTIFICATION HAS CHANGED`** → the NAS's SSH host key looks
  different than what's saved locally (can happen after DSM/package changes).
  Confirm it's genuinely your NAS (nothing else on your LAN would answer at
  `voyager.local`), then:
  ```bash
  ssh-keygen -R voyager.local
  ssh isaac@voyager.local
  ```
- **`no matching key exchange method found` / `no matching host key type
  found`** → newer macOS OpenSSH refusing DSM's older sshd algorithms:
  ```bash
  ssh -o HostKeyAlgorithms=+ssh-rsa -o PubkeyAcceptedAlgorithms=+ssh-rsa isaac@voyager.local
  ```
  If that connects, make it permanent by adding to `~/.ssh/config`:
  ```
  Host voyager.local
    HostKeyAlgorithms +ssh-rsa
    PubkeyAcceptedAlgorithms +ssh-rsa
  ```
- **Times out / no route** → DNS/mDNS issue, not a key issue. Try
  `ping voyager.local`, and fall back to the Tailscale IP or
  `voyager.tail303fda.ts.net` as the SSH target instead.

## 3. No-SSH fallback: Container Manager's console

If SSH stays broken, you don't need it. Container Manager → **Container** →
`ts-portainer` → **Terminal**/**Details** tab has a built-in console. Run:

```bash
tailscale status
```

If it shows logged-out / NeedsLogin / no peers, that alone explains
"unreachable" — the sidecar isn't actually on the tailnet regardless of
anything else being correct.

## 4. Establish ground truth on the NAS (do this before changing anything)

So much changed in parallel tonight that local repo state and NAS state may
have drifted. Check, don't assume:

```bash
# a. Does the new secrets location actually exist with real content?
ls -la /volume1/docker/portainer-secrets/
ls -la /volume1/docker/portainer-secrets/certs/
ls -la /volume1/docker/portainer-secrets/chisel/

# b. Does the .env file the compose file now requires actually exist?
ls -la /volume1/docker/stacks/portainer/.env
cat /volume1/docker/stacks/portainer/.env   # confirm TS_AUTHKEY etc. are real values, not placeholders

# c. What compose file is Container Manager's "Portainer" project actually
#    running? Compare it against the repo's canonical copy.
cat /volume1/docker/stacks/portainer/docker-compose.yml
```

Pull that last one down and diff against your laptop's copy if you want to be
sure they match:
```bash
scp isaac@voyager.local:/volume1/docker/stacks/portainer/docker-compose.yml /tmp/nas-portainer-compose.yml
diff /tmp/nas-portainer-compose.yml ~/code/isaackehle/iac/portainer/docker-compose.yml
```
No output = they match. If they differ, the NAS's copy is what's actually
running — treat that as truth for now, and decide whether to push your
laptop's version over it or pull the NAS's version back into git.

Also check what Container Manager's UI itself shows for the project's YAML
(Project → Portainer → Edit) — if it was ever created via "Import from
YAML/JSON" rather than pointed at a file on disk, Container Manager stores its
own copy internally, separate from anything in `/volume1/docker/stacks/`.

If `.env` is missing or has placeholder values, `docker compose up -d` in
step 7 will fail immediately — fix that first, don't skip to step 7 hoping
it'll work.

## 5. Confirm the certs/chisel/compose merge landed, and handle the still-open secrets exposure

Your last directory listing showed `cert.pem`/`key.pem` under `certs/`,
`private-key.pem` under `chisel/`, and content under `compose/` — that part
looks done. Quick confirm:

```bash
ls -la /volume1/docker/stacks/portainer/certs/ /volume1/docker/stacks/portainer/chisel/
ls -la /volume1/docker/portainer/ 2>/dev/null   # old legacy path — should be empty or gone
```

**Separately — and this is still open regardless of the certs/chisel work:**
your directory tree showed `iac-secrets.env` sitting inside the deployed
data/compose copy of this repo. The consolidation docs explicitly decided to
*keep* a working copy of the repo inside Portainer's data volume (documented
in `docs/CONSOLIDATION-PLAN.md` as intentional, not a bug) — that's a
reasonable call to leave as-is. But a real secrets file has no reason to be
part of that copy regardless. Check and remove it specifically:

```bash
find /volume1/docker/stacks/portainer/data/compose -iname "iac-secrets.env*"
```

If found, delete just those files (not the whole repo copy):
```bash
rm -f /volume1/docker/stacks/portainer/data/compose/*/iac-secrets.env
rm -f /volume1/docker/stacks/portainer/data/compose/*/iac-secrets.env.example
```

Given a real secrets file briefly sat inside a Portainer-browsable volume,
the prudent move is rotating whatever Tailscale auth key(s) are in that file
once things are stable again — treat it as potentially exposed, not
definitely safe.

## 6. Bring the stack up

```bash
cd /volume1/docker/stacks/portainer
docker compose up -d
```

If it errors on the `env_file` directive, that's step 4b unresolved — go
fix the `.env` file first.

## 7. Verify

```bash
docker ps -a --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'
docker logs --tail 50 ts-portainer
docker logs --tail 50 portainer
docker exec ts-portainer tailscale status
```

Want: both containers `Up`, no errors in either log, `tailscale status`
showing connected. Then log into `https://portainer.tail303fda.ts.net` (or
the LAN fallback `http://<host>:9000`) and confirm it shows your **existing**
admin login, not a fresh "create admin user" screen — that's the proof the
migrated `portainer.db` is the one actually being read.

---

## Still on the list after this (not blocking, from the original session)

- `scripts/serve-all.sh <ssh-host>` — reapply affine/frigate/postgresql
  host-serve mappings wiped by an earlier `tailscale serve reset`
- Investigate why `syncthing`/`ts-syncthing` were `Exited` earlier — separate,
  never chased down
- Remove the orphaned `portainer-ts_portainer_net` / `portainer_portainer_net`
  Docker networks if unused
- Commit `portainer/docker-compose.yml` and the new `docs/` restructuring to
  git — confirm `git status` in the repo, there's uncommitted work here
