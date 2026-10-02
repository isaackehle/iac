# Actual Budget: installation

Actual Budget is a local-first budgeting app. The server stores your budget files and syncs them between devices. It is reachable only over the tailnet at
`https://actualbudget.${TS_TAILNET_DOMAIN}`.

## Deploy

Add `TS_AUTHKEY` (or `TS_AUTHKEY_ACTUALBUDGET`) to `iac-secrets.env`, then from the repo root:

```shell
scripts/deploy.sh all actualbudget nas
```

That generates `.env`, creates `/volume1/docker/stacks/actualbudget/{data,ts-state,ts-config}`, pushes the compose file and `serve.json`, and starts the stack.

## First run

1. Open `https://actualbudget.${TS_TAILNET_DOMAIN}`.
2. Set a server password when prompted. Actual has no default login, so whoever reaches the URL first sets it.
3. Create a new budget, or import one from YNAB, nYNAB or another Actual file.

Actual needs a secure context (HTTPS) for its sync features. The Tailscale certificate provides that; don't reach the app over plain `http://` on the LAN.

## Data

Everything lives in `/volume1/docker/stacks/actualbudget/data` (server files, user files, account database). Back that directory up.

## Upgrades

```shell
scripts/deploy.sh up actualbudget nas
```

Never restart the sidecar alone. See [DEBUG.md](DEBUG.md).
