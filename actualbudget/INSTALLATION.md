# Actual Budget: installation

Actual Budget is a local-first budgeting app. The server stores your budget files and syncs them between devices. It is reachable only over the tailnet at
`https://actualbudget.${TS_TAILNET_DOMAIN}`.

## Deploy

Add `TS_AUTHKEY` (or `TS_AUTHKEY_ACTUALBUDGET`) to `iac-secrets.env`, then from the repo root:

```shell
scripts/deploy.sh api actualbudget
```

This is the supported path: it creates the stack **in Portainer** (GitOps mode,
endpoint 3), pulling `actualbudget/docker-compose.yml` from GitHub main. The
stack is owned by Portainer — see [AUTH.md](AUTH.md#deployment-use-the-portainer-api-mode)
for why `docker compose up -d` over SSH must be avoided, and for the Portainer
gotchas (`name=` filter ignored, corrupted stack rows, the `get_secret_value`
service-account issue).

It stops if the stack already exists and never deletes one. To redeploy the
existing stack after a compose change: `scripts/deploy.sh redeploy actualbudget`.

For a non-Portainer host, `scripts/deploy.sh all actualbudget <ssh-host>` still
works.

## First run

1. Open `https://actualbudget.${TS_TAILNET_DOMAIN}`.
2. Set a server password when prompted. Actual has no default login, so whoever reaches the URL first sets it.
3. **Sign in.** There is no separate "create user" step — the ADMIN user is
   created automatically on the first successful password login.
4. Create a new budget, or import one from YNAB, nYNAB or another Actual file.

The password is bootstrapped once through `POST /account/bootstrap` and must
**not** be put in `docker-compose.yml`; see [AUTH.md](AUTH.md). It is stored in
1Password (`op://secrets/Actual Budget/password`) and referenced from
`iac-secrets.env`.

Actual needs a secure context (HTTPS) for its sync features. The Tailscale certificate provides that; don't reach the app over plain `http://` on the LAN.

## Data

Everything lives in `/volume1/docker/stacks/actualbudget/data` (server files, user files, account database). Back that directory up.

## Upgrades

```shell
scripts/deploy.sh up actualbudget nas
```

Never restart the sidecar alone. See [DEBUG.md](DEBUG.md).
