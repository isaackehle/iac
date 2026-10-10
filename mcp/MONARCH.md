# Monarch Money MCP server (local, stdio)

The Monarch Money MCP server is **not** part of the Portainer-managed `mcp`
stack. It runs locally as a stdio server, wired into the agent config, because
it needs interactive authentication and direct filesystem access to its session
credentials.

- Repo: `~/code/isaackehle/mcp-servers/monarch-mcp-server`
- Exposes Monarch tools (`get_transactions`, `search_transactions`,
  `get_accounts`, `get_spending_summary`, `get_recurring_transactions`, ...)
- Consumer: `~/Documents/Finances/financial-data-consolidation-skill` (see
  "Who consumes this" below)

For servers that *are* containerized behind `mcp.<tailnet>.ts.net`, see
[INSTALLATION.md](INSTALLATION.md).

---

## Setup

```bash
cd ~/code/isaackehle/mcp-servers/monarch-mcp-server
uv sync --frozen
```

Requires Python ≥3.12,<3.14 (the repo uses `uv`; the system `python3` is not
the project interpreter).

### gotcha: always use `uv run`

Running the scripts with the bare interpreter fails, because the system Python
has none of the dependencies installed:

```bash
$ python3 login_setup.py
ModuleNotFoundError: No module named 'monarchmoney'
```

The project env already has it. Use:

```bash
uv run python login_setup.py
```

Same applies to the server itself. There is no `requirements.txt` install step
to run by hand — `uv sync --frozen` against `uv.lock` is the install.

---

## Authentication

All tools return this until a session exists:

```json
{"error": true, "tool": "get_transactions",
 "message": "Authentication needed! Run: python login_setup.py"}
```

Authenticate interactively (this cannot be done unattended):

```bash
uv run python login_setup.py
```

The script offers three paths, in order of preference:

1. **Session cookies pasted from a logged-in browser** — long-lived, works for
   all account types including SSO, and sidesteps the Cloudflare CAPTCHA.
2. **Email + password**, with OTP and MFA prompts. Requests a long-lived
   session token from Monarch.
3. **Legacy session token paste**, for tokens captured under the old auth model.

### gotcha: restarting the MCP server after `uv sync`

If the MCP server process was started before dependencies were installed, it
keeps running with the broken environment and keeps reporting
`Authentication needed` even after a successful login. Restart the MCP server
after `uv sync` (or after installing dependencies by any means) so it picks up
the project env.

### gotcha: stale data is not stale auth

An expired or revoked session surfaces the same "Authentication needed"
message as a never-authenticated server. Before assuming the credentials broke,
check whether the server is simply running against an environment that predates
the last `uv sync`.

---

## Exporting transactions

`export_transactions.py` (in the server repo) pulls transactions straight from
the API using the same keyring-backed session and writes Monarch-shaped CSVs:

```bash
cd ~/code/isaackehle/mcp-servers/monarch-mcp-server
uv run python export_transactions.py --months 12 \
  --out ~/Documents/Finances/monarch
```

This exists because paging ~2,000 records through MCP tool calls floods the
agent context; running it as a process costs nothing. Output matches Monarch's
own CSV export column-for-column, including the `Transactions_*.csv` filename
the skill expects.

Two response-shape details the script depends on:

- the client returns a **dict**, not an object: transactions live under
  `allTransactions.results`, count at `allTransactions.totalCount`
- amounts are floats, dates are `YYYY-MM-DD`, and `account` / `merchant` /
  `category` are nested objects, not strings

### gotcha: the bank descriptor lives in `plaidName`

The API leaves `originalStatement` **empty** on many rows and carries the bank
descriptor in `plaidName` instead. Monarch's own CSV export puts that descriptor
in "Original Statement" either way.

Read `plaidName` first when mapping to the CSV. Skipping it silently loses data
that is only identifiable by descriptor: MDOL unemployment payments arrive with
the merchant set to Isaac's own name and category `Paychecks`, so with a blank
descriptor two of three May 2026 benefit deposits went undetected
(`$357.00` reported instead of `$1,071.00`).

---

## Who consumes this

`~/Documents/Finances/financial-data-consolidation-skill` aggregates Monarch
transactions into a rolling monthly budget and pushes plan amounts into
[Actual Budget](../actualbudget/AUTH.md).

Data flow:

```text
Monarch (API or CSV export)
  └─> monarch/Transactions_*.csv          (skill input; exports nest, deduped on Id)
       └─> budgets/YYYY-MM/{budget.yaml,budget.md,comparison.md}
            └─> unemployment/YYYY-MM/income.{yaml,md}
                 └─> Actual Budget (plan amounts, dry-run then --apply)
```

Current Monarch exports live in `~/Documents/Finances/monarch/`. They are
**cumulative snapshots, not disjoint periods** — each export contains all
history available at that moment, so three exports taken a week apart nest
(153 ⊂ 514 ⊂ 1312 rows). The skill dedupes on Monarch's `Id` column; without
that, concatenating them inflates the same purchases several times over.

Superseded exports are moved to `~/Documents/Finances/monarch/_archive/<stamp>/`
rather than deleted, so a bad pull can be rolled back. The skill's file scan is
non-recursive and only matches `Transactions_*.csv`, so `_archive/` is never
picked up as duplicate data.
