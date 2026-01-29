# Remote AI Bridge

Use AI CLIs (Claude Code, Aider, etc.) from your work laptop via SSH to your home machine over Tailscale.

## Why?

- **Access AI tools remotely** - Use Claude Code from anywhere via your home machine
- **Keep credentials at home** - API keys never leave your personal computer
- **Secure connection** - Tailscale's WireGuard mesh, no exposed ports

## Quick Start

### 1. Home Machine (macOS/Linux)

```bash
curl -fsSL https://raw.githubusercontent.com/ddv1982/remote-ai-bridge/main/setup-home.sh | bash
```

Installs: Tailscale, tmux, Claude Code, enables SSH.

**macOS Users:** Enable Remote Login manually:
System Settings → General → Sharing → Remote Login (ON)

**After setup:**
- Log into Tailscale (macOS: menu bar icon, Linux: URL shown in terminal)
- Get your Tailscale IP: `tailscale ip` (e.g., `100.x.x.x`)

### 2. Work Laptop (macOS/Linux/WSL)

```bash
curl -fsSL https://raw.githubusercontent.com/ddv1982/remote-ai-bridge/main/setup-work.sh | bash
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
| `ai-pipe <cmd>` | Pipe stdin to home |
| `ai-review` | Pipe code for review |
| `ai-explain` | Pipe code for explanation |

## Examples

```bash
ai                        # Interactive session
ai-run claude --version   # Single command
git diff | ai-review      # Review changes
cat file.py | ai-explain  # Explain code
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

3. If missing or wrong, re-run `setup-work.sh` to reconfigure.

### SSH asks for password

The SSH key wasn't copied. Run on work laptop:
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

## Uninstall

To remove Remote AI Bridge config from your work laptop:

```bash
curl -fsSL https://raw.githubusercontent.com/ddv1982/remote-ai-bridge/main/uninstall.sh | bash
```

This removes SSH config and shell functions.

## Disclaimer

This tool provides secure remote access to your personal computer. Use responsibly and in accordance with your employer's policies and any applicable regulations.

## License

MIT
