# Actual Budget — Authentication and Operations

Reference for the `actualbudget` stack: how authentication actually works, what
the failure modes look like, and how to deploy without breaking it.

Companion to `INSTALLATION.md` (deploy) and `DEBUG.md` (commands).

---

## Deployment: use the Portainer API mode

The stack is owned by **Portainer**, not by a hand-run `docker compose`.

```bash
scripts/deploy.sh api actualbudget
```

This creates (or recreates) a GitOps stack on endpoint 3, pulling
`actualbudget/docker-compose.yml` from `github.com/isaackehle/iac.git` main.

**Do not run `docker compose up -d` over SSH on the NAS.** Doing so recreates
the containers outside Portainer's knowledge, so Portainer's stack record and
the running containers drift apart. That drift is what produced the corrupted
stack row described below.

Portainer credentials come from 1Password:

```bash
export PORTAINER_URL="$(grep -m1 '^PORTAINER_URL=' iac-secrets.env | cut -d= -f2-)"
export PORTAINER_API_KEY="$(op read op://secrets/Portainer/PORTAINER_API_KEY)"
```

### gotcha: `get_secret_value` unsets the service account

`scripts/lib.sh` deliberately unsets `OP_SERVICE_ACCOUNT_TOKEN` before calling
`op read`, to avoid 403s on *user* vaults:

```bash
unset OP_SERVICE_ACCOUNT OP_SERVICE_ACCOUNT_TOKEN OP_TOKEN
resolved="$(op read "$value")"
```

That makes `get_secret_value` return **empty** for items in the `secrets` vault,
which is where this repo's service-account-only credentials live. When a script
needs one of those, resolve it explicitly with the service account active
(`op read "op://secrets/..."`) and export it, so the script's "from environment"
branch is used instead.

### gotcha: `/api/stacks?name=` is ignored

Portainer ignores the `name` query filter and returns every stack. Selecting
`.[0]` then returns the *first stack alphabetically by id*, not the requested
one — which has previously pointed at `syncthing` when `actualbudget` was
intended. Always filter client-side and verify identity before a DELETE:

```bash
sid=$(curl -s -H "X-Api-Key: $KEY" "$URL/api/stacks" \
  | python3 -c "import json,sys;print(next(s['Id'] for s in json.load(sys.stdin) if s['Name']=='actualbudget'))")
# then confirm before deleting
```

### gotcha: corrupted stack rows cannot be deleted

A stack row whose stored endpoint is `0` (rather than its real endpoint) makes
Portainer's delete fail permanently:

```text
404 {"message":"Unable to find the endpoint associated to the stack inside the database",
     "details":"Object not found inside the database (bucket=endpoints, key=0)"}
```

A `PUT` that rewrites `EndpointId` returns 200 but does **not** fix the delete
path, and recreating a stack with that name then fails with
`A stack with the normalized name 'X' already exists`. Recovery is to remove the
row outside the API (Portainer UI / DB) or to rename the stack.

---

## Authentication: how it really works

Server version: **26.10.0**. Account state lives in
`/volume1/docker/stacks/actualbudget/data/server-files/account.sqlite`
(`auth`, `users`, `sessions` tables).

The password is **not** stored in the compose file. It is bootstrapped once
through the API and then lives in the account DB.

### Bootstrap

```bash
curl -X POST -H 'Content-Type: application/json' \
  -d '{"loginMethod":"password","password":"<pw>"}' \
  https://actualbudget.tail303fda.ts.net/account/bootstrap
# => {"status":"ok","data":{"token":"<session token>"}}
```

Check state first:

```bash
curl https://actualbudget.tail303fda.ts.net/account/needs-bootstrap
# {"status":"ok","data":{"bootstrapped":false,"loginMethod":"password",
#                        "availableLoginMethods":[],"multiuser":false}}
```

`bootstrapped` is true when the `auth` table has **any** row. A second bootstrap
returns `already-bootstrapped`.

### There is no separate "create user" step

This trips people up, including in the UI: you can set a password but there is no
separate control to create a user, and you do not need one.

From the server source (`account-db-*.js`), `loginWithPassword()` creates the
ADMIN user on the first successful password login:

```js
const { totalOfUsers } = accountDb.first('SELECT count(*) as totalOfUsers FROM users');
if (totalOfUsers === 0) {
  userId = v4();
  accountDb.mutate(
    'INSERT INTO users (id, user_name, display_name, enabled, owner, role) VALUES (?,?,?,1,1,?)',
    [userId, '', '', 'ADMIN'],
  );
}
```

So: set the password, then **sign in**. The user appears at that point. A user
row with `user_name = ''` is the expected single-user shape.

### Why `ACTUAL_SERVER_PASSWORD` does not work

Setting `ACTUAL_SERVER_PASSWORD` in compose has no effect once `account.sqlite`
already holds an account row. `loginWithPassword()` only ever compares against
the stored hash:

```js
const { extra_data: passwordHash } = accountDb.first(
  "SELECT extra_data FROM auth WHERE method = 'password'") || {};
if (!passwordHash) return { error: 'invalid-password' };
```

With an empty `auth` table, every login returns `invalid-password` no matter
what is passed or what env var is set — including a correct one. Password
bootstrap must go through `/account/bootstrap`.

**Rule: never put the Actual password in docker-compose.**

### Where the password lives

1Password item `Actual Budget` in the `secrets` vault, referenced from
`iac-secrets.env` as an `op://` reference:

```text
ACTUAL_PASSWORD=op://secrets/Actual Budget/password
```

Consumer: `~/Documents/Finances/financial-data-consolidation-skill` reads
`ACTUAL_PASSWORD` from the environment (`lib/actual.js`). That skill also pulls
transactions from Monarch and produces the monthly budgets; see
[mcp/MONARCH.md](../mcp/MONARCH.md) for the upstream half and
`~/Documents/Finances/financial-data-consolidation-skill/README.md` for the
skill itself.

```bash
export ACTUAL_PASSWORD="$(op read 'op://secrets/Actual Budget/password')"
export ACTUAL_BUDGET="<budget file name>"
```

---

## API endpoints (verified against 26.10.0)

Paths are relative to the server URL. Sync routes require an
`X-ACTUAL-TOKEN` header and otherwise answer `401 token-not-found`.

| Method   | Path                       | Notes                                                          |
| -------- | -------------------------- | -------------------------------------------------------------- |
| POST     | `/account/bootstrap`       | Set the initial password. Only while `needs-bootstrap`         |
| POST     | `/account/login`           | Returns `{data:{token}}`; creates the ADMIN user on first call |
| POST     | `/account/change-password` | Needs a valid session                                          |
| GET      | `/account/needs-bootstrap` | `{bootstrapped, loginMethod, availableLoginMethods}`           |
| GET      | `/account/login-methods`   | Active login methods                                           |
| POST     | `/sync/sync`               | Binary sync payload                                            |
| GET/POST | `/sync/list-user-files`    | List budget files; token required                              |

The @actual-app/api Node client signs in at `SIGNUP_SERVER + "/login"`, i.e.
`/account/login` — **not** `/sync/login` or `/login`. SYNC_SERVER is `<url>/sync`.

### `getBudgets()` returning `[]` is ambiguous

The Node client's `getBudgets()` returns an empty array in **two** different
situations:

- the server genuinely has no budgets, and
- authentication was rejected (`401 token-not-found`), which the client swallows.

An empty list is therefore **not** proof of an empty server. Confirm with
`/sync/list-user-files` plus a valid token before concluding anything, and never
report "the server has no budgets" off an empty array alone.

Budget files live in `data/user-files/`. A shared/group budget appears as
`group-<sync-id>.sqlite` alongside a `file-<uuid>.blob`, and that sqlite holds
sync messages (`messages_binary`, `messages_merkles`) rather than readable
budget tables — so it cannot be inspected with `sqlite3 ... select * from budgets`.
There is no `/account/signup` or `/account/register` route; bootstrap is the
only way in.

---

## Data reset (2026-10-10)

The account was reset to establish password auth. The prior data was moved, not
deleted:

```text
/volume1/docker/stacks/actualbudget/data.pre-reset-20261010-134850/
├── server-files/account.sqlite
├── user-files/file-3bd25770-….blob
└── user-files/group-3e99b2dc-….sqlite
```

Restore by moving it back over `data/` with the stack stopped. No budget files
exist on the server since the reset; create one in the UI before pushing.

---

## Known pre-existing issue: `gen-env.sh` needs bash 5

```bash
/opt/homebrew/bin/bash scripts/gen-env.sh actualbudget
```

macOS ships bash 3.2, which lacks associative arrays. `scripts/lib.sh` declares
`declare -A STACK_REMOTE_DIR=( [actualbudget]=... )`, and under `set -u` bash 3.2
evaluates `[actualbudget]` as arithmetic, dying with:

```text
scripts/lib.sh: line 18: actualbudget: unbound variable
```

This fails for **every** stack, not just this one, and is unrelated to any
stack's config. Every other script in the repo already uses
`#!/opt/homebrew/bin/bash`; `gen-env.sh` is the odd one out and should be fixed
the same way.

---

## State as of 2026-10-10

Reset for this auth work; old data preserved at
`data.pre-reset-20261010-134850/` (restore by moving it back over `data/` with
the stack stopped).

| Item                   | State                                                                           |
| ---------------------- | ------------------------------------------------------------------------------- |
| Password auth          | working — bootstrapped via `POST /account/bootstrap`                            |
| Password stored        | 1Password `Actual Budget`, `op://secrets/Actual Budget/password`                |
| `account.sqlite`       | `auth`: password/active=1, `users`: 1, `sessions`: 1                            |
| Budget files on server | **none** — `user-files/` is empty                                               |
| Portainer stack        | id 72, GitOps via `scripts/deploy.sh api actualbudget`                          |
| Monarch source         | archived; waiting on `login_setup.py` (see [mcp/MONARCH.md](../mcp/MONARCH.md)) |

The UI showed a pre-existing budget, but that copy is **browser local storage
only** — the server has never held it. Clearing site data destroys it, and the
NAS backup is a separate, older copy that does not include it.

Next step is to create a budget in the UI and sign in to the sync server so it
uploads, then let the skill push plan amounts. Category names must be read back
with `npm run actual:categories` and mapped before any write.
