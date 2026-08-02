# NAS Terminal Configuration

## Terminal Setup for Synology NAS SSH

This document describes the terminal configuration used when SSH-ing into the Synology NAS (voyager).

### Local SSH Config (Automatic)

Your `~/.ssh/config` already handles terminal configuration automatically:

```ssh-config
# Tailscale hosts (including voyager)
Host dx1 discovery ds9 voyager enterprise
    HostName %h.tail303fda.ts.net
    SetEnv TERM=xterm-256color
    RequestTTY yes
    StrictHostKeyChecking accept-new

# Voyager specific
Host voyager.local, voyager
    HostName voyager.local
    User isaac
    SetEnv TERM=xterm-256color
    SendEnv COLORTERM
```

**What this does:**

- `SetEnv TERM=xterm-256color` - Sets terminal type for 256-color support
- `RequestTTY yes` - Forces TTY allocation (needed for interactive commands)
- `SendEnv COLORTERM` - Sends color environment variable to NAS

### NAS Profile Configuration

Add the following to `~/.profile` on the NAS (`/home/isaac/.profile`):

```bash
# Set terminal type (redundant if SSH config does it, but safe to have)
export TERM=xterm-256color

# Enable colored ls output
alias ls='ls --color=auto'

# Custom LS_COLORS for better visibility
# di=01;34    -> Directories: Bold Blue (no background)
# ow=01;34    -> Other-writable dirs: Bold Blue (removes green background)
# tw=01;34    -> Sticky+writable dirs: Bold Blue (removes green background)
# ex=01;32    -> Executables: Bold Green
# ln=01;36    -> Symlinks: Bold Cyan
export LS_COLORS="di=01;34:ow=01;34:tw=01;34:ex=01;32:ln=01;36"
```

**Note:** The `~/.profile` approach is preferred over `~/.bashrc` because:

- It runs for both interactive and non-interactive SSH sessions
- It's loaded before `~/.bashrc` in the login sequence
- It ensures consistent environment across all connection types

### Connection Command

```bash
# From your Mac (uses SSH config automatically)
ssh voyager
# or
ssh isaac@voyager.tail303fda.ts.net
```

The SSH config automatically:

- Sets `TERM=xterm-256color`
- Requests TTY allocation
- Uses the correct identity file
- Applies `StrictHostKeyChecking accept-new`

### Verification

After connecting, verify the configuration:

```bash
# Check terminal type (should be xterm-256color)
echo $TERM

# Check LS_COLORS
echo $LS_COLORS

# Test colored output (directories should be bold blue)
ls -la

# Test directory colors
ls -la /volume1/
```

### Troubleshooting

**Colors not working:**

1. Check terminal type: `echo $TERM` (should be `xterm-256color`)
2. Check if `LS_COLORS` is set: `echo $LS_COLORS`
3. If missing, run: `export LS_COLORS="di=01;34:ow=01;34:tw=01;34:ex=01;32:ln=01;36"`

**TTY allocation issues:**

1. Check SSH config: `grep -A3 "Host voyager" ~/.ssh/config`
2. Ensure `RequestTTY yes` is present
3. Try manual TTY: `ssh -t voyager`

**Ghostty-specific issues:**
If using Ghostty terminal, you can also set these in `~/.config/ghostty/config`:

```ini
env = TERM=xterm-256color
env = LS_COLORS=di=01;34:ow=01;34:tw=01;34:ex=01;32:ln=01;36
```

But the SSH config approach is preferred as it's connection-specific.
