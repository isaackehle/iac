# Running Docker Commands on the NAS Without `sudo`

Synology's Docker/Container Manager package does **not** create a `docker`
group by default, and DSM replaces the usual Linux `usermod`/`groupadd`
tools with its own `synogroup` — the standard "add yourself to the docker
group" instructions you'll find for regular Linux don't directly apply here.

## Steps (over SSH, with a sudo-capable account)

```shell
sudo synogroup --add docker
sudo synogroup --memberadd docker $USER
sudo chown root:docker /var/run/docker.sock
```

Then log out and back in. If it doesn't take effect, a reboot of the NAS
should do it.

## ⚠️ `--memberadd`, not `--member`

`--member` **replaces** the group's entire membership list with whoever you
pass in — it doesn't add to it. Using it on a group that already has other
members will silently remove them. Always use `--memberadd`.

## Persistence

Reported to survive reboots and DSM version upgrades (DSM6 → DSM7) once
set — this isn't a per-boot fix that needs reapplying, unlike some other
Synology package quirks (see `tailscale.md` in this same directory for a
case where a restart/reconfigure step **does** need to be reapplied).

## Source

- [Manage docker without needing sudo on your Synology NAS – Dave Jansen](https://davejansen.com/manage-docker-without-needing-sudo-on-your-synology-nas/) — same NAS model (DS920+), confirms this held up across a DSM6→7 upgrade.
