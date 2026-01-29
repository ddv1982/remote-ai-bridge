# ai-home

> Access AI CLI tools on your home machine from anywhere via SSH over Tailscale.

Use AI CLIs (Claude Code, Aider, etc.) from any device via SSH to your home machine over Tailscale.

## Why?

- **Access AI tools remotely** - Use Claude Code from anywhere via your home machine
- **Keep credentials at home** - API keys never leave your personal computer
- **Secure connection** - Tailscale's WireGuard mesh, no exposed ports

## Quick Start

### 1. Home Machine (macOS/Linux)

```bash
curl -fsSL https://raw.githubusercontent.com/ddv1982/ai-home/main/setup-home.sh | bash
```

Installs: Tailscale, tmux, Claude Code, enables SSH.

**macOS Users:** Enable Remote Login manually:
System Settings → General → Sharing → Remote Login (ON)

**After setup:**
- Log into Tailscale (macOS: menu bar icon, Linux: URL shown in terminal)
- Get your Tailscale IP: `tailscale ip` (e.g., `100.x.x.x`)

### 2. Client Machine (macOS/Linux/WSL)

**Windows users:** Requires WSL. Install with `wsl --install` in PowerShell (admin), then reboot.

```bash
curl -fsSL https://raw.githubusercontent.com/ddv1982/ai-home/main/setup-client.sh | bash
```

The script will:
- Install Tailscale (log in with same account as home)
- Generate SSH key
- Ask for your home machine's **Tailscale IP or hostname**
- Configure SSH and shell commands

### 3. Copy SSH Key & Connect

After the script completes, copy your SSH key:
```bash
ssh-copy-id <username>@<tailscale-ip>
```

Then connect (open a new terminal or reload your shell):
```bash
ai    # Connect to persistent tmux session on home machine
```

(If `ai` isn't found, run `source ~/.bashrc` or open a new terminal)

## Commands

| Command | Description |
|---------|-------------|
| `ai [session]` | Connect to tmux session |
| `ai-run <cmd>` | Run command on home |

## Examples

```bash
ai                        # Interactive session
ai-run claude --version   # Single command
```

## Why tmux?

The `ai` command uses tmux to create a persistent session. If your SSH connection drops (network issues, laptop sleeps), your Claude session keeps running on your home machine. Just run `ai` again to reconnect.

Plain `ssh home` works too, but you'd lose any running sessions on disconnect.

## tmux Keys

| Key | Action |
|-----|--------|
| `Ctrl+B, D` | Detach (leave session running) |
| `Ctrl+B, C` | New window |
| `Ctrl+B, N/P` | Next/prev window |

## Troubleshooting

### Check Tailscale connection

```bash
tailscale status
```

Both machines should show as connected. If not:
- macOS: Click Tailscale icon in menu bar and log in
- Linux: Run `sudo tailscale up` and open the URL shown

### SSH connection refused

Ensure Remote Login is enabled on your Mac:
1. System Settings → General → Sharing
2. Turn ON "Remote Login"
3. Ensure your user is in the allowed list (or set to "All users")

### SSH hangs or times out

1. Verify Tailscale connectivity:
   ```bash
   tailscale ping <home-machine-name>
   ```

2. Check SSH config exists:
   ```bash
   ssh -G home | grep -E "^(hostname|user)"
   ```

3. If missing or wrong, re-run `setup-client.sh` to reconfigure.

### SSH asks for password

The SSH key wasn't copied. Run on client machine:
```bash
ssh-copy-id <username>@<tailscale-ip>
```

Or manually copy `~/.ssh/id_ed25519.pub` content to `~/.ssh/authorized_keys` on home.

### Linux: Tailscale auth

On Linux, `sudo tailscale up` shows an auth URL. Open it in your browser to log in.

### Test SSH directly

```bash
ssh -v <username>@<tailscale-ip>
```

The `-v` flag shows where the connection fails.

### Home machine goes to sleep

If your home Mac sleeps, SSH connections will fail. Use an app like [Caffeinated](https://apps.apple.com/app/caffeinated/id1362171212) or [Amphetamine](https://apps.apple.com/app/amphetamine/id937984704) to keep it awake, or adjust Energy Saver settings in System Settings.

## Uninstall

To remove ai-home config from your client machine:

```bash
curl -fsSL https://raw.githubusercontent.com/ddv1982/ai-home/main/uninstall.sh | bash
```

This removes SSH config and shell functions.

## Author

[Douwe de Vries](https://github.com/ddv1982)

## License

MIT
