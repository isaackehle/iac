# TODO Items

## Done

- ✅ scp files into place from local laptop — `scripts/deploy.sh push`
- ✅ combine init.sh and apply-serve.sh — replaced by `scripts/deploy.sh`
  (`dirs`/`push`/`serve`/`up`) driven by config in `scripts/lib.sh`
- ✅ secrets consolidated into `iac-secrets.env` at the repo root (gitignored),
  generated per-stack `.env` via `scripts/gen-env.sh`

## Update template

- simplify README.md files (per-stack `PORTAINER.md`/`README.md` still have
  a lot of overlapping boilerplate — could factor shared bits out)
- rotate `postgresql` credentials — they were committed to git history in
  plaintext before being parameterized; changing `.env` going forward does
  not undo that exposure
- fill in real values for stacks with placeholder secrets — see
  `scripts/gen-env.sh --all` output for the current list
- decide whether to migrate the 4 legacy-path stacks (`homeassistant`,
  `pihole`, `plex`, `postgresql`) to the standard
  `/volume1/docker/stacks/<name>` layout — requires manually moving real
  data on the NAS first, see README.md "Legacy directory paths"
