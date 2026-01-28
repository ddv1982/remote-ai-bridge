# Remote AI Bridge

Use AI CLIs (Claude Code, Aider, etc.) from your work laptop via SSH to your home machine over Tailscale.

## Why?

- **Bypass firewalls** - AI services blocked at work
- **No API keys on work laptop** - Credentials stay home
- **Secure** - Tailscale's WireGuard mesh, no exposed ports

## Quick Start

### 1. Home Machine (macOS/Linux)

```bash
curl -fsSL https://raw.githubusercontent.com/ddv1982/remote-ai-bridge/main/setup-home.sh | bash
```

Installs: Tailscale, tmux, Claude Code, enables SSH. If Tailscale needs login, complete it via menu bar, then run `tailscale ip` to get your hostname.

### 2. Work Laptop (macOS/Linux/WSL)

```bash
curl -fsSL https://raw.githubusercontent.com/ddv1982/remote-ai-bridge/main/setup-work.sh | bash
```

Enter your home machine's Tailscale hostname when prompted.

### 3. Use It

```bash
source ~/.zshrc  # or ~/.bashrc
ai               # Connect to home machine
```

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

## tmux Keys

| Key | Action |
|-----|--------|
| `Ctrl+B, D` | Detach |
| `Ctrl+B, C` | New window |
| `Ctrl+B, N/P` | Next/prev window |

## Troubleshooting

```bash
tailscale status          # Check connection
ssh -v home               # Debug SSH
ssh home 'tmux ls'        # List sessions
```

## License

MIT
